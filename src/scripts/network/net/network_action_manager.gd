class_name NetworkActionManager
extends Node
## Маршрутизация пакетов из GeneratedPackets.
## Поддержка индивидуальной герцовки для каждого пакета.
## Поле "peer_id" перезаписывается сервером на реальный ID.

signal packet_sent(action_name: String)
signal packet_received(action_name: String, peer_id: int, data: Dictionary)

var _net: NetworkManager
var _handlers: Dictionary = {}
var _validators: Dictionary = {}
var _gp: RefCounted
var _name_to_id: Dictionary = {}

# ── Система герцовки ──────────────────────────────
# pid → { "args": Array, "dirty": bool, "accumulator": float, "interval": float }
var _tick_data: Dictionary = {}
# peer_id → { pid → { "count": int, "window_start": float } }
var _rate_limits: Dictionary = {}

const RATE_LIMIT_WINDOW := 1.0    # секунда
const RATE_LIMIT_MAX := {
	# pid → максимум пакетов в секунду
	# Заполняется в setup() из send_rate_hz * 2 (с запасом)
}
var _rate_max: Dictionary = {}


func setup(net: NetworkManager) -> void:
	_net = net
	_gp = GeneratedPackets.new()

	for pid: int in GeneratedPackets.PACKETS:
		_net.register_handler(pid, _on_packet.bind(pid))
		var meta: Dictionary = GeneratedPackets.PACKETS[pid]
		_name_to_id[meta["name"]] = pid

		# Rate limit: hz * 3 с запасом, минимум 10
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
			_rate_max[pid] = 30   # событийные: макс 30/сек


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

	# Новое окно?
	if now - entry["window_start"] >= RATE_LIMIT_WINDOW:
		entry["count"] = 0
		entry["window_start"] = now

	entry["count"] += 1

	var max_allowed: int = _rate_max.get(pid, 30)
	if entry["count"] > max_allowed:
		return false   # Превышен лимит

	return true


# ══════════════════════════════════════════════════
#  ПОДПИСКИ И ВАЛИДАТОРЫ
# ══════════════════════════════════════════════════

func on_action(action_name: String, handler: Callable) -> void:
	var pid := _find_id(action_name)
	if pid == -1:
		push_error("[NAM] on_action: неизвестное действие '%s'" % action_name)
		return
	_handlers[pid] = handler


func on_validate(action_name: String, validator: Callable) -> void:
	var pid := _find_id(action_name)
	if pid == -1:
		push_error("[NAM] on_validate: неизвестное действие '%s'" % action_name)
		return
	_validators[pid] = validator


# ══════════════════════════════════════════════════
#  ОТПРАВКА
# ══════════════════════════════════════════════════

## Отправить немедленно (для событийных пакетов с send_rate_hz = 0)
## или обновить данные (для тиковых пакетов с send_rate_hz > 0).
func send_action(action_name: String, args: Array) -> void:
	var pid := _find_id(action_name)
	if pid == -1:
		push_error("[NAM] send_action: неизвестное действие '%s'" % action_name)
		return

	# Если у пакета есть герцовка — только обновляем данные
	if pid in _tick_data:
		_tick_data[pid]["args"] = args
		_tick_data[pid]["dirty"] = true
		return

	# Иначе — отправляем немедленно
	_send_immediate(pid, action_name, args)


## Принудительная немедленная отправка (игнорирует герцовку)
func send_action_now(action_name: String, args: Array) -> void:
	var pid := _find_id(action_name)
	if pid == -1:
		push_error("[NAM] send_action_now: неизвестное действие '%s'" % action_name)
		return
	_send_immediate(pid, action_name, args)


## Сервер → конкретному пиру
func send_action_to(peer_id: int, action_name: String, args: Array) -> void:
	if not _net.is_server():
		push_error("[NAM] send_action_to: только для сервера")
		return
	var pid := _find_id(action_name)
	if pid == -1:
		push_error("[NAM] send_action_to: неизвестное действие '%s'" % action_name)
		return
	var meta: Dictionary = GeneratedPackets.PACKETS[pid]
	var write_fn := "write_%s" % action_name
	var pkt: PackedByteArray = _gp.callv(write_fn, args)
	_net.send_to_peer(peer_id, pkt, 0, _channel_flags(meta["channel"]))
	packet_sent.emit(action_name)


