extends Node
## Юнит-тесты сетевого кода. Запуск: F6

var _passed := 0
var _failed := 0


func _ready() -> void:
	print("═══ ТЕСТЫ СЕТЕВОГО КОДА ═══\n")

	_test_all_packets_metadata()
	_test_packet_write_read()
	_test_half_float()
	_test_quantization()
	_test_fragment_assembly()
	_test_fragment_bomb_protection()
	_test_auth_packets()

	print("\n═══ РЕЗУЛЬТАТЫ ═══")
	print("  Пройдено: %d" % _passed)
	print("  Провалено: %d" % _failed)
	if _failed == 0:
		print("  ✓ ВСЕ ТЕСТЫ ПРОЙДЕНЫ")
	print("══════════════════\n")

	await get_tree().create_timer(0.3).timeout
	get_tree().quit()


func _assert(condition: bool, test_name: String) -> void:
	if condition:
		_passed += 1
		print("  ✓ %s" % test_name)
	else:
		_failed += 1
		print("  ✗ %s  ← ПРОВАЛЕНО" % test_name)


func _assert_approx(a: float, b: float, epsilon: float, test_name: String) -> void:
	_assert(absf(a - b) < epsilon, test_name)


# ══════════════════════════════════════════════════
#  УНИВЕРСАЛЬНЫЙ: все пакеты из PACKETS
# ══════════════════════════════════════════════════

func _test_all_packets_metadata() -> void:
	print("── Метаданные всех пакетов ──")

	var gp := GeneratedPackets.new()

	for pid: int in GeneratedPackets.PACKETS:
		var meta: Dictionary = GeneratedPackets.PACKETS[pid]
		var pname: String = meta["name"]

		_assert(gp.has_method("write_%s" % pname),
			"'%s': write_%s существует" % [pname, pname])
		_assert(gp.has_method("read_%s" % pname),
			"'%s': read_%s существует" % [pname, pname])

		var field_names: Array = meta.get("field_names", [])
		_assert(field_names.size() > 0,
			"'%s': %d полей" % [pname, field_names.size()])

		_assert(meta["sync_mode"] >= 0 and meta["sync_mode"] <= 4,
			"'%s': sync_mode=%d" % [pname, meta["sync_mode"]])
		_assert(meta["channel"] == 0 or meta["channel"] == 1,
			"'%s': channel=%d" % [pname, meta["channel"]])

	print("  Всего пакетов в PACKETS: %d" % GeneratedPackets.PACKETS.size())


# ══════════════════════════════════════════════════
#  player_move: запись/чтение
# ══════════════════════════════════════════════════

func _test_packet_write_read() -> void:
	print("── player_move: запись/чтение ──")

	var gp := GeneratedPackets.new()
	var peer_id := 42
	var pos := Vector3(10.5, 20.3, -5.7)
	var pitch := 0.5
	var yaw := -1.2

	var pkt: PackedByteArray = gp.call("write_player_move", peer_id, pos, pitch, yaw)
	_assert(pkt.size() > 0, "write возвращает данные")

	var parsed := PacketTypes.read_packet(pkt)
	_assert(parsed["type"] == GeneratedPackets.PLAYER_MOVE_ID, "type совпадает")

	var data: Dictionary = gp.call("read_player_move", parsed["body"])
	_assert(data["peer_id"] == peer_id, "peer_id совпадает")
	_assert_approx(data["position"].x, pos.x, 0.01, "position.x")
	_assert_approx(data["position"].y, pos.y, 0.01, "position.y")
	_assert_approx(data["position"].z, pos.z, 0.01, "position.z")
	_assert_approx(data["head_pitch"], pitch, 0.001, "head_pitch")
	_assert_approx(data["body_yaw"], yaw, 0.01, "body_yaw")


# ══════════════════════════════════════════════════
#  Half-float
# ══════════════════════════════════════════════════

func _test_half_float() -> void:
	print("── Half-float ──")

	var gp := GeneratedPackets.new()
	var test_values := [0.0, 1.0, -1.0, 0.5, 100.0, -100.0, 0.001]

	for v in test_values:
		var h: int = gp.call("_f2h", v)
		var back: float = gp.call("_h2f", h)
		var epsilon := maxf(absf(v) * 0.01, 0.001)
		_assert_approx(back, v, epsilon, "roundtrip: %s" % str(v))


