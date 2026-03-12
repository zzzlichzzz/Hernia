extends Node

const PORT         := 9999
const MAX_CLIENTS  := 32
const SPAWN_Y      := 2.0
const SERVER_TOKEN := "my_game_v1"
const AUTH_TIMEOUT  := 5.0

const REPLICATION_TPS := 30.0

const LOD_NEAR_DISTANCE := 20.0
const LOD_MID_DISTANCE  := 45.0
const LOD_FAR_DISTANCE  := 90.0

const LOD_NEAR_HZ      := 20.0
const LOD_MID_HZ       := 10.0
const LOD_FAR_HZ       := 5.0
const LOD_VERY_FAR_HZ  := 2.0

const MAX_VIOLATIONS  := 10
const VIOLATION_DECAY := 30.0

var _net : NetworkManager        = null
var _pm  : PlayerManager         = null
var _nam : NetworkActionManager  = null

var _chameleon_state: Dictionary = {}   # Vector3i → int (source_block_id)
var _authenticated  : Dictionary = {}
var _connect_time   : Dictionary = {}
var _security_log   : Dictionary = {}

var _violations : Dictionary = {}

var _replication_accumulator: float = 0.0
var _replication_time: float = 0.0
var _replication_last_send: Dictionary = {} # observer_id -> { target_id -> last_send_time }
var _replication_last_tick: Dictionary = {} # observer_id -> { target_id -> last_sent_tick }
var _authoritative_move_ticks: Dictionary = {} # target_id -> latest authoritative movement tick

func _ready() -> void:
	get_tree().auto_accept_quit = false

	_net = NetworkManager.new()
	_net.name = "NetworkManager"
	add_child(_net)

	_pm = PlayerManager.new()
	_pm.name = "PlayerManager"
	add_child(_pm)

	_nam = NetworkActionManager.new()
	_nam.name = "NetworkActionManager"
	add_child(_nam)

	_net.peer_connected.connect(_on_peer_connected)
	_net.peer_disconnected.connect(_on_peer_disconnected)
	_net.register_handler(PacketTypes.PING, _on_ping)
	_net.register_handler(PacketTypes.AUTH_REQUEST, _on_auth_request)

	_nam.setup(_net)
	_nam.set_kick_callback(_on_security_kick)
	_nam.setup_server_context(_pm, _authenticated, _on_violation)
	_nam.auto_bind_server(self)

	var err := _net.create_server(PORT, MAX_CLIENTS)
	if err != OK:
		push_error("[server] Не удалось создать сервер")
		get_tree().quit(1)
		return

	print("[server] Запущен на порту %d" % PORT)

	# ═══ HUD ═══
	$ServerHUD.setup(_net, _pm, _nam)

func _process(delta: float) -> void:
	_check_auth_timeout()

	_replication_time += delta
	_replication_accumulator += delta

	var step := 1.0 / REPLICATION_TPS
	while _replication_accumulator >= step:
		_replication_accumulator -= step
		_replicate_player_snapshots()


# ══════════════════════════════════════════════════
#  АУТЕНТИФИКАЦИЯ
# ══════════════════════════════════════════════════

func _on_peer_connected(id: int) -> void:
	_authenticated[id] = false
	_connect_time[id] = Time.get_unix_time_from_system()


func _check_auth_timeout() -> void:
	var now := Time.get_unix_time_from_system()
	var to_kick: Array[int] = []
	for id: int in _connect_time:
		if not _authenticated.get(id, false):
			if now - _connect_time[id] > AUTH_TIMEOUT:
				to_kick.append(id)
	for id: int in to_kick:
		_net.kick_peer(id)
		_connect_time.erase(id)


func _on_auth_request(peer_id: int, body: StreamPeerBuffer) -> void:
	var data := PacketTypes.read_auth_request(body)
	if data["token"] != SERVER_TOKEN:
		_net.send_to_peer(peer_id, PacketTypes.write_auth_response(false, "Bad token"))
		await get_tree().create_timer(0.5).timeout
		_net.kick_peer(peer_id)
		return

	_authenticated[peer_id] = true
	_connect_time.erase(peer_id)
	_net.send_to_peer(peer_id, PacketTypes.write_auth_response(true))

	var pos := Vector3(randf_range(-5.0, 5.0), SPAWN_Y, randf_range(-5.0, 5.0))
	var rot := Vector3.ZERO
	_net.send_to_peer(peer_id, PacketTypes.write_welcome(peer_id, pos, rot))

	for eid: int in _pm.get_all_ids():
		var d: Dictionary = _pm.get_player_data(eid)
		_net.send_to_peer(peer_id, PacketTypes.write_player_joined(
			eid, d["position"], d["rotation"]))

	_pm.add_player(peer_id, pos, rot)
	_authoritative_move_ticks[peer_id] = 0
	_net.broadcast_except(peer_id, PacketTypes.write_player_joined(peer_id, pos, rot))

	# ── Хамелеоны: начальная синхронизация ────
	_send_chameleon_sync(peer_id)

func _send_chameleon_sync(peer_id: int) -> void:
	if _chameleon_state.is_empty():
		return
	var body := PacketTypes.write_chameleon_sync_body(_chameleon_state)
	# Автофрагментация при большом количестве
	_net.send_fragmented_to_peer(
		peer_id,
		PacketTypes.CHAMELEON_SYNC,
		body,
		0,
		ENetPacketPeer.FLAG_RELIABLE
	)

func _on_peer_disconnected(id: int) -> void:
	_pm.remove_player(id)
	_net.broadcast(PacketTypes.write_player_left(id))
	_authenticated.erase(id)
	_connect_time.erase(id)
	_violations.erase(id)
	_nam.clear_peer_data(id)
	_cleanup_replication_peer(id)


