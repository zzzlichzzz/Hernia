extends Node3D
## Клиент. Поддерживает аргументы:
##   --address <ip>    Адрес сервера (по умолчанию 127.0.0.1)
##   --port <число>    Порт сервера (по умолчанию 9999)

const TICK_INTERVAL := 0.05
const PING_INTERVAL := 3.0

const PLAYER_SCENE        = preload("res://src/scripts/network/scenes/player.tscn")
const REMOTE_PLAYER_SCENE = preload("res://src/scripts/network/scenes/remote_player.tscn")

var _net          : NetworkManager
var _pm           : PlayerManager
var _local_player : CharacterBody3D = null
var _my_id        : int = 0
var _tick_timer   : Timer
var _ping_timer   : Timer

var _address : String = "127.0.0.1"
var _port    : int    = 9999


func _ready() -> void:
	# ── CLI аргументы ─────────────────────────────
	var args := CmdArgs.new()
	_address = args.get_string("--address", _address)
	_port    = args.get_int("--port", _port)

	# ── Сеть ──────────────────────────────────────
	_net = NetworkManager.new()
	_net.name = "NetworkManager"
	add_child(_net)

	# ── Менеджер игроков ──────────────────────────
	_pm = PlayerManager.new()
	_pm.name = "PlayerManager"
	add_child(_pm)
	_pm.setup_client(REMOTE_PLAYER_SCENE, $World/Players)

	# ── Сигналы ──────────────────────────────────
	_net.peer_connected.connect(_on_connected)
	_net.peer_disconnected.connect(_on_disconnected)

	# ── Обработчики пакетов ──────────────────────
	_net.register_handler(PacketTypes.WELCOME,       _on_welcome)
	_net.register_handler(PacketTypes.PLAYER_JOINED, _on_player_joined)
	_net.register_handler(PacketTypes.PLAYER_LEFT,   _on_player_left)
	_net.register_handler(PacketTypes.PLAYER_UPDATE, _on_player_update)
	_net.register_handler(PacketTypes.PONG,          _on_pong)

	# ── Таймеры ──────────────────────────────────
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

	# ── Подключение ──────────────────────────────
	var err := _net.create_client(_address, _port)
	if err != OK:
		push_error("Не удалось подключиться к %s:%d!" % [_address, _port])
		get_tree().quit(1)


# ══════════════════════════════════════════════════
#  ПОДКЛЮЧЕНИЕ / ОТКЛЮЧЕНИЕ
# ══════════════════════════════════════════════════

func _on_connected(_id: int) -> void:
	print("[client] Подключён к %s:%d, жду WELCOME…" % [_address, _port])


func _on_disconnected(_id: int) -> void:
	print("[client] Отключён от сервера")
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
	print("[client] Состояние очищено")


# ══════════════════════════════════════════════════
#  ОБРАБОТЧИКИ ПАКЕТОВ
# ══════════════════════════════════════════════════

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
	if id == _my_id:
		return
	print("[client] Игрок %d присоединился в %s" % [id, data["position"]])
	_pm.add_player(id, data["position"], data["rotation"])


func _on_player_left(_peer_id: int, body: StreamPeerBuffer) -> void:
	var data := PacketTypes.read_player_left(body)
	print("[client] Игрок %d ушёл" % data["id"])
	_pm.remove_player(data["id"])


func _on_player_update(_peer_id: int, body: StreamPeerBuffer) -> void:
	var data := PacketTypes.read_player_update(body)
	var id: int = data["id"]
	if id == _my_id:
		return
	_pm.update_player(id, data["position"], data["rotation"])


func _on_pong(_peer_id: int, _body: StreamPeerBuffer) -> void:
	pass


# ══════════════════════════════════════════════════
#  ТИКИ
# ══════════════════════════════════════════════════

func _on_tick() -> void:
	if _local_player == null or _my_id == 0:
		return
	var state: Dictionary = _local_player.get_network_state()
	var pkt := PacketTypes.write_player_update(
		_my_id, state["position"], state["rotation"])
	_net.send_to_server(pkt, 0, ENetPacketPeer.FLAG_UNSEQUENCED)


func _send_ping() -> void:
	_net.send_to_server(PacketTypes.write_ping())


# ══════════════════════════════════════════════════

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_net.shutdown()
		get_tree().quit()
