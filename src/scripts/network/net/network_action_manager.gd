class_name NetworkActionManager
extends Node

signal packet_sent(action_name: String)
signal packet_received(action_name: String, peer_id: int, data: Dictionary)

var _net: NetworkManager
var _handlers: Dictionary = {}
var _validators: Dictionary = {}
var _gp: RefCounted
var _name_to_id: Dictionary = {}

var _tick_data: Dictionary = {}

var _rate_limits: Dictionary = {}
var _rate_max: Dictionary = {}
var _rate_kick_callback: Callable

const RATE_LIMIT_WINDOW := 1.0
const RATE_KICK_MULTIPLIER := 5

var _sources: Dictionary = {}
var _receiver_manager: Object = null

# ── Автовалидация ─────────────────────────────────
# Внешние зависимости (устанавливаются через setup_server_context)
var _player_manager: PlayerManager = null
var _auth_data: Dictionary = {}        # peer_id → bool (ссылка на внешний)
var _last_move_times: Dictionary = {}   # peer_id → { pid → float }
var _cooldown_times: Dictionary = {}   # peer_id → { action → float }
var _violation_callback: Callable      # (peer_id, reason) → void


func setup(net: NetworkManager) -> void:
	_net = net
	_gp = GeneratedPackets.new()

	for pid: int in GeneratedPackets.PACKETS:
		_net.register_handler(pid, _on_packet.bind(pid))
		var meta: Dictionary = GeneratedPackets.PACKETS[pid]
		_name_to_id[meta["name"]] = pid

		var hz: int = meta.get("send_rate_hz", 0)
		if hz > 0:
			_rate_max[pid] = hz * 3
			_tick_data[pid] = {
				"args": [],
				"dirty": false,
				"accumulator": 0.0,
				"interval": 1.0 / float(hz),
			}
		else:
			_rate_max[pid] = 30


## Настроить серверный контекст для автовалидации.
## После этого вызова NAM автоматически проверяет правила из .tres.
## Ручные _validate_* методы вызываются ПОСЛЕ автопроверок.
func setup_server_context(
	pm: PlayerManager,
	authenticated: Dictionary,
	violation_cb: Callable = Callable()
) -> void:
	_player_manager = pm
	_auth_data = authenticated
	_violation_callback = violation_cb


# ══════════════════════════════════════════════════
#  АВТОПРИВЯЗКА
# ══════════════════════════════════════════════════

func auto_bind_source(node: Node, peer_id: int) -> void:
	var bound := 0
	var unbound := 0

	for pid: int in GeneratedPackets.PACKETS:
		var meta: Dictionary = GeneratedPackets.PACKETS[pid]
		var method: String = meta.get("source_method", "")

		if method == "":
			continue

		if node.has_method(method):
			_sources[pid] = { "node": node, "peer_id": peer_id }
			bound += 1
		else:
			unbound += 1
			push_warning("[NAM] auto_bind_source: '%s' требует метод '%s', но '%s' его не имеет" % [
				meta["name"], method, node.name])

	print("[NAM] auto_bind_source: привязано %d, пропущено %d" % [bound, unbound])

## Очистить все привязки источников.
## Вызывать при отключении, смене сцены, удалении локального игрока.
func clear_sources() -> void:
	_sources.clear()
	# Сбросить tick-данные чтобы не отправлять стухшие пакеты
	for pid: int in _tick_data:
		_tick_data[pid]["dirty"] = false
		_tick_data[pid]["args"] = []


func auto_bind_receiver(manager: Object) -> void:
	_receiver_manager = manager

	var count := 0

	for pid: int in GeneratedPackets.PACKETS:
		var meta: Dictionary = GeneratedPackets.PACKETS[pid]
		var method: String = meta.get("receive_method", "")

		if method == "":
			continue

		count += 1

	print("[NAM] auto_bind_receiver: %d пакетов с receive_method" % count)


