extends Node

const PORT         := 9999
const MAX_CLIENTS  := 32
const SPAWN_Y      := 2.0
const SERVER_TOKEN := "my_game_v1"
const AUTH_TIMEOUT  := 5.0

var _net : NetworkManager        = null
var _pm  : PlayerManager         = null
var _nam : NetworkActionManager  = null

var _authenticated : Dictionary = {}
var _connect_time  : Dictionary = {}
var _security_log  : Dictionary = {}

const MAX_VIOLATIONS  := 10
const VIOLATION_DECAY := 30.0
var _violations : Dictionary = {}


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

	_net.peer_connected.connect(_on_peer_connected)
	_net.peer_disconnected.connect(_on_peer_disconnected)
	_net.register_handler(PacketTypes.PING, _on_ping)
	_net.register_handler(PacketTypes.AUTH_REQUEST, _on_auth_request)

	_nam.setup(_net)
	_nam.set_kick_callback(_on_security_kick)

	# ═══ АВТОНАСТРОЙКА СЕРВЕРА — ТРИ СТРОКИ ═══
	# 1. Контекст для автовалидации (правила из .tres)
	_nam.setup_server_context(_pm, _authenticated, _on_violation)
	# 2. Автопривязка обработчиков _on_* и _validate_*
	_nam.auto_bind_server(self)

	var err := _net.create_server(PORT, MAX_CLIENTS)
	if err != OK:
		push_error("[server] Не удалось создать сервер")
		get_tree().quit(1)
		return

	print("[server] Запущен на порту %d" % PORT)


func _process(_delta: float) -> void:
	_check_auth_timeout()


# ══════════════════════════════════════════════════
#  АУТЕНТИФИКАЦИЯ
# ══════════════════════════════════════════════════

func _on_peer_connected(id: int) -> void:
	_authenticated[id] = false
	_connect_time[id] = Time.get_unix_time_from_system()


func _check_auth_timeout() -> void:
	var now := Time.get_unix_time_from_system()
	var to_kick: Array[int] = []
	for id: int in _connect_time:
		if not _authenticated.get(id, false):
			if now - _connect_time[id] > AUTH_TIMEOUT:
				to_kick.append(id)
	for id: int in to_kick:
		_net.kick_peer(id)
		_connect_time.erase(id)


func _on_auth_request(peer_id: int, body: StreamPeerBuffer) -> void:
	var data := PacketTypes.read_auth_request(body)
	if data["token"] != SERVER_TOKEN:
		_net.send_to_peer(peer_id, PacketTypes.write_auth_response(false, "Bad token"))
		await get_tree().create_timer(0.5).timeout
		_net.kick_peer(peer_id)
		return

	_authenticated[peer_id] = true
	_connect_time.erase(peer_id)
	_net.send_to_peer(peer_id, PacketTypes.write_auth_response(true))

	var pos := Vector3(randf_range(-5.0, 5.0), SPAWN_Y, randf_range(-5.0, 5.0))
	var rot := Vector3.ZERO
	_net.send_to_peer(peer_id, PacketTypes.write_welcome(peer_id, pos, rot))

	for eid: int in _pm.get_all_ids():
		var d: Dictionary = _pm.get_player_data(eid)
		_net.send_to_peer(peer_id, PacketTypes.write_player_joined(
			eid, d["position"], d["rotation"]))

	_pm.add_player(peer_id, pos, rot)
	_net.broadcast_except(peer_id, PacketTypes.write_player_joined(peer_id, pos, rot))


func _on_peer_disconnected(id: int) -> void:
	_pm.remove_player(id)
	_net.broadcast(PacketTypes.write_player_left(id))
	_authenticated.erase(id)
	_connect_time.erase(id)
	_violations.erase(id)
	_nam.clear_peer_data(id)


func _on_ping(peer_id: int, _body: StreamPeerBuffer) -> void:
	_net.send_to_peer(peer_id, PacketTypes.write_pong())


func _on_security_kick(peer_id: int, reason: String) -> void:
	_net.kick_peer(peer_id)


# ══════════════════════════════════════════════════
#  НАРУШЕНИЯ
# ══════════════════════════════════════════════════

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


# ══════════════════════════════════════════════════
#  ОБРАБОТЧИКИ (auto_bind_server находит по имени)
#
#  Для player_move — вся валидация в .tres (автоматически).
#  _on_player_move нужен только для обновления PlayerManager.
#
#  При добавлении нового пакета:
#  1. Создать .tres с правилами валидации
#  2. F6
#  3. Добавить _on_<name>() ТОЛЬКО если нужна серверная логика
#  4. _validate_<name>() ТОЛЬКО если нужна ДОПОЛНИТЕЛЬНАЯ проверка
#     сверх того что описано в .tres
# ══════════════════════════════════════════════════

func _on_player_move(peer_id: int, data: Dictionary) -> void:
	var pos: Vector3 = data["position"]
	var rot := Vector3(data["head_pitch"], data["body_yaw"], 0.0)
	_pm.update_player(peer_id, pos, rot)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		for id: int in _pm.get_all_ids():
			_net.send_to_peer(id, PacketTypes.write_player_left(id))
		if _net != null and _net._host != null:
			_net._host.flush()
		if _net != null:
			_net.shutdown()
		get_tree().quit(0)
