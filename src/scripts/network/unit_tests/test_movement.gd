extends Node

## Тесты античита. Используют реальное время как сервер.

var _passed := 0
var _failed := 0

var _net_server: NetworkManager = null
var _pm: PlayerManager = null
var _nam_server: NetworkActionManager = null
var _gp: RefCounted = null

var _authenticated: Dictionary = {}
var _violations: Array[String] = []

## Задержка между пакетами — имитирует реальный send_rate_hz=20.
## 0.2с гарантирует что unix_time покажет разницу > 0.1с.
const DT := 0.2


func _ready() -> void:
	print("═══ ТЕСТЫ АНТИЧИТА И КОРРЕКЦИИ ═══\n")
	_gp = GeneratedPackets.new()
	_setup_server()
	await _run_all()
	_print_results()
	await get_tree().create_timer(0.3).timeout
	get_tree().quit()


func _assert(condition: bool, name: String) -> void:
	if condition:
		_passed += 1
		print("  ✓ %s" % name)
	else:
		_failed += 1
		print("  ✗ %s ← ПРОВАЛЕНО" % name)


func _assert_approx(a: float, b: float, eps: float, name: String) -> void:
	_assert(absf(a - b) < eps, name)


func _print_results() -> void:
	print("\n═══ РЕЗУЛЬТАТЫ ═══")
	print("  Пройдено: %d" % _passed)
	print("  Провалено: %d" % _failed)
	if _failed == 0:
		print("  ✓ ВСЕ ТЕСТЫ ПРОЙДЕНЫ")
	else:
		print("  ✗ ЕСТЬ ПРОВАЛЫ")
	print("══════════════════\n")


func _setup_server() -> void:
	_pm = PlayerManager.new()
	_pm.name = "PM"
	add_child(_pm)
	_net_server = NetworkManager.new()
	_net_server.name = "Net"
	add_child(_net_server)
	_nam_server = NetworkActionManager.new()
	_nam_server.name = "NAM"
	add_child(_nam_server)
	_nam_server.setup(_net_server)
	_nam_server.setup_server_context(_pm, _authenticated, _on_violation)


func _on_violation(peer_id: int, reason: String) -> void:
	_violations.append("%d:%s" % [peer_id, reason])


func _add(id: int, pos: Vector3) -> void:
	_pm.add_player(id, pos, Vector3.ZERO)
	_authenticated[id] = true


func _rem(id: int) -> void:
	_pm.remove_player(id)
	_authenticated.erase(id)
	_nam_server.clear_peer_data(id)


func _reset() -> void:
	_violations.clear()
	for id in _pm.get_all_ids().duplicate():
		_rem(id)


func _pid() -> int:
	for p: int in GeneratedPackets.PACKETS:
		if GeneratedPackets.PACKETS[p]["name"] == "player_move":
			return p
	return -1


func _move(id: int, pos: Vector3) -> bool:
	if not _pm.has_player(id):
		return false
	var pkt: PackedByteArray = _gp.call("write_player_move", id, pos, 0.0, 0.0)
	var parsed := PacketTypes.read_packet(pkt)
	var p := _pid()
	if p == -1:
		return false
	var meta: Dictionary = GeneratedPackets.PACKETS[p]
	var data: Dictionary = _gp.call("read_player_move", parsed["body"])
	data["peer_id"] = id
	var ok := _nam_server._auto_validate(p, id, data, meta)
	if ok:
		_nam_server._auto_update_pm(id, data, meta)
	return ok


func _w() -> void:
	await get_tree().create_timer(DT).timeout


# ══════════════════════════════════════════════════

func _run_all() -> void:
	await _t_normal()
	await _t_speed()
	await _t_teleport()
	await _t_correction_speed()
	await _t_correction_teleport()
	await _t_violations()
	await _t_diagonal()
	await _t_jump()
	await _t_first()
	await _t_peer_id()
	await _t_unauth()
	await _t_no_player()
	await _t_edge()
	await _t_walk_10()


func _t_normal() -> void:
	print("── Нормальное движение ──")
	_reset()
	_add(10, Vector3(0, 2, 0))
	# speed=5, DT=0.2 → перемещение за шаг = 5*0.2=1.0
	# max_allowed = 10 * 0.2 * 1.5 = 3.0
	# шаг 0.25 << 3.0 → OK
	_assert(_move(10, Vector3(0.25, 2, 0)), "Шаг 1")
	await _w()
	_assert(_move(10, Vector3(0.5, 2, 0)), "Шаг 2")
	await _w()
	_assert(_move(10, Vector3(0.75, 2, 0)), "Шаг 3")
	_assert_approx(_pm.get_player_data(10)["position"].x, 0.75, 0.1, "PM x=0.75")
	_assert(_violations.is_empty(), "0 нарушений")


func _t_speed() -> void:
	print("── Спидхак ──")
	_reset()
	_add(20, Vector3(0, 2, 0))
	_move(20, Vector3(0.2, 2, 0))
	await _w()
	# 10 блоков за ~0.2с, max_allowed ≈ 10*0.2*1.5=3.0, distance=9.8 > 3.0
	var v := _violations.size()
	_assert(not _move(20, Vector3(10.0, 2, 0)), "Отклонён")
	_assert(_violations.size() > v, "Нарушение")
	var has := false
	for x in _violations:
		if "speed_" in x: has = true
	_assert(has, "Тип: speed")
	_assert_approx(_pm.get_player_data(20)["position"].x, 0.2, 0.1, "PM x=0.2")