func auto_bind_server(server: Object) -> void:
	var validators := 0
	var handlers := 0

	for pid: int in GeneratedPackets.PACKETS:
		var meta: Dictionary = GeneratedPackets.PACKETS[pid]
		var pname: String = meta["name"]

		var validate_fn := "_validate_%s" % pname
		if server.has_method(validate_fn):
			_validators[pid] = Callable(server, validate_fn)
			validators += 1

		var handler_fn := "_on_%s" % pname
		if server.has_method(handler_fn):
			_handlers[pid] = Callable(server, handler_fn)
			handlers += 1

	print("[NAM] auto_bind_server: %d валидаторов, %d обработчиков" % [validators, handlers])

## Авто-обновление PlayerManager после валидации.
## Обновляет позицию И ротацию из полей пакета.
func _auto_update_pm(peer_id: int, data: Dictionary, meta: Dictionary) -> void:
	if not meta.get("server_validates", false):
		return
	if _player_manager == null or not _player_manager.has_player(peer_id):
		return

	var pos_field: String = meta.get("v_position_field", "position")
	if pos_field == "" or pos_field not in data:
		return

	var max_dist: float = meta.get("v_max_distance", 0.0)
	var max_speed: float = meta.get("v_max_speed", 0.0)
	if max_dist <= 0.0 and max_speed <= 0.0:
		return

	var new_pos: Vector3 = data[pos_field]
	var old_data := _player_manager.get_player_data(peer_id)
	var old_rot: Vector3 = old_data.get("rotation", Vector3.ZERO)

	# Попытка собрать ротацию из известных полей
	var new_rot := old_rot
	var field_names: Array = meta.get("field_names", [])
	if "head_pitch" in data and "body_yaw" in data:
		new_rot = Vector3(data["head_pitch"], data["body_yaw"], 0.0)
	elif "rotation" in data and data["rotation"] is Vector3:
		new_rot = data["rotation"]

	_player_manager.update_player(peer_id, new_pos, new_rot)

func update_peer_id(peer_id: int) -> void:
	for pid: int in _sources:
		_sources[pid]["peer_id"] = peer_id

# ══════════════════════════════════════════════════
#  РУЧНАЯ ПРИВЯЗКА (обратная совместимость)
# ══════════════════════════════════════════════════

func on_action(action_name: String, handler: Callable) -> void:
	var pid := _find_id(action_name)
	if pid == -1:
		push_error("[NAM] on_action: неизвестное '%s'" % action_name)
		return
	_handlers[pid] = handler


func on_validate(action_name: String, validator: Callable) -> void:
	var pid := _find_id(action_name)
	if pid == -1:
		push_error("[NAM] on_validate: неизвестное '%s'" % action_name)
		return
	_validators[pid] = validator


func set_kick_callback(callback: Callable) -> void:
	_rate_kick_callback = callback


# ══════════════════════════════════════════════════
#  ОТПРАВКА
# ══════════════════════════════════════════════════

func send_action(action_name: String, args: Array) -> void:
	var pid := _find_id(action_name)
	if pid == -1:
		push_error("[NAM] send_action: неизвестное '%s'" % action_name)
		return
	if pid in _tick_data:
		_tick_data[pid]["args"] = args
		_tick_data[pid]["dirty"] = true
		return
	_send_immediate(pid, action_name, args)


func send_action_now(action_name: String, args: Array) -> void:
	var pid := _find_id(action_name)
	if pid == -1:
		return
	_send_immediate(pid, action_name, args)


func send_action_to(peer_id: int, action_name: String, args: Array) -> void:
	if not _net.is_server():
		return
	var pid := _find_id(action_name)
	if pid == -1:
		return
	var meta: Dictionary = GeneratedPackets.PACKETS[pid]
	var pkt: PackedByteArray = _gp.callv("write_%s" % action_name, args)
	_net.send_to_peer(peer_id, pkt, 0, _channel_flags(meta["channel"]))
	packet_sent.emit(action_name)


