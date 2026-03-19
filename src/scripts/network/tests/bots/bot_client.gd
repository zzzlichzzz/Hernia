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

var _my_id: int = 0
var _is_ready: bool = false

var _connect_delay_remaining: float = 0.0
var _connect_pending: bool = false

## Счётчик полученных коррекций (для диагностики)
var _corrections_received: int = 0


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
	_net.register_handler(PacketTypes.PONG, _noop)

	_nam.on_action("player_correction", _on_player_correction)

	_net.register_handler(PacketTypes.PLAYER_JOINED, _noop)
	_net.register_handler(PacketTypes.PLAYER_LEFT, _noop)
	_net.register_handler(PacketTypes.CHAMELEON_SYNC, _noop)
	_net.register_handler(PacketTypes.PLAYER_SNAPSHOT_BATCH, _noop)

	if connect_delay <= 0.0:
		_connect_now()
	else:
		_connect_delay_remaining = connect_delay
		_connect_pending = true


func _process(delta: float) -> void:
	if _connect_pending:
		_connect_delay_remaining -= delta
		if _connect_delay_remaining <= 0.0:
			_connect_pending = false
			_connect_now()


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


func get_corrections_received() -> int:
	return _corrections_received


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
	_corrections_received = 0

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
	_corrections_received += 1
	if _bot != null:
		_bot.apply_correction_state(peer_id, data)


func _noop(_peer_id: int, _body: StreamPeerBuffer) -> void:
	pass