# ══════════════════════════════════════════════════
#  Квантизация
# ══════════════════════════════════════════════════

func _test_quantization() -> void:
	print("── Квантизация ──")

	var gp := GeneratedPackets.new()
	var test_pitches := [-1.5, -0.5, 0.0, 0.5, 1.5]

	for pitch in test_pitches:
		var pkt: PackedByteArray = gp.call("write_player_move", 1, Vector3.ZERO, pitch, 0.0)
		var parsed := PacketTypes.read_packet(pkt)
		var data: Dictionary = gp.call("read_player_move", parsed["body"])
		_assert_approx(data["head_pitch"], pitch, 0.001,
			"pitch: %s" % str(pitch))

	# Clamp
	var pkt_c: PackedByteArray = gp.call("write_player_move", 1, Vector3.ZERO, 5.0, 0.0)
	var parsed_c := PacketTypes.read_packet(pkt_c)
	var data_c: Dictionary = gp.call("read_player_move", parsed_c["body"])
	_assert_approx(data_c["head_pitch"], 1.5, 0.001, "clamp: 5.0 → 1.5")


# ══════════════════════════════════════════════════
#  Фрагментация
# ══════════════════════════════════════════════════

func _test_fragment_assembly() -> void:
	print("── Фрагментация ──")

	var body := PackedByteArray()
	body.resize(3000)
	for i in 3000:
		body[i] = i % 256

	var fragments := PacketTypes.fragment_packet(100, body)
	_assert(fragments.size() == 3, "3 фрагмента")

	var assembler := PacketTypes.FragmentAssembler.new()
	var result = null

	for frag: PackedByteArray in fragments:
		var parsed := PacketTypes.read_packet(frag)
		result = assembler.add_fragment(
			1, parsed["type"],
			parsed["fragment_id"], parsed["total_fragments"],
			parsed["body"])

	_assert(result != null, "Собрано")
	if result != null:
		_assert((result as StreamPeerBuffer).data_array.size() == 3000, "Размер = 3000")


# ══════════════════════════════════════════════════
#  Фрагмент-бомба
# ══════════════════════════════════════════════════

func _test_fragment_bomb_protection() -> void:
	print("── Фрагмент-бомба ──")

	var assembler := PacketTypes.FragmentAssembler.new()

	var fb := StreamPeerBuffer.new()
	fb.data_array = PackedByteArray([1, 2, 3])
	fb.seek(0)
	var result = assembler.add_fragment(1, 100, 0, 100, fb)
	_assert(result == null, "total=100 отклонён (> 64)")

	for i in 5:
		var fb2 := StreamPeerBuffer.new()
		fb2.data_array = PackedByteArray([1])
		fb2.seek(0)
		assembler.add_fragment(1, 200 + i, 0, 2, fb2)

	_assert(assembler._buffers.size() <= 4, "Лимит на пира: макс 4")
	assembler.clear()


# ══════════════════════════════════════════════════
#  Аутентификация
# ══════════════════════════════════════════════════

func _test_auth_packets() -> void:
	print("── Аутентификация ──")

	var req_pkt := PacketTypes.write_auth_request("test_token")
	var req_p := PacketTypes.read_packet(req_pkt)
	_assert(req_p["type"] == PacketTypes.AUTH_REQUEST, "AUTH_REQUEST type")
	var req_d := PacketTypes.read_auth_request(req_p["body"])
	_assert(req_d["token"] == "test_token", "Токен совпадает")

	var resp_ok := PacketTypes.write_auth_response(true)
	var resp_p := PacketTypes.read_packet(resp_ok)
	var resp_d := PacketTypes.read_auth_response(resp_p["body"])
	_assert(resp_d["success"] == true, "success=true")

	var resp_fail := PacketTypes.write_auth_response(false, "Bad token")
	var resp_fp := PacketTypes.read_packet(resp_fail)
	var resp_fd := PacketTypes.read_auth_response(resp_fp["body"])
	_assert(resp_fd["success"] == false, "success=false")
	_assert(resp_fd["message"] == "Bad token", "message совпадает")

	var huge := "A".repeat(500)
	var huge_pkt := PacketTypes.write_auth_request(huge)
	var huge_p := PacketTypes.read_packet(huge_pkt)
	var huge_d := PacketTypes.read_auth_request(huge_p["body"])
	_assert(huge_d["token"] == "", "Огромный токен отклонён")
