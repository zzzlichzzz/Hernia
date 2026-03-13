extends Node

const PORT         := 9999
const MAX_CLIENTS  := 32
const SPAWN_Y      := 2.0
const SERVER_TOKEN := "my_game_v1"
const AUTH_TIMEOUT := 5.0

const MAX_VIOLATIONS  := 10
const VIOLATION_DECAY := 30.0

var _net : NetworkManager = null
var _pm  : PlayerManager = null
var _nam : NetworkActionManager = null

var _replication: PlayerReplicationManager = null
var _auth: ServerAuthManager = null

var _chameleon_state: Dictionary = {}   # Vector3i → int (source_block_id)
var _authenticated  : Dictionary = {}   # peer_id -> bool (ссылка, её использует auth manager)
var _security_log   : Dictionary = {}
var _violations     : Dictionary = {}

## peer_id -> session data
## {
##   "spawn_position": Vector3,
##   "spawn_rotation": Vector3,
##   "character_id": ...,
##   "race_id": "human",
##   "world_id": "default_world",
## }
var _player_sessions: Dictionary = {}


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

	_replication = PlayerReplicationManager.new()
	_replication.name = "PlayerReplicationManager"
	add_child(_replication)
	_replication.setup(_net, _pm, _authenticated)

	_auth = ServerAuthManager.new()
	_auth.name = "ServerAuthManager"
	add_child(_auth)
	_auth.setup(_net, _authenticated, AUTH_TIMEOUT, SERVER_TOKEN, SPAWN_Y)

	# Если позже появится master server / transfer token validation,
	# достаточно будет подставить внешний валидатор:
	# _auth.set_validator(_validate_external_auth)

	_net.peer_connected.connect(_auth.on_peer_connected)
	_net.peer_disconnected.connect(_on_peer_disconnected)

	_auth.peer_authenticated.connect(_on_peer_authenticated)
	_auth.peer_auth_failed.connect(_on_peer_auth_failed)
	_auth.peer_auth_timeout.connect(_on_peer_auth_timeout)

	_net.register_handler(PacketTypes.PING, _on_ping)
	_net.register_handler(PacketTypes.AUTH_REQUEST, _auth.handle_auth_request)

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
	if _auth != null:
		_auth.tick()

	if _replication != null:
		_replication.tick(delta)


# ══════════════════════════════════════════════════
#  AUTH / SESSION
# ══════════════════════════════════════════════════

func _on_peer_authenticated(peer_id: int, session_data: Dictionary) -> void:
	_player_sessions[peer_id] = session_data.duplicate(true)

	var pos: Vector3 = session_data.get("spawn_position", Vector3.ZERO)
	var rot: Vector3 = session_data.get("spawn_rotation", Vector3.ZERO)

	_net.send_to_peer(peer_id, PacketTypes.write_welcome(peer_id, pos, rot))

	_pm.add_player(peer_id, pos, rot)

	if _replication != null:
		_replication.on_player_spawned(peer_id)
		_replication.refresh_visibility_now()

	_send_chameleon_sync(peer_id)

	var race_id: String = session_data.get("race_id", "unknown")
	var world_id: String = session_data.get("world_id", "unknown")
	print("[server] peer=%d authenticated, race=%s world=%s" % [peer_id, race_id, world_id])


func _on_peer_auth_failed(peer_id: int, message: String) -> void:
	print("[server] auth failed for peer=%d: %s" % [peer_id, message])


func _on_peer_auth_timeout(peer_id: int) -> void:
	print("[server] auth timeout for peer=%d" % peer_id)


func get_player_session(peer_id: int) -> Dictionary:
	return _player_sessions.get(peer_id, {})


# ══════════════════════════════════════════════════
#  WORLD SYNC
# ══════════════════════════════════════════════════

func _send_chameleon_sync(peer_id: int) -> void:
	if _chameleon_state.is_empty():
		return

	var body := PacketTypes.write_chameleon_sync_body(_chameleon_state)

	_net.send_fragmented_to_peer(
		peer_id,
		PacketTypes.CHAMELEON_SYNC,
		body,
		0,
		ENetPacketPeer.FLAG_RELIABLE
	)


func _on_chameleon_paint(_peer_id: int, data: Dictionary) -> void:
	var pos := Vector3i(data["block_position"])
	var block_id: int = data["source_block_id"]
	_chameleon_state[pos] = block_id


func _on_block_break(_peer_id: int, data: Dictionary) -> void:
	var pos := Vector3i(data["block_position"])
	_chameleon_state.erase(pos)


# ══════════════════════════════════════════════════
#  CONNECTION / DISCONNECT
# ══════════════════════════════════════════════════

func _on_peer_disconnected(id: int) -> void:
	if _replication != null:
		_replication.on_player_disconnected(id)

	if _auth != null:
		_auth.clear_peer(id)

	_pm.remove_player(id)
	_player_sessions.erase(id)
	_violations.erase(id)
	_nam.clear_peer_data(id)


func _on_ping(peer_id: int, _body: StreamPeerBuffer) -> void:
	_net.send_to_peer(peer_id, PacketTypes.write_pong())


# ══════════════════════════════════════════════════
#  SECURITY
# ══════════════════════════════════════════════════

func _on_security_kick(peer_id: int, _reason: String) -> void:
	_net.kick_peer(peer_id)


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


func get_security_log() -> Dictionary:
	return _security_log


# ══════════════════════════════════════════════════
#  GAMEPLAY HANDLERS
# ══════════════════════════════════════════════════

func _on_player_move(peer_id: int, data: Dictionary) -> void:
	var pos: Vector3 = data["position"]
	var head_pitch: float = data["head_pitch"]
	var body_yaw: float = data["body_yaw"]
	var tick: int = int(data.get("tick", 0))

	if _replication != null:
		_replication.on_authoritative_move(peer_id, tick)

	_nam.send_action_to(peer_id, "player_correction", [
		peer_id,
		tick,
		pos,
		head_pitch,
		body_yaw,
	])


# ══════════════════════════════════════════════════
#  FUTURE MASTER / TRANSFER HOOK
# ══════════════════════════════════════════════════

## Пример будущего внешнего валидатора для master server / transfer token.
## Пока не используется.
# func _validate_external_auth(peer_id: int, token: String) -> Dictionary:
# 	# Здесь позже можно:
# 	# - проверить token у master server
# 	# - получить world_id / character_id / race_id
# 	# - получить spawn_position после transfer между мирами
# 	return {
# 		"success": token != "",
# 		"message": "Bad token" if token == "" else "",
# 		"spawn_position": Vector3(0, SPAWN_Y, 0),
# 		"spawn_rotation": Vector3.ZERO,
# 		"character_id": peer_id,
# 		"race_id": "human",
# 		"world_id": "default_world",
# 	}


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		for id: int in _pm.get_all_ids():
			_net.send_to_peer(id, PacketTypes.write_player_left(id))

		if _net != null and _net._host != null:
			_net._host.flush()

		if _replication != null:
			_replication.clear()

		if _net != null:
			_net.shutdown()

		get_tree().quit(0)
