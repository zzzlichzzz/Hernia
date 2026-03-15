class_name BotClient
extends Node

signal bot_ready(peer_id: int)
signal bot_disconnected(peer_id: int)

var address: String = "127.0.0.1"
var port: int = 9999
var connect_delay: float = 0.0
var bot_index: int = 0
var bot_mode: int = BotVirtualPlayer.Mode.CIRCLE
var auth_token: String = "my_game_v1"

var movement_start_delay: float = 5.0

var _net: NetworkManager = null
var _nam: NetworkActionManager = null
var _bot: BotVirtualPlayer = null
var _connect_timer: Timer = null

var _my_id: int = 0
var _is_ready: bool = false


func setup(
	p_address: String,
	p_port: int,
	p_bot_index: int,
	p_bot_mode: int,
	p_connect_delay: float,
	p_auth_token: String = "my_game_v1",
	p_movement_start_delay: float = 5.0
) -> void:
	address = p_address
	port = p_port
	bot_index = p_bot_index
	bot_mode = p_bot_mode
	connect_delay = p_connect_delay
	auth_token = p_auth_token
	movement_start_delay = p_movement_start_delay


func _ready() -> void:
	_net = NetworkManager.new()
	_net.name = "NetworkManager"
	add_child(_net)

	_nam = NetworkActionManager.new()
	_nam.name = "NetworkActionManager"
	add_child(_nam)
	_nam.setup(_net)

	_net.peer_connected.connect(_on_connected)
	_net.peer_disconnected.connect(_on_disconnected)

	_net.register_handler(PacketTypes.AUTH_RESPONSE, _on_auth_response)
	_net.register_handler(PacketTypes.WELCOME, _on_welcome)
	_net.register_handler(PacketTypes.PONG, _on_pong)

	# Correction для владельца через NAM action handler.
	_nam.on_action("player_correction", Callable(self, "_on_player_correction"))

	# Эти пакеты можно игнорировать — они нужны только для того,
	# чтобы сервер создавал реальную нагрузку репликации.
	_net.register_handler(PacketTypes.PLAYER_JOINED, _ignore_packet)
	_net.register_handler(PacketTypes.PLAYER_LEFT, _ignore_packet)
	_net.register_handler(PacketTypes.CHAMELEON_SYNC, _ignore_packet)
	_net.register_handler(PacketTypes.PLAYER_SNAPSHOT_BATCH, _ignore_packet)

	_connect_timer = Timer.new()
	_connect_timer.name = "ConnectTimer"
	_connect_timer.one_shot = true
	_connect_timer.wait_time = maxf(connect_delay, 0.0)
	_connect_timer.timeout.connect(_connect_now)
	add_child(_connect_timer)

	if connect_delay <= 0.0:
		_connect_now()
	else:
		_connect_timer.start()


func shutdown_bot() -> void:
	if _nam != null:
		_nam.clear_sources()

	if _bot != null and is_instance_valid(_bot):
		_bot.queue_free()
	_bot = null

	_my_id = 0
	_is_ready = false

	if _net != null:
		_net.shutdown()


func is_ready_for_test() -> bool:
	return _is_ready


func get_my_id() -> int:
	return _my_id


func _connect_now() -> void:
	var err := _net.create_client(address, port)
	if err != OK:
		push_warning("[bot %d] connect failed: %s" % [bot_index, error_string(err)])


func _on_connected(_id: int) -> void:
	_net.send_to_server(PacketTypes.write_auth_request(auth_token))


func _on_disconnected(_id: int) -> void:
	var old_id := _my_id
	_nam.clear_sources()

	if _bot != null and is_instance_valid(_bot):
		_bot.queue_free()
	_bot = null

	_my_id = 0
	_is_ready = false

	bot_disconnected.emit(old_id)


func _on_auth_response(_peer_id: int, body: StreamPeerBuffer) -> void:
	var data := PacketTypes.read_auth_response(body)
	if not data["success"]:
		push_warning("[bot %d] auth failed: %s" % [bot_index, data["message"]])
		_net.shutdown()


func _on_welcome(_peer_id: int, body: StreamPeerBuffer) -> void:
	var data := PacketTypes.read_welcome(body)

	_my_id = data["id"]
	_net.set_my_id(_my_id)

	_nam.clear_sources()

	if _bot != null and is_instance_valid(_bot):
		_bot.queue_free()

	_bot = BotVirtualPlayer.new()
	_bot.name = "BotVirtualPlayer_%d" % bot_index
	_bot.network_id = _my_id
	_bot.movement_start_delay = movement_start_delay
	add_child(_bot)

	var spawn_position: Vector3 = data["position"]
	var seed_value: int = 100000 + bot_index
	_bot.configure(spawn_position, bot_mode, seed_value)

	_nam.auto_bind_source(_bot, _my_id)

	_is_ready = true
	bot_ready.emit(_my_id)


func _on_player_correction(peer_id: int, data: Dictionary) -> void:
	if _bot != null and is_instance_valid(_bot):
		_bot.apply_correction_state(peer_id, data)


func _on_pong(_peer_id: int, _body: StreamPeerBuffer) -> void:
	pass


func _ignore_packet(_peer_id: int, _body: StreamPeerBuffer) -> void:
	pass