func _send_immediate(pid: int, action_name: String, args: Array) -> void:
	var meta: Dictionary = GeneratedPackets.PACKETS[pid]
	var write_fn := "write_%s" % action_name
	var pkt: PackedByteArray = _gp.callv(write_fn, args)
	var flags := _channel_flags(meta["channel"])

	if _net.is_server():
		match meta["sync_mode"]:
			1: _net.broadcast(pkt, 0, flags)
			2: _net.broadcast(pkt, 0, flags)
	else:
		_net.send_to_server(pkt, 0, flags)

	packet_sent.emit(action_name)


# ══════════════════════════════════════════════════
#  ТИКОВАЯ СИСТЕМА (_process)
# ══════════════════════════════════════════════════

func _physics_process(delta: float) -> void:
	for pid: int in _tick_data:
		var td: Dictionary = _tick_data[pid]
		if not td["dirty"]:
			continue

		td["accumulator"] += delta
		if td["accumulator"] >= td["interval"]:
			td["accumulator"] -= td["interval"]

			var meta: Dictionary = GeneratedPackets.PACKETS[pid]
			var action_name: String = meta["name"]
			_send_immediate(pid, action_name, td["args"])
			td["dirty"] = false


## Изменить герцовку в рантайме
func set_send_rate(action_name: String, hz: int) -> void:
	var pid := _find_id(action_name)
	if pid == -1:
		return

	if hz <= 0:
		_tick_data.erase(pid)
		return

	if pid not in _tick_data:
		_tick_data[pid] = {
			"args": [],
			"dirty": false,
			"accumulator": 0.0,
			"interval": 1.0 / float(hz),
		}
	else:
		_tick_data[pid]["interval"] = 1.0 / float(hz)


# ══════════════════════════════════════════════════
#  ПОЛУЧЕНИЕ
# ══════════════════════════════════════════════════

func _on_packet(peer_id: int, body: StreamPeerBuffer, pid: int) -> void:
	if pid not in GeneratedPackets.PACKETS:
		return

	# Rate limiting
	if not _check_rate_limit(peer_id, pid):
		return   # Молча отбрасываем

	var meta: Dictionary = GeneratedPackets.PACKETS[pid]
	var action_name: String = meta["name"]
	var read_fn := "read_%s" % action_name
	var data: Dictionary = _gp.call(read_fn, body)

	packet_received.emit(action_name, peer_id, data)

	if _net.is_server():
		_handle_server(pid, peer_id, data, meta)
	else:
		_handle_client(pid, peer_id, data)


func _handle_server(pid: int, peer_id: int, data: Dictionary, meta: Dictionary) -> void:
	if "peer_id" in data:
		data["peer_id"] = peer_id

	if meta["server_validates"] and pid in _validators:
		if not (_validators[pid] as Callable).call(peer_id, data):
			return

	if pid in _handlers:
		(_handlers[pid] as Callable).call(peer_id, data)

	var sync_mode: int = meta["sync_mode"]
	if sync_mode == 0:
		return

	var write_fn := "write_%s" % meta["name"]
	var field_names: Array = meta.get("field_names", [])
	var values := []
	for fname in field_names:
		values.append(data[fname])

	var pkt: PackedByteArray = _gp.callv(write_fn, values)
	var flags := _channel_flags(meta["channel"])

	match sync_mode:
		1: _net.broadcast(pkt, 0, flags)
		2: _net.broadcast_except(peer_id, pkt, 0, flags)
		3: _net.broadcast_except(peer_id, pkt, 0, flags)
		4: _net.send_to_peer(peer_id, pkt, 0, flags)


func _handle_client(pid: int, peer_id: int, data: Dictionary) -> void:
	if pid in _handlers:
		(_handlers[pid] as Callable).call(peer_id, data)


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

func clear_peer_data(peer_id: int) -> void:
	_rate_limits.erase(peer_id)
