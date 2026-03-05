extends Node3D

const ADDRESS       := "127.0.0.1"
const PORT          := 9999
const TICK_INTERVAL := 0.05
const PING_INTERVAL := 3.0

const PLAYER_SCENE        = preload("res://src/scripts/network/scenes/player.tscn")
const REMOTE_PLAYER_SCENE = preload("res://src/scripts/network/scenes/remote_player.tscn")

var _net          : NetworkManager
var _pm           : PlayerManager
var _nam          : NetworkActionManager
var _local_player : CharacterBody3D = null
var _my_id        : int = 0
var _tick_timer   : Timer
var _ping_timer   : Timer
var _address      : String = ADDRESS
var _port         : int    = PORT


func _ready() -> void:
	var args := CmdArgs.new()
	_address = args.get_string("--address", _address)
	_port    = args.get_int("--port", _port)

	_net = NetworkManager.new()
	_net.name = "NetworkManager"
	add_child(_net)

	_pm = PlayerManager.new()
	_pm.name = "PlayerManager"
	add_child(_pm)
	_pm.setup_client(REMOTE_PLAYER_SCENE, $World/Players)

	_nam = NetworkActionManager.new()
	_nam.name = "NetworkActionManager"
	add_child(_nam)

	_net.peer_connected.connect(_on_connected)
	_net.peer_disconnected.connect(_on_disconnected)

	# Базовые обработчики
	_net.register_handler(PacketTypes.WELCOME,       _on_welcome)
	_net.register_handler(PacketTypes.PLAYER_JOINED, _on_player_joined)
	_net.register_handler(PacketTypes.PLAYER_LEFT,   _on_player_left)
	_net.register_handler(PacketTypes.PONG,          _on_pong)

	# NAM — после базовых handler-ов
	_nam.setup(_net)

	# Подписка на player_move от других игроков
	_nam.on_action("player_move", _on_remote_player_move)

	# Таймеры
	_tick_timer = Timer.new()
	_tick_timer.wait_time = TICK_INTERVAL
	_tick_timer.autostart = false
	_tick_timer.timeout.connect(_on_tick)
	add_child(_tick_timer)

	_ping_timer = Timer.new()
	_ping_timer.wait_time = PING_INTERVAL
	_ping_timer.autostart = false
	_ping_timer.timeout.connect(_send_ping)
	add_child(_ping_timer)

	var err := _net.create_client(_address, _port)
	if err != OK:
		push_error("Не удалось подключиться!")
		get_tree().quit(1)


func _on_connected(_id: int) -> void:
	print("[client] Подключён, жду WELCOME…")


func _on_disconnected(_id: int) -> void:
	print("[client] Отключён")
	_cleanup()


func _cleanup() -> void:
	_tick_timer.stop()
	_ping_timer.stop()
	if _local_player:
		_local_player.queue_free()
		_local_player = null
	_pm.clear()
	_my_id = 0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_welcome(_peer_id: int, body: StreamPeerBuffer) -> void:
	var data := PacketTypes.read_welcome(body)
	_my_id = data["id"]
	_net.set_my_id(_my_id)
	var pos: Vector3 = data["position"]
	var rot: Vector3 = data["rotation"]
	print("[client] WELCOME! id=%d спавн=%s" % [_my_id, pos])
	_local_player = PLAYER_SCENE.instantiate() as CharacterBody3D
	_local_player.name = "LocalPlayer"
	$World/Players.add_child(_local_player)
	_local_player.global_position = pos
	_local_player.rotation.y = rot.y
	_tick_timer.start()
	_ping_timer.start()


func _on_player_joined(_peer_id: int, body: StreamPeerBuffer) -> void:
	var data := PacketTypes.read_player_joined(body)
	var id: int = data["id"]
	if id == _my_id: return
	_pm.add_player(id, data["position"], data["rotation"])


func _on_player_left(_peer_id: int, body: StreamPeerBuffer) -> void:
	var data := PacketTypes.read_player_left(body)
	_pm.remove_player(data["id"])


func _on_pong(_peer_id: int, _body: StreamPeerBuffer) -> void:
	pass


func _on_remote_player_move(_peer_id: int, data: Dictionary) -> void:
	var id: int = data["peer_id"]
	if id == _my_id: return
	var pos: Vector3 = data["position"]
	var rot := Vector3(data["head_pitch"], data["body_yaw"], 0.0)
	_pm.update_player(id, pos, rot)


func _on_tick() -> void:
	if _local_player == null or _my_id == 0: return
	var state: Dictionary = _local_player.get_network_state()
	# Используем сгенерированную функцию через NAM
	_nam.send_action("player_move", [
		_my_id,
		state["position"],
		state["rotation"].x,    # head_pitch
		state["rotation"].y,    # body_yaw
	])


func _send_ping() -> void:
	_net.send_to_server(PacketTypes.write_ping())


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_net.shutdown()
		get_tree().quit()