func _send_immediate(pid: int, action_name: String, args: Array) -> void:
	var meta: Dictionary = GeneratedPackets.PACKETS[pid]
	var pkt: PackedByteArray = _gp.callv("write_%s" % action_name, args)
	var flags := _channel_flags(meta["channel"])
	if _net.is_server():
		match meta["sync_mode"]:
			1: _net.broadcast(pkt, 0, flags)
			2: _net.broadcast(pkt, 0, flags)
	else:
		_net.send_to_server(pkt, 0, flags)
	packet_sent.emit(action_name)


# ══════════════════════════════════════════════════
# ТИКОВАЯ СИСТЕМА + AUTO COLLECT
# ══════════════════════════════════════════════════

func _physics_process(delta: float) -> void:
	_collect_from_sources()
	for pid: int in _tick_data:
		var td: Dictionary = _tick_data[pid]
		if not td["dirty"]:
			continue
		td["accumulator"] += delta
		if td["accumulator"] >= td["interval"]:
			td["accumulator"] -= td["interval"]
			var meta: Dictionary = GeneratedPackets.PACKETS[pid]
			_send_immediate(pid, meta["name"], td["args"])
			td["dirty"] = false


func _collect_from_sources() -> void:
	var stale: Array[int] = []

	for pid: int in _sources:
		var source: Dictionary = _sources[pid]

		# Безтиповое чтение — не крашит на freed instance
		var node_ref: Variant = source.get("node", null)
		if node_ref == null or not is_instance_valid(node_ref):
			stale.append(pid)
			continue

		var node: Node = node_ref as Node
		var meta: Dictionary = GeneratedPackets.PACKETS[pid]
		var method: String = meta.get("source_method", "")
		if method == "" or not node.has_method(method):
			continue

		var state: Dictionary = node.call(method)
		var args := _build_args(pid, meta, state, source["peer_id"])

		if pid in _tick_data:
			_tick_data[pid]["args"] = args
			_tick_data[pid]["dirty"] = true
		else:
			_send_immediate(pid, meta["name"], args)

	# Убрать мёртвые источники
	for pid in stale:
		_sources.erase(pid)
		if pid in _tick_data:
			_tick_data[pid]["dirty"] = false
			_tick_data[pid]["args"] = []


func _build_args(pid: int, meta: Dictionary, state: Dictionary, peer_id: int) -> Array:
	var field_names: Array = meta.get("field_names", [])
	var source_keys: Dictionary = meta.get("source_keys", {})
	var auto_pid: bool = meta.get("auto_peer_id", true)
	var args := []
	for fname in field_names:
		if fname == "peer_id" and auto_pid:
			args.append(peer_id)
			continue
		var skey: String = source_keys.get(fname, fname)
		args.append(_resolve_key(state, skey))
	return args


func _resolve_key(state: Dictionary, key: String) -> Variant:
	if "." not in key:
		return state.get(key, null)
	var parts := key.split(".")
	var current: Variant = state
	for part in parts:
		if current is Dictionary:
			current = (current as Dictionary).get(part, null)
		elif current is Vector3:
			match part:
				"x": current = current.x
				"y": current = current.y
				"z": current = current.z
				_: current = null
		elif current is Vector2:
			match part:
				"x": current = current.x
				"y": current = current.y
				_: current = null
		else:
			return null
	return current


func set_send_rate(action_name: String, hz: int) -> void:
	var pid := _find_id(action_name)
	if pid == -1:
		return
	if hz <= 0:
		_tick_data.erase(pid)
		return
	if pid not in _tick_data:
		_tick_data[pid] = {
			"args": [], "dirty": false,
			"accumulator": 0.0, "interval": 1.0 / float(hz),
		}
	else:
		_tick_data[pid]["interval"] = 1.0 / float(hz)


# ══════════════════════════════════════════════════
#  ПОЛУЧЕНИЕ
# ══════════════════════════════════════════════════

