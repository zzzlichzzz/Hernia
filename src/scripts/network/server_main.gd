extends Node

const PORT         := 9999
const MAX_CLIENTS  := 32
const SPAWN_Y      := 2.0
const SERVER_TOKEN := "my_game_v1"
const MAX_PLAYER_SPEED := 10.0
const SPEED_TOLERANCE  := 1.5

var _net : NetworkManager        = null
var _pm  : PlayerManager         = null
var _nam : NetworkActionManager  = null

var _stats_timer: Timer

# ── Безопасность ──────────────────────────────────
var _authenticated  : Dictionary = {}   # peer_id → bool
var _last_move_time : Dictionary = {}   # peer_id → float
var _cooldowns      : Dictionary = {}   # peer_id → { action → float }

var _security_log: Dictionary = {
	"auth_failed": 0,
	"rate_limited": 0,
	"teleport_blocked": 0,
	"speedhack_blocked": 0,
	"cooldown_blocked": 0,
	"peer_id_overwritten": 0,
	"unauth_packets": 0,
}

func _ready() -> void:
	get_tree().auto_accept_quit = false

	# ══════════════════════════════════════════════
	#  1. СОЗДАТЬ ВСЕ МЕНЕДЖЕРЫ (порядок важен!)
	# ══════════════════════════════════════════════

	_net = NetworkManager.new()
	_net.name = "NetworkManager"
	add_child(_net)

	_pm = PlayerManager.new()
	_pm.name = "PlayerManager"
	add_child(_pm)

	_nam = NetworkActionManager.new()
	_nam.name = "NetworkActionManager"
	add_child(_nam)

	# ══════════════════════════════════════════════
	#  2. СИГНАЛЫ (после создания _net!)
	# ══════════════════════════════════════════════

	_net.peer_connected.connect(_on_peer_connected)
	_net.peer_disconnected.connect(_on_peer_disconnected)

	# ══════════════════════════════════════════════
	#  3. ОБРАБОТЧИКИ СЛУЖЕБНЫХ ПАКЕТОВ (после создания _net!)
	# ══════════════════════════════════════════════

	_net.register_handler(PacketTypes.PING, _on_ping)
	_net.register_handler(PacketTypes.AUTH_REQUEST, _on_auth_request)

	# ══════════════════════════════════════════════
	#  4. NAM SETUP (после создания _net и _nam!)
	# ══════════════════════════════════════════════

	_nam.setup(_net)
	_nam.on_action("player_move", _on_player_move)
	_nam.on_validate("player_move", _validate_player_move)

	# ══════════════════════════════════════════════
	#  5. СТАРТ СЕРВЕРА (последний шаг)
	# ══════════════════════════════════════════════

	var err := _net.create_server(PORT, MAX_CLIENTS)
	if err != OK:
		push_error("[server] Не удалось создать сервер! Error: %d" % err)
		get_tree().quit(1)
		return

	print("═══════════════════════════════════════")
	print("[server] Запущен на порту %d" % PORT)
	print("[server] Макс. клиентов: %d" % MAX_CLIENTS)
	print("═══════════════════════════════════════")
	
	_stats_timer = Timer.new()
	_stats_timer.wait_time = 10.0
	_stats_timer.autostart = true
	_stats_timer.timeout.connect(_print_stats)
	add_child(_stats_timer)


# ══════════════════════════════════════════════════
#  АУТЕНТИФИКАЦИЯ
# ══════════════════════════════════════════════════

func _on_peer_connected(id: int) -> void:
	# НЕ спавним сразу — ждём аутентификацию
	_authenticated[id] = false
	print("[server] Игрок %d подключился, ожидание аутентификации..." % id)

# Добавить в _notification или по таймеру
func _print_security_stats() -> void:
	print("═══ СТАТИСТИКА БЕЗОПАСНОСТИ ═══")
	for key: String in _security_log:
		var val: int = _security_log[key]
		if val > 0:
			print("  %-25s %d" % [key, val])
	print("════════════════════════════════")

func _print_stats() -> void:
	print("\n═══ СОСТОЯНИЕ СЕРВЕРА ═══")
	print("  Онлайн:          %d" % _pm.get_all_ids().size())
	print("  Аутентифицировано: %d" % _authenticated.values().count(true))

	# Статистика безопасности
	for key: String in _security_log:
		var val: int = _security_log[key]
		if val > 0:
			print("  [security] %-20s %d" % [key, val])

	print("══════════════════════════\n")

