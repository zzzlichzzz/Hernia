extends Node3D

const ADDRESS    := "127.0.0.1"
const PORT       := 9999
const TICK_RATE  := 20
const PING_INTERVAL := 3.0

const PLAYER_SCENE        = preload("res://src/scripts/network/scenes/player.tscn")
const REMOTE_PLAYER_SCENE = preload("res://src/scripts/network/scenes/remote_player.tscn")

var _net          : NetworkManager
var _pm           : PlayerManager
var _nam          : NetworkActionManager
var _local_player : CharacterBody3D = null
var _my_id        : int = 0
var _ping_timer   : Timer

# Tick rate
var _tick_accumulator : float = 0.0
var _tick_interval    : float = 1.0 / float(TICK_RATE)


func _ready() -> void:
	print("═══════════════════════════════════════")
	print("[client] Запуск клиента")
	print("[client] Адрес: %s:%d" % [ADDRESS, PORT])
	print("[client] Tick rate: %d Гц" % TICK_RATE)
	print("═══════════════════════════════════════")

	# ── Сеть ──────────────────────────────────────
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

	# ── Базовые обработчики (хардкод-пакеты) ─────
	_net.register_handler(PacketTypes.WELCOME,       _on_welcome)
	_net.register_handler(PacketTypes.PLAYER_JOINED, _on_player_joined)
	_net.register_handler(PacketTypes.PLAYER_LEFT,   _on_player_left)
	_net.register_handler(PacketTypes.PONG,          _on_pong)

	# ── NAM (генерируемые пакеты) ─────────────────
	_nam.setup(_net)
	_nam.on_action("player_move", _on_remote_player_move)

	# ── Ping таймер ───────────────────────────────
	_ping_timer = Timer.new()
	_ping_timer.wait_time = PING_INTERVAL
	_ping_timer.autostart = false
	_ping_timer.timeout.connect(_send_ping)
	add_child(_ping_timer)

	# ── Подключение ───────────────────────────────
	var err := _net.create_client(ADDRESS, PORT)
	if err != OK:
		push_error("[client] Не удалось подключиться! Error: %d" % err)
		get_tree().quit(1)


# ══════════════════════════════════════════════════
#  СОБЫТИЯ СЕТИ
# ══════════════════════════════════════════════════

func _on_connected(_id: int) -> void:
	print("[client] ✓ Соединение установлено, жду WELCOME...")


func _on_disconnected(_id: int) -> void:
	print("[client] ✗ Отключён от сервера")
	_cleanup()


func _cleanup() -> void:
	_ping_timer.stop()
	if _local_player:
		_local_player.queue_free()
		_local_player = null
	_pm.clear()
	_my_id = 0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# ══════════════════════════════════════════════════
#  ХАРДКОД-ПАКЕТЫ (от сервера)
# ══════════════════════════════════════════════════

func _on_welcome(_peer_id: int, body: StreamPeerBuffer) -> void:
	var data := PacketTypes.read_welcome(body)
	_my_id = data["id"]
	_net.set_my_id(_my_id)
	var pos: Vector3 = data["position"]
	var rot: Vector3 = data["rotation"]

	print("[client] ✓ WELCOME: id=%d pos=%s" % [_my_id, pos])

	_local_player = PLAYER_SCENE.instantiate() as CharacterBody3D
	_local_player.name = "LocalPlayer"
	$World/Players.add_child(_local_player)
	_local_player.global_position = pos
	_local_player.rotation.y = rot.y

	_ping_timer.start()
	print("[client] ✓ Готов к игре! WASD + мышь")


func _on_player_joined(_peer_id: int, body: StreamPeerBuffer) -> void:
	var data := PacketTypes.read_player_joined(body)
	var id: int = data["id"]
	if id == _my_id:
		return
	print("[client] → Игрок %d присоединился" % id)
	_pm.add_player(id, data["position"], data["rotation"])


func _on_player_left(_peer_id: int, body: StreamPeerBuffer) -> void:
	var data := PacketTypes.read_player_left(body)
	print("[client] → Игрок %d вышел" % data["id"])
	_pm.remove_player(data["id"])


func _on_pong(_peer_id: int, _body: StreamPeerBuffer) -> void:
	pass


# ══════════════════════════════════════════════════
#  ГЕНЕРИРУЕМЫЕ ПАКЕТЫ (через NAM)
# ══════════════════════════════════════════════════

func _on_remote_player_move(_peer_id: int, data: Dictionary) -> void:
	# _peer_id = SERVER_ID (пакет пришёл от сервера)
	# Реальный ID отправителя — в data["peer_id"] (защищён сервером)
	var id: int = data["peer_id"]
	if id == _my_id:
		return

	var pos: Vector3 = data["position"]
	var rot := Vector3(data["head_pitch"], data["body_yaw"], 0.0)
	_pm.update_player(id, pos, rot)


# ══════════════════════════════════════════════════
#  ИГРОВОЙ ЦИКЛ
# ══════════════════════════════════════════════════

func _physics_process(delta: float) -> void:
	if _local_player == null or _my_id == 0:
		return

	_tick_accumulator += delta
	if _tick_accumulator >= _tick_interval:
		_tick_accumulator -= _tick_interval

		var state: Dictionary = _local_player.get_network_state()
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
		print("[client] Завершение работы...")
		_net.shutdown()
		get_tree().quit()