func _on_packet(peer_id: int, body: StreamPeerBuffer, pid: int) -> void:
	if pid not in GeneratedPackets.PACKETS:
		return
	if not _check_rate_limit(peer_id, pid):
		return
	var meta: Dictionary = GeneratedPackets.PACKETS[pid]
	var data: Dictionary = _gp.call("read_%s" % meta["name"], body)
	packet_received.emit(meta["name"], peer_id, data)
	if _net.is_server():
		_handle_server(pid, peer_id, data, meta)
	else:
		_handle_client(pid, peer_id, data, meta)


func _handle_server(pid: int, peer_id: int, data: Dictionary, meta: Dictionary) -> void:
	var sync_mode: int = meta["sync_mode"]
	if sync_mode == 1 or sync_mode == 2 or sync_mode == 4:
		return

	if "peer_id" in data:
		data["peer_id"] = peer_id

	# ── Автовалидация из .tres правил ─────────────
	if meta["server_validates"]:
		if not _auto_validate(pid, peer_id, data, meta):
			return
		if pid in _validators:
			if not (_validators[pid] as Callable).call(peer_id, data):
				return

	# ── Авто-обновление PlayerManager ─────────────
	_auto_update_pm(peer_id, data, meta)

	# ── Обработчик ────────────────────────────────
	if pid in _handlers:
		(_handlers[pid] as Callable).call(peer_id, data)

	# ── Маршрутизация ─────────────────────────────
	if sync_mode == 0:
		return

	var field_names: Array = meta.get("field_names", [])
	var values := []
	for fname in field_names:
		values.append(data[fname])
	var pkt: PackedByteArray = _gp.callv("write_%s" % meta["name"], values)
	var flags := _channel_flags(meta["channel"])

	match sync_mode:
		1: _net.broadcast(pkt, 0, flags)
		2: _net.broadcast_except(peer_id, pkt, 0, flags)
		3: _net.broadcast_except(peer_id, pkt, 0, flags)
		4: _net.send_to_peer(peer_id, pkt, 0, flags)


func _handle_client(pid: int, peer_id: int, data: Dictionary, meta: Dictionary) -> void:
	if pid in _handlers:
		(_handlers[pid] as Callable).call(peer_id, data)

	var receive_method: String = meta.get("receive_method", "")
	if receive_method != "" and _receiver_manager != null:
		_auto_receive(pid, peer_id, data, meta)


func _auto_receive(pid: int, peer_id: int, data: Dictionary, meta: Dictionary) -> void:
	var receive_method: String = meta.get("receive_method", "")
	var remote_id: int = data.get("peer_id", peer_id)
	if _receiver_manager is PlayerManager:
		var pm := _receiver_manager as PlayerManager
		if not pm.has_player(remote_id):
			return
		var player_data := pm.get_player_data(remote_id)
		var node: Node = player_data.get("node", null)
		if node != null and is_instance_valid(node) and node.has_method(receive_method):
			node.call(receive_method, remote_id, data)
	elif _receiver_manager.has_method(receive_method):
		_receiver_manager.call(receive_method, remote_id, data)


# ══════════════════════════════════════════════════
#  АВТОВАЛИДАЦИЯ (правила из .tres)
# ══════════════════════════════════════════════════