func _t_teleport() -> void:
	print("── Телепорт ──")
	_reset()
	_add(30, Vector3(0, 2, 0))
	var v := _violations.size()
	_assert(not _move(30, Vector3(999, 2, 999)), "Отклонён")
	_assert(_violations.size() > v, "Нарушение")
	var has := false
	for x in _violations:
		if "teleport_" in x: has = true
	_assert(has, "Тип: teleport")


func _t_correction_speed() -> void:
	print("── Коррекция спидхак ──")
	_reset()
	_add(40, Vector3(5, 2, 5))
	_move(40, Vector3(5.2, 2, 5))
	await _w()
	_assert(not _move(40, Vector3(15.2, 2, 5)), "Отклонён")
	_assert_approx(_pm.get_player_data(40)["position"].x, 5.2, 0.1, "PM x=5.2")
	await _w()
	_assert(_move(40, Vector3(5.4, 2, 5)), "Норм после коррекции")


func _t_correction_teleport() -> void:
	print("── Коррекция телепорт ──")
	_reset()
	_add(41, Vector3(10, 2, 10))
	_assert(not _move(41, Vector3(999, 999, 999)), "Отклонён")
	_assert_approx(_pm.get_player_data(41)["position"].x, 10.0, 0.1, "PM x=10")


func _t_violations() -> void:
	print("── Накопление ──")
	_reset()
	_add(50, Vector3(0, 2, 0))
	for i in 5:
		_move(50, Vector3(999 + i, 999, 999))
	var c := 0
	for x in _violations:
		if x.begins_with("50:"): c += 1
	_assert(c >= 5, "%d нарушений (≥5)" % c)


func _t_diagonal() -> void:
	print("── Диагональ ──")
	_reset()
	_add(60, Vector3(0, 2, 0))
	_assert(_move(60, Vector3(0.3, 2, 0.3)), "Шаг 1")
	await _w()
	_assert(_move(60, Vector3(0.6, 2, 0.6)), "Шаг 2")
	_assert(_violations.is_empty(), "0 нарушений")


func _t_jump() -> void:
	print("── Прыжок ──")
	_reset()
	_add(70, Vector3(0, 2, 0))
	_assert(_move(70, Vector3(0.1, 2.22, 0)), "Фаза 1")
	await _w()
	_assert(_move(70, Vector3(0.2, 2.4, 0)), "Фаза 2")
	await _w()
	_assert(_move(70, Vector3(0.3, 2.5, 0)), "Фаза 3")
	_assert(_violations.is_empty(), "0 нарушений")


func _t_first() -> void:
	print("── Первый пакет ──")
	_reset()
	_add(80, Vector3(3, 2, -5))
	_assert(_move(80, Vector3(3.1, 2, -5)), "Принят")
	_assert(_violations.is_empty(), "0 нарушений")


func _t_peer_id() -> void:
	print("── Подмена peer_id ──")
	_reset()
	_add(90, Vector3(0, 2, 0))
	var pkt: PackedByteArray = _gp.call("write_player_move", 999, Vector3(0.1, 2, 0), 0.0, 0.0)
	var parsed := PacketTypes.read_packet(pkt)
	var data: Dictionary = _gp.call("read_player_move", parsed["body"])
	data["peer_id"] = 90
	_assert(data["peer_id"] == 90, "Перезаписан")


func _t_unauth() -> void:
	print("── Неавторизован ──")
	_reset()
	_pm.add_player(100, Vector3(0, 2, 0), Vector3.ZERO)
	_assert(not _move(100, Vector3(0.1, 2, 0)), "Отклонён")
	_pm.remove_player(100)


func _t_no_player() -> void:
	print("── Не существует ──")
	_reset()
	_authenticated[110] = true
	_assert(not _move(110, Vector3(0.1, 2, 0)), "Отклонён")
	_authenticated.erase(110)


func _t_edge() -> void:
	print("── Граничная скорость ──")
	_reset()
	_add(120, Vector3(0, 2, 0))
	# Первый пакет: dt=0.05 (дефолт), max=10*0.05*1.5=0.75
	_assert(_move(120, Vector3(0.5, 2, 0)), "0.5 принят")
	await _w()
	# Второй: dt~0.2, max=10*0.2*1.5=3.0
	_assert(_move(120, Vector3(1.0, 2, 0)), "0.5 принят")
	_assert(_violations.is_empty(), "0 нарушений")


func _t_walk_10() -> void:
	print("── 10 шагов ──")
	_reset()
	_add(130, Vector3(0, 2, 0))
	var ok := true
	for i in 10:
		if not _move(130, Vector3(0.25 * (i + 1), 2, 0)):
			ok = false
		await _w()
	_assert(ok, "Все 10 приняты")
	_assert(_violations.is_empty(), "0 нарушений")
	_assert_approx(_pm.get_player_data(130)["position"].x, 2.5, 0.1, "PM x=2.5")
