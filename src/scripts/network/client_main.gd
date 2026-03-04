extends Node3D

const ADDRESS       := "127.0.0.1"
const PORT          := 9999
const TICK_INTERVAL := 0.05          # 50 мс → 20 Гц

const PLAYER_SCENE        = preload("res://src/scripts/network/scenes/player.tscn")
const REMOTE_PLAYER_SCENE = preload("res://src/scripts/network/scenes/remote_player.tscn")

var _net          : NetworkManager
var _pm           : PlayerManager
var _local_player : CharacterBody3D = null
var _my_id        : int = 0
var _tick_timer   : Timer


func _ready() -> void:
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

	# ── Таймер отправки позиции ──────────────────
	_tick_timer = Timer.new()
	_tick_timer.wait_time = TICK_INTERVAL
	_tick_timer.autostart = false
	_tick_timer.timeout.connect(_on_tick)
	add_child(_tick_timer)

	# ── Подключение ──────────────────────────────
	var err := _net.create_client(ADDRESS, PORT)
	if err != OK:
		push_error("Не удалось подключиться!")
		get_tree().quit(1)


# ══════════════════════════════════════════════════
#  СОБЫТИЯ ПОДКЛЮЧЕНИЯ
# ══════════════════════════════════════════════════

func _on_connected(_id: int) -> void:
	print("[client] Подключён, жду WELCOME…")


func _on_disconnected(_id: int) -> void:
	print("[client] Отключён от сервера")
	_tick_timer.stop()
	if _local_player:
		_local_player.queue_free()
		_local_player = null
	_pm.clear()
	_my_id = 0


# ══════════════════════════════════════════════════
#  ОБРАБОТЧИКИ ПАКЕТОВ
# ══════════════════════════════════════════════════

func _on_welcome(_peer_id: int, body: StreamPeerBuffer) -> void:
	var data := PacketTypes.read_welcome(body)
	_my_id = data["id"]
	_net.set_my_id(_my_id)

	var pos: Vector3 = data["position"]
	var rot: Vector3 = data["rotation"]
	print("[client] WELCOME!  id=%d  спавн=%s" % [_my_id, pos])

	# Спавн локального игрока
	_local_player = PLAYER_SCENE.instantiate() as CharacterBody3D
	_local_player.name = "LocalPlayer"
	$World/Players.add_child(_local_player)
	_local_player.global_position = pos
	_local_player.rotation.y = rot.y

	# Запускаем отправку позиции
	_tick_timer.start()


func _on_player_joined(_peer_id: int, body: StreamPeerBuffer) -> void:
	var data := PacketTypes.read_player_joined(body)
	var id: int = data["id"]
	if id == _my_id:
		return                                  # не спавним себя как удалённого
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
		return                                  # свои апдейты игнорируем
	_pm.update_player(id, data["position"], data["rotation"])


func _on_pong(_peer_id: int, _body: StreamPeerBuffer) -> void:
	print("[client] ← PONG")


# ══════════════════════════════════════════════════
#  ТИКИ: ОТПРАВКА ПОЗИЦИИ
# ══════════════════════════════════════════════════

func _on_tick() -> void:
	if _local_player == null or _my_id == 0:
		return
	var state: Dictionary = _local_player.get_network_state()
	var pkt := PacketTypes.write_player_update(
		_my_id, state["position"], state["rotation"])
	_net.send_to_server(pkt, 0, ENetPacketPeer.FLAG_UNSEQUENCED)


# ══════════════════════════════════════════════════

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_net.shutdown()
		get_tree().quit()