func _on_ping(peer_id: int, _body: StreamPeerBuffer) -> void:
	_net.send_to_peer(peer_id, PacketTypes.write_pong())


func _on_security_kick(peer_id: int, reason: String) -> void:
	_net.kick_peer(peer_id)

func _on_chameleon_paint(peer_id: int, data: Dictionary) -> void:
	var pos := Vector3i(data["block_position"])
	var block_id: int = data["source_block_id"]
	_chameleon_state[pos] = block_id

func _on_block_break(peer_id: int, data: Dictionary) -> void:
	var pos := Vector3i(data["block_position"])
	_chameleon_state.erase(pos)
# ══════════════════════════════════════════════════
#  НАРУШЕНИЯ
# ══════════════════════════════════════════════════

func _on_violation(peer_id: int, reason: String) -> void:
	var now := Time.get_unix_time_from_system()
	if peer_id not in _violations:
		_violations[peer_id] = []
	var fresh: Array = []
	for t in _violations[peer_id]:
		if now - t < VIOLATION_DECAY:
			fresh.append(t)
	fresh.append(now)
	_violations[peer_id] = fresh
	_security_log[reason] = _security_log.get(reason, 0) + 1
	if fresh.size() >= MAX_VIOLATIONS:
		_net.kick_peer(peer_id)


# ══════════════════════════════════════════════════
#  ОБРАБОТЧИКИ (auto_bind_server находит по имени)
#
#  Для player_move — вся валидация в .tres (автоматически).
#  _on_player_move нужен только для обновления PlayerManager.
#
#  При добавлении нового пакета:
#  1. Создать .tres с правилами валидации
#  2. F6
#  3. Добавить _on_<name>() ТОЛЬКО если нужна серверная логика
#  4. _validate_<name>() ТОЛЬКО если нужна ДОПОЛНИТЕЛЬНАЯ проверка
#     сверх того что описано в .tres
# ══════════════════════════════════════════════════

func _on_player_move(peer_id: int, data: Dictionary) -> void:
	var pos: Vector3 = data["position"]
	var head_pitch: float = data["head_pitch"]
	var body_yaw: float = data["body_yaw"]
	var tick: int = int(data.get("tick", 0))

	_authoritative_move_ticks[peer_id] = tick

	_nam.send_action_to(peer_id, "player_correction", [
		peer_id,
		tick,
		pos,
		head_pitch,
		body_yaw,
	])

func _replicate_player_snapshots() -> void:
	var ids: Array = _pm.get_all_ids()
	if ids.size() <= 1:
		return

	for observer_var in ids:
		var observer_id: int = int(observer_var)

		if not _authenticated.get(observer_id, false):
			continue
		if not _pm.has_player(observer_id):
			continue

		var observer_data: Dictionary = _pm.get_player_data(observer_id)
		var observer_pos: Vector3 = observer_data.get("position", Vector3.ZERO)

		if observer_id not in _replication_last_send:
			_replication_last_send[observer_id] = {}
		if observer_id not in _replication_last_tick:
			_replication_last_tick[observer_id] = {}

		var send_map: Dictionary = _replication_last_send[observer_id]
		var tick_map: Dictionary = _replication_last_tick[observer_id]

		for target_var in ids:
			var target_id: int = int(target_var)

			if target_id == observer_id:
				continue
			if not _authenticated.get(target_id, false):
				continue
			if not _pm.has_player(target_id):
				continue

			var target_tick: int = int(_authoritative_move_ticks.get(target_id, -1))
			if target_tick < 0:
				continue

			var target_data: Dictionary = _pm.get_player_data(target_id)
			var target_pos: Vector3 = target_data.get("position", Vector3.ZERO)
			var target_rot: Vector3 = target_data.get("rotation", Vector3.ZERO)

			var distance := observer_pos.distance_to(target_pos)
			var hz := _get_replication_hz(distance)
			if hz <= 0.0:
				continue

			var last_tick_sent: int = int(tick_map.get(target_id, -1))
			if last_tick_sent == target_tick:
				continue

			var interval := 1.0 / hz
			var last_send_time: float = float(send_map.get(target_id, -1.0))
			if last_send_time >= 0.0 and (_replication_time - last_send_time) < interval:
				continue

			_nam.send_action_to(observer_id, "player_snapshot", [
				target_id,
				target_tick,
				target_pos,
				target_rot.x,
				target_rot.y,
			])

			send_map[target_id] = _replication_time
			tick_map[target_id] = target_tick

func _get_replication_hz(distance: float) -> float:
	if distance <= LOD_NEAR_DISTANCE:
		return LOD_NEAR_HZ
	if distance <= LOD_MID_DISTANCE:
		return LOD_MID_HZ
	if distance <= LOD_FAR_DISTANCE:
		return LOD_FAR_HZ
	return LOD_VERY_FAR_HZ

func _cleanup_replication_peer(peer_id: int) -> void:
	_replication_last_send.erase(peer_id)
	_replication_last_tick.erase(peer_id)
	_authoritative_move_ticks.erase(peer_id)

	for observer_id in _replication_last_send.keys():
		var send_map: Dictionary = _replication_last_send[observer_id]
		send_map.erase(peer_id)

	for observer_id in _replication_last_tick.keys():
		var tick_map: Dictionary = _replication_last_tick[observer_id]
		tick_map.erase(peer_id)

func get_security_log() -> Dictionary:
	return _security_log

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		for id: int in _pm.get_all_ids():
			_net.send_to_peer(id, PacketTypes.write_player_left(id))
		if _net != null and _net._host != null:
			_net._host.flush()
		if _net != null:
			_net.shutdown()
		get_tree().quit(0)
