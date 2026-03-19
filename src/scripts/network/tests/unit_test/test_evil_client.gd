extends Node
## Вредоносный клиент для тестирования защит.

const ADDRESS := "127.0.0.1"
const PORT    := 9999
const TOKEN   := "my_game_v1"

var _net: NetworkManager = null
var _nam: NetworkActionManager = null
var _my_id: int = 0
var _connected: bool = false
var _gp: RefCounted = null
var _move_tick: int = 0


func _ready() -> void:
	_net = NetworkManager.new()
	_net.name = "NetworkManager"
	add_child(_net)

	_nam = NetworkActionManager.new()
	_nam.name = "NetworkActionManager"
	add_child(_nam)

	_net.peer_connected.connect(_on_connected)
	_net.peer_disconnected.connect(_on_disconnected)

	_net.register_handler(PacketTypes.AUTH_RESPONSE, _on_auth_response)
	_net.register_handler(PacketTypes.WELCOME, _on_welcome)

	_nam.setup(_net)

	_gp = GeneratedPackets.new()

	var err := _net.create_client(ADDRESS, PORT)
	if err != OK:
		print("[evil] Не удалось подключиться")
		return

	print("═══════════════════════════════════════")
	print("[evil] Вредоносный клиент запущен")
	print("═══════════════════════════════════════")


func _on_connected(_id: int) -> void:
	_connected = true
	print("[evil] Подключён, отправка токена...")
	_net.send_to_server(PacketTypes.write_auth_request(TOKEN))


func _on_disconnected(_id: int) -> void:
	_connected = false
	print("[evil] ✗ Отключён от сервера")


func _on_auth_response(_peer_id: int, body: StreamPeerBuffer) -> void:
	var data := PacketTypes.read_auth_response(body)
	if data["success"]:
		print("[evil] ✓ Аутентификация пройдена")
	else:
		print("[evil] ✗ Аутентификация отклонена: %s" % data["message"])


func _on_welcome(_peer_id: int, body: StreamPeerBuffer) -> void:
	var data := PacketTypes.read_welcome(body)
	_my_id = data["id"]
	_move_tick = 0
	print("[evil] ✓ WELCOME id=%d" % _my_id)
	print("")
	print("[evil] Тесты:")
	print("[evil]   1 = Неверный токен")
	print("[evil]   2 = Подмена peer_id")
	print("[evil]   3 = Телепортация")
	print("[evil]   4 = Спидхак")
	print("[evil]   5 = Спам пакетами (ПОСЛЕДНИМ! кикнут)")
	print("[evil]   9 = Все тесты по порядку")


func _is_ready() -> bool:
	if not _connected:
		print("[evil] ✗ Нет соединения!")
		return false
	if _my_id == 0:
		print("[evil] ✗ Нет WELCOME!")
		return false
	return true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1: _test_bad_token()
			KEY_2: _test_fake_peer_id()
			KEY_3: _test_teleport()
			KEY_4: _test_speedhack()
			KEY_5: _test_packet_spam()
			KEY_9: _test_all()


# ══════════════════════════════════════════════════
#  ТЕСТ 1: Неверный токен (отдельное соединение)
# ══════════════════════════════════════════════════

func _test_bad_token() -> void:
	print("\n[evil] ═══ ТЕСТ 1: Неверный токен ═══")

	var evil_net := NetworkManager.new()
	evil_net.name = "EvilNet_BadToken"
	add_child(evil_net)

	evil_net.peer_connected.connect(func(_id):
		print("[evil] Второе соединение → плохой токен")
		evil_net.send_to_server(PacketTypes.write_auth_request("WRONG"))
	)

	evil_net.peer_disconnected.connect(func(_id):
		print("[evil] ✓ Кикнут (защита работает)")
		evil_net.queue_free()
	)

	evil_net.register_handler(PacketTypes.AUTH_RESPONSE, func(_pid, body: StreamPeerBuffer):
		var data := PacketTypes.read_auth_response(body)
		print("[evil] Ответ: success=%s msg='%s'" % [data["success"], data["message"]])
	)

	evil_net.create_client(ADDRESS, PORT)


# ══════════════════════════════════════════════════
#  ТЕСТ 2: Подмена peer_id
# ══════════════════════════════════════════════════

func _test_fake_peer_id() -> void:
	if not _is_ready():
		return

	print("\n[evil] ═══ ТЕСТ 2: Подмена peer_id ═══")

	var fake_id := 999
	var pos := Vector3(0, 2, 0)
	_send_player_move(fake_id, pos, 0.0, 0.0)

	print("[evil] Отправлен peer_id=%d (реальный=%d)" % [fake_id, _my_id])
	print("[evil] ✓ Сервер должен перезаписать на %d" % _my_id)
	print("[evil] Проверь: другие клиенты НЕ видят игрока 999")


