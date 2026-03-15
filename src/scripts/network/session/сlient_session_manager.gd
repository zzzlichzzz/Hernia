class_name ClientSessionManager
extends Node

signal session_ready(my_id: int)
signal session_disconnected()
signal auth_failed(message: String)

const PING_INTERVAL := 3.0
const AUTH_TOKEN := "my_game_v1"

var _net: NetworkManager = null
var _world_runtime: ClientWorldRuntimeManager = null
var _ping_timer: Timer = null


func setup(
	net: NetworkManager,
	world_runtime: ClientWorldRuntimeManager
) -> void:
	_net = net
	_world_runtime = world_runtime

	_register_network_handlers()
	_ensure_ping_timer()

	if _world_runtime != null and not _world_runtime.world_ready.is_connected(_on_world_ready):
		_world_runtime.world_ready.connect(_on_world_ready)


func connect_to_server(address: String, port: int) -> Error:
	if _net == null:
		return ERR_UNCONFIGURED
	return _net.create_client(address, port)


func shutdown_session() -> void:
	if _ping_timer != null and is_instance_valid(_ping_timer):
		_ping_timer.stop()

	if _world_runtime != null:
		_world_runtime.clear_world()


func get_my_id() -> int:
	if _world_runtime != null:
		return _world_runtime.get_my_id()
	return 0


# ══════════════════════════════════════════════════
#  SETUP
# ══════════════════════════════════════════════════

func _register_network_handlers() -> void:
	if not _net.peer_connected.is_connected(_on_connected):
		_net.peer_connected.connect(_on_connected)

	if not _net.peer_disconnected.is_connected(_on_disconnected):
		_net.peer_disconnected.connect(_on_disconnected)

	_net.register_handler(PacketTypes.AUTH_RESPONSE, _on_auth_response)
	_net.register_handler(PacketTypes.PONG, _on_pong)


func _ensure_ping_timer() -> void:
	if _ping_timer != null and is_instance_valid(_ping_timer):
		return

	_ping_timer = Timer.new()
	_ping_timer.name = "PingTimer"
	_ping_timer.wait_time = PING_INTERVAL
	_ping_timer.autostart = false
	_ping_timer.one_shot = false
	_ping_timer.timeout.connect(_send_ping)
	add_child(_ping_timer)


# ══════════════════════════════════════════════════
#  CONNECTION / AUTH
# ══════════════════════════════════════════════════

func _on_connected(_id: int) -> void:
	print("[client] Соединение установлено")
	_net.send_to_server(PacketTypes.write_auth_request(AUTH_TOKEN))


func _on_disconnected(_id: int) -> void:
	if _ping_timer != null and is_instance_valid(_ping_timer):
		_ping_timer.stop()

	if _world_runtime != null:
		_world_runtime.on_connection_lost()

	session_disconnected.emit()


func _on_auth_response(_peer_id: int, body: StreamPeerBuffer) -> void:
	var data := PacketTypes.read_auth_response(body)
	if not data["success"]:
		var message: String = data["message"]
		print("[client] Аутентификация отклонена: %s" % message)
		auth_failed.emit(message)

		if _ping_timer != null and is_instance_valid(_ping_timer):
			_ping_timer.stop()

		if _world_runtime != null:
			_world_runtime.clear_world()

		if _net != null:
			_net.shutdown()


# ══════════════════════════════════════════════════
#  WORLD SESSION HOOKS
# ══════════════════════════════════════════════════

func _on_world_ready(my_id: int) -> void:
	if _ping_timer != null and is_instance_valid(_ping_timer):
		_ping_timer.start()

	session_ready.emit(my_id)


# ══════════════════════════════════════════════════
#  HEARTBEAT
# ══════════════════════════════════════════════════

func _on_pong(_peer_id: int, _body: StreamPeerBuffer) -> void:
	pass


func _send_ping() -> void:
	if _net != null:
		_net.send_to_server(PacketTypes.write_ping())
