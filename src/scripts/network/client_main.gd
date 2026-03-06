extends Node3D

const ADDRESS       := "127.0.0.1"
const PORT          := 9999
const PING_INTERVAL := 3.0

const PLAYER_SCENE        = preload("res://src/scripts/network/scenes/player.tscn")
const REMOTE_PLAYER_SCENE = preload("res://src/scripts/network/scenes/remote_player.tscn")

var _net          : NetworkManager
var _pm           : PlayerManager
var _nam          : NetworkActionManager
var _local_player : CharacterBody3D = null
var _my_id        : int = 0
var _ping_timer   : Timer


func _ready() -> void:
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

	_net.register_handler(PacketTypes.WELCOME,       _on_welcome)
	_net.register_handler(PacketTypes.PLAYER_JOINED, _on_player_joined)
	_net.register_handler(PacketTypes.PLAYER_LEFT,   _on_player_left)
	_net.register_handler(PacketTypes.PONG,          _on_pong)
	_net.register_handler(PacketTypes.AUTH_RESPONSE,  _on_auth_response)

	_nam.setup(_net)

	# ═══ АВТОПРИВЯЗКА ПОЛУЧАТЕЛЯ — ОДНА СТРОКА НА ВЕСЬ ПРОЕКТ ═══
	# Работает для ВСЕХ пакетов с receive_method в .tres
	# Новые пакеты подхватываются автоматически
	_nam.auto_bind_receiver(_pm)

	_ping_timer = Timer.new()
	_ping_timer.wait_time = PING_INTERVAL
	_ping_timer.autostart = false
	_ping_timer.timeout.connect(_send_ping)
	add_child(_ping_timer)

	var err := _net.create_client(ADDRESS, PORT)
	if err != OK:
		push_error("[client] Не удалось подключиться")
		get_tree().quit(1)


func _on_connected(_id: int) -> void:
	print("[client] Соединение установлено")
	_net.send_to_server(PacketTypes.write_auth_request("my_game_v1"))


func _on_auth_response(_peer_id: int, body: StreamPeerBuffer) -> void:
	var data := PacketTypes.read_auth_response(body)
	if not data["success"]:
		print("[client] Аутентификация отклонена: %s" % data["message"])
		_net.shutdown()


func _on_disconnected(_id: int) -> void:
	_cleanup()


func _cleanup() -> void:
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

	_local_player = PLAYER_SCENE.instantiate() as CharacterBody3D
	_local_player.name = "LocalPlayer"
	$World/Players.add_child(_local_player)
	_local_player.global_position = data["position"]
	_local_player.rotation.y = data["rotation"].y

	# ═══ АВТОПРИВЯЗКА ИСТОЧНИКА — ОДНА СТРОКА НА ВЕСЬ ПРОЕКТ ═══
	# Сканирует ВСЕ пакеты в PACKETS
	# Привязывает те, чей source_method есть у _local_player
	# Новые пакеты подхватываются автоматически
	_nam.auto_bind_source(_local_player, _my_id)

	_ping_timer.start()


func _on_player_joined(_peer_id: int, body: StreamPeerBuffer) -> void:
	var data := PacketTypes.read_player_joined(body)
	if data["id"] == _my_id:
		return
	_pm.add_player(data["id"], data["position"], data["rotation"])


func _on_player_left(_peer_id: int, body: StreamPeerBuffer) -> void:
	_pm.remove_player(PacketTypes.read_player_left(body)["id"])


func _on_pong(_peer_id: int, _body: StreamPeerBuffer) -> void:
	pass


func _send_ping() -> void:
	_net.send_to_server(PacketTypes.write_ping())


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_net.shutdown()
		get_tree().quit()