# ══════════════════════════════════════════════════
#  ТЕСТ 3: Телепортация
# ══════════════════════════════════════════════════

func _test_teleport() -> void:
	if not _is_ready():
		return

	print("\n[evil] ═══ ТЕСТ 3: Телепортация ═══")

	var normal_pos := Vector3(0, 2, 0)
	_send_player_move(_my_id, normal_pos, 0.0, 0.0)

	await get_tree().create_timer(0.2).timeout

	if not _connected:
		print("[evil] ✗ Потеряно соединение")
		return

	var fake_pos := Vector3(99999.0, 0.0, 99999.0)
	_send_player_move(_my_id, fake_pos, 0.0, 0.0)

	print("[evil] Отправлено: %s → %s" % [normal_pos, fake_pos])
	print("[evil] ✓ Сервер должен отклонить (distance > 50)")


# ══════════════════════════════════════════════════
#  ТЕСТ 4: Спидхак
# ══════════════════════════════════════════════════

func _test_speedhack() -> void:
	if not _is_ready():
		return

	print("\n[evil] ═══ ТЕСТ 4: Спидхак ═══")

	var pos := Vector3(0, 2, 0)
	_send_player_move(_my_id, pos, 0.0, 0.0)

	await get_tree().create_timer(0.1).timeout

	if not _connected:
		print("[evil] ✗ Потеряно соединение")
		return

	var fast_pos := pos + Vector3(50, 0, 0)

	# Для честной проверки античита не подделываем огромный tick gap,
	# а отправляем обычный следующий tick.
	_send_player_move(_my_id, fast_pos, 0.0, 0.0)

	print("[evil] Отправлено: %s → %s за короткое время" % [pos, fast_pos])
	print("[evil] ✓ Сервер должен отклонить (> max_speed)")


# ══════════════════════════════════════════════════
#  ТЕСТ 5: Спам пакетами (ПОСЛЕДНИМ — может кикнуть!)
# ══════════════════════════════════════════════════

func _test_packet_spam() -> void:
	if not _is_ready():
		return

	print("\n[evil] ═══ ТЕСТ 5: Спам пакетами ═══")
	print("[evil] ⚠ После этого теста скорее всего кикнут!")

	var pos := Vector3(0, 2, 0)
	var sent := 0

	for i in 200:
		if not _connected:
			break
		_send_player_move(_my_id, pos, 0.0, 0.0)
		sent += 1

	print("[evil] Отправлено: %d пакетов" % sent)
	print("[evil] ✓ Сервер должен отбросить большинство (rate limit)")
	print("[evil] Проверь лог сервера: rate_limited > 0")


# ══════════════════════════════════════════════════
#  ТЕСТ 9: Все тесты по порядку
# ══════════════════════════════════════════════════

func _test_all() -> void:
	print("\n[evil] ═══ ВСЕ ТЕСТЫ ═══\n")

	_test_bad_token()
	await get_tree().create_timer(2.0).timeout

	_test_fake_peer_id()
	await get_tree().create_timer(1.0).timeout

	_test_teleport()
	await get_tree().create_timer(1.0).timeout

	_test_speedhack()
	await get_tree().create_timer(1.0).timeout

	# Спам последним — может кикнуть
	_test_packet_spam()

	await get_tree().create_timer(2.0).timeout
	print("\n[evil] ═══ ВСЕ ТЕСТЫ ЗАВЕРШЕНЫ ═══")
	print("[evil] Проверь СОСТОЯНИЕ СЕРВЕРА в логах!")

func _next_tick() -> int:
	_move_tick = (_move_tick + 1) & 0xFFFF
	return _move_tick


func _make_player_move(peer_id: int, pos: Vector3, head_pitch: float = 0.0, body_yaw: float = 0.0, tick: int = -1) -> PackedByteArray:
	var t := tick
	if t < 0:
		t = _next_tick()
	return _gp.call("write_player_move", peer_id, tick, pos, Vector3.ZERO, head_pitch, body_yaw)


func _send_player_move(peer_id: int, pos: Vector3, head_pitch: float = 0.0, body_yaw: float = 0.0, tick: int = -1) -> void:
	var pkt := _make_player_move(peer_id, pos, head_pitch, body_yaw, tick)
	# movement у тебя сейчас идёт как unreliable sequenced на канале 1
	_net.send_to_server(pkt, 1, 0)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if _net:
			_net.shutdown()
		get_tree().quit()