func _auto_validate(pid: int, peer_id: int, data: Dictionary, meta: Dictionary) -> bool:
	var action_name: String = meta["name"]
	var now := Time.get_unix_time_from_system()
	var cooldown: float = meta.get("v_cooldown", 0.0)
	var max_speed: float = meta.get("v_max_speed", 0.0)

	# ═══════════════════════════════════════════════
	# ФАЗА 1: Все проверки БЕЗ изменения состояния
	# ═══════════════════════════════════════════════

	if meta.get("v_authenticated", true):
		if not _auth_data.get(peer_id, false):
			return false

	if meta.get("v_player_exists", true):
		if _player_manager == null or not _player_manager.has_player(peer_id):
			return false

	if cooldown > 0.0:
		if peer_id in _cooldown_times:
			var peer_cd: Dictionary = _cooldown_times[peer_id]
			if action_name in peer_cd:
				if now - peer_cd[action_name] < cooldown:
					return false

	var pos_field: String = meta.get("v_position_field", "position")
	if pos_field != "" and pos_field in data and _player_manager != null:
		var new_pos: Vector3 = data[pos_field]
		var old_data := _player_manager.get_player_data(peer_id)
		var old_pos: Vector3 = old_data.get("position", Vector3.ZERO)
		var distance := old_pos.distance_to(new_pos)

		var max_dist: float = meta.get("v_max_distance", 0.0)
		if max_dist > 0.0 and distance > max_dist:
			_report_violation(peer_id, "teleport_%s" % action_name)
			return false

		if max_speed > 0.0:
			var dt := 0.05
			var peer_times: Dictionary = _last_move_times.get(peer_id, {})
			if pid in peer_times:
				dt = clampf(now - peer_times[pid], 0.01, 2.0)
			var tolerance: float = meta.get("v_speed_tolerance", 1.5)
			var max_allowed := max_speed * dt * tolerance
			if distance > max_allowed:
				_report_violation(peer_id, "speed_%s" % action_name)
				return false

		var max_action: float = meta.get("v_max_action_dist", 0.0)
		if max_action > 0.0 and distance > max_action:
			_report_violation(peer_id, "range_%s" % action_name)
			return false

	# ═══════════════════════════════════════════════
	# ФАЗА 2: Все проверки пройдены — обновляем таймеры
	# ═══════════════════════════════════════════════

	if cooldown > 0.0:
		if peer_id not in _cooldown_times:
			_cooldown_times[peer_id] = {}
		_cooldown_times[peer_id][action_name] = now

	if max_speed > 0.0:
		if peer_id not in _last_move_times:
			_last_move_times[peer_id] = {}
		_last_move_times[peer_id][pid] = now

	return true


func _report_violation(peer_id: int, reason: String) -> void:
	if _violation_callback.is_valid():
		_violation_callback.call(peer_id, reason)


# ══════════════════════════════════════════════════
#  RATE LIMITING
# ══════════════════════════════════════════════════

func _check_rate_limit(peer_id: int, pid: int) -> bool:
	if not _net.is_server():
		return true
	var now := Time.get_unix_time_from_system()
	if peer_id not in _rate_limits:
		_rate_limits[peer_id] = {}
	var peer_rates: Dictionary = _rate_limits[peer_id]
	if pid not in peer_rates:
		peer_rates[pid] = { "count": 0, "window_start": now }
	var entry: Dictionary = peer_rates[pid]
	if now - entry["window_start"] >= RATE_LIMIT_WINDOW:
		entry["count"] = 0
		entry["window_start"] = now
	entry["count"] += 1
	var max_allowed: int = _rate_max.get(pid, 30)
	if entry["count"] > max_allowed * RATE_KICK_MULTIPLIER:
		if _rate_kick_callback.is_valid():
			_rate_kick_callback.call(peer_id, "rate_extreme")
		return false
	if entry["count"] > max_allowed:
		return false
	return true


func clear_peer_data(peer_id: int) -> void:
	_rate_limits.erase(peer_id)
	_last_move_times.erase(peer_id)
	_cooldown_times.erase(peer_id)


# ══════════════════════════════════════════════════
#  УТИЛИТЫ
# ══════════════════════════════════════════════════

func _find_id(action_name: String) -> int:
	if action_name in _name_to_id:
		return _name_to_id[action_name]
	for pid: int in GeneratedPackets.PACKETS:
		if (GeneratedPackets.PACKETS[pid] as Dictionary)["name"] == action_name:
			_name_to_id[action_name] = pid
			return pid
	return -1


func _channel_flags(channel: int) -> int:
	if channel == 0:
		return ENetPacketPeer.FLAG_RELIABLE
	return ENetPacketPeer.FLAG_UNSEQUENCED