func _on_auth_request(peer_id: int, body: StreamPeerBuffer) -> void:
	var data := PacketTypes.read_auth_request(body)

	if data["token"] != SERVER_TOKEN:
		print("[server] Игрок %d: неверный токен '%s'" % [peer_id, data["token"]])
		_net.send_to_peer(peer_id, PacketTypes.write_auth_response(false, "Bad token"))
		_security_log["auth_failed"] += 1
		# Кикаем с задержкой чтобы клиент получил ответ
		await get_tree().create_timer(0.5).timeout
		_net.kick_peer(peer_id)
		return

	# Аутентификация пройдена
	_authenticated[peer_id] = true
	_net.send_to_peer(peer_id, PacketTypes.write_auth_response(true))

	# Теперь спавним
	var pos := Vector3(randf_range(-5.0, 5.0), SPAWN_Y, randf_range(-5.0, 5.0))
	var rot := Vector3.ZERO

	# WELCOME новому игроку
	_net.send_to_peer(peer_id, PacketTypes.write_welcome(peer_id, pos, rot))

	# Список существующих игроков
	for eid: int in _pm.get_all_ids():
		var d: Dictionary = _pm.get_player_data(eid)
		_net.send_to_peer(peer_id, PacketTypes.write_player_joined(
			eid, d["position"], d["rotation"]))

	# Добавляем
	_pm.add_player(peer_id, pos, rot)

	# Оповещаем остальных
	_net.broadcast_except(peer_id, PacketTypes.write_player_joined(peer_id, pos, rot))

	print("[server] Игрок %d аутентифицирован и заспавнен в %s (онлайн: %d)" % [
		peer_id, pos, _pm.get_all_ids().size()])


func _on_peer_disconnected(id: int) -> void:
	_pm.remove_player(id)
	_net.broadcast(PacketTypes.write_player_left(id))

	# Очистка данных безопасности
	_authenticated.erase(id)
	_last_move_time.erase(id)
	_cooldowns.erase(id)
	_nam.clear_peer_data(id)

	print("[server] Игрок %d отключился (онлайн: %d)" % [id, _pm.get_all_ids().size()])


# ══════════════════════════════════════════════════
#  СЛУЖЕБНЫЕ ПАКЕТЫ
# ══════════════════════════════════════════════════

func _on_ping(peer_id: int, _body: StreamPeerBuffer) -> void:
	_net.send_to_peer(peer_id, PacketTypes.write_pong())


# ══════════════════════════════════════════════════
#  ВАЛИДАЦИЯ PLAYER_MOVE
# ══════════════════════════════════════════════════

func _validate_player_move(peer_id: int, data: Dictionary) -> bool:
	if not _authenticated.get(peer_id, false):
		_security_log["unauth_packets"] += 1
		return false

	if not _pm.has_player(peer_id):
		return false

	var now := Time.get_unix_time_from_system()
	var old_data := _pm.get_player_data(peer_id)
	var old_pos: Vector3 = old_data["position"]
	var new_pos: Vector3 = data["position"]
	var distance := old_pos.distance_to(new_pos)

	if distance > 50.0:
		_security_log["teleport_blocked"] += 1
		print("[security] Игрок %d: телепортация %.1f м" % [peer_id, distance])
		return false

	var dt := 0.05
	if peer_id in _last_move_time:
		dt = clampf(now - _last_move_time[peer_id], 0.01, 2.0)
	_last_move_time[peer_id] = now

	var max_distance := MAX_PLAYER_SPEED * dt * SPEED_TOLERANCE
	if distance > max_distance:
		_security_log["speedhack_blocked"] += 1
		print("[security] Игрок %d: спидхак %.2f > %.2f" % [peer_id, distance, max_distance])
		return false

	return true


# ══════════════════════════════════════════════════
#  ОБРАБОТЧИК PLAYER_MOVE
# ══════════════════════════════════════════════════

func _on_player_move(peer_id: int, data: Dictionary) -> void:
	var pos: Vector3 = data["position"]
	var rot := Vector3(data["head_pitch"], data["body_yaw"], 0.0)
	_pm.update_player(peer_id, pos, rot)


# ══════════════════════════════════════════════════
#  COOLDOWN (для будущих действий)
# ══════════════════════════════════════════════════

func _check_cooldown(peer_id: int, action_name: String, cooldown_sec: float) -> bool:
	var now := Time.get_unix_time_from_system()

	if peer_id not in _cooldowns:
		_cooldowns[peer_id] = {}

	var peer_cd: Dictionary = _cooldowns[peer_id]

	if action_name in peer_cd:
		if now - peer_cd[action_name] < cooldown_sec:
			return false

	peer_cd[action_name] = now
	return true


# ══════════════════════════════════════════════════
#  ЗАВЕРШЕНИЕ
# ══════════════════════════════════════════════════

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		print("[server] Завершение работы...")
		for id: int in _pm.get_all_ids():
			_net.send_to_peer(id, PacketTypes.write_player_left(id))
		if _net != null and _net._host != null:
			_net._host.flush()
		if _net != null:
			_net.shutdown()
		get_tree().quit(0)
