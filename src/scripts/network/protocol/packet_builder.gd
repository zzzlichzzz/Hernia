extends Node
## Генератор сетевого кода из .tres определений.
## Запуск: открыть builder_scene.tscn → Run Scene (F6)

const ACTIONS_DIR := "res://src/scripts/network/packets/"
const OUTPUT_PATH := "res://src/scripts/network/protocol/generated/generated_packets.gd"

const KNOWN_SCRIPTS := [
	"res://src/scripts/network/scenes/player.gd",
	"res://src/scripts/network/scenes/remote_player.gd",
]
const AUTO_PACKET_ID_START := 1000
const AUTO_PACKET_ID_END := 65535

const RESERVED_PACKET_IDS := {
	3: true, 4: true, 6: true, 7: true, 8: true,
	9: true, 10: true, 11: true, 12: true,
}


func _ready() -> void:
	print("═══════════════════════════════════════")
	print("   Сборка сетевых пакетов")
	print("═══════════════════════════════════════")

	var defs := _scan()
	if defs.is_empty():
		print("[builder] Нет .tres файлов в %s" % ACTIONS_DIR)
		_quit(); return

	var changed := _assign_packet_ids(defs)
	if changed < 0:
		push_error("[builder] Не удалось назначить packet_id!")
		_quit(); return
	if changed > 0:
		print("[builder] Автоназначено/исправлено packet_id: %d" % changed)

	if not _validate(defs):
		push_error("[builder] Валидация не пройдена!")
		_quit(); return

	# ——— Генерация и сохранение ———
	var code := _generate(defs)
	if not _save(code):
		push_error("[builder] Не удалось сохранить!")
		_quit(); return

	_report(defs)
	_quit()


func _quit() -> void:
	await get_tree().create_timer(0.3).timeout
	get_tree().quit()


# ══════════════════════════════════════════════════
#  СКАНИРОВАНИЕ
# ══════════════════════════════════════════════════

func _scan() -> Array[NetworkPacketDef]:
	var result: Array[NetworkPacketDef] = []
	var dir := DirAccess.open(ACTIONS_DIR)
	if dir == null:
		push_error("[builder] Не могу открыть %s" % ACTIONS_DIR)
		return result
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			var res := ResourceLoader.load(ACTIONS_DIR + fname)
			if res is NetworkPacketDef:
				result.append(res as NetworkPacketDef)
				print("[builder] Найден: %s → '%s'" % [fname, (res as NetworkPacketDef).packet_name])
			else:
				push_warning("[builder] %s — не NetworkPacketDef, пропускаю" % fname)
		fname = dir.get_next()
	dir.list_dir_end()
	result.sort_custom(func(a: NetworkPacketDef, b: NetworkPacketDef) -> bool:
		return a.packet_name < b.packet_name)
	return result


# ══════════════════════════════════════════════════
#  ВАЛИДАЦИЯ
# ══════════════════════════════════════════════════

func _validate(defs: Array[NetworkPacketDef]) -> bool:
	var ok := true
	var ids: Dictionary = {}
	var names: Dictionary = {}

	for d in defs:
		if d.packet_name.is_empty():
			push_error("[builder] Пакет без имени!")
			ok = false
			continue

		if d.packet_name in names:
			push_error("[builder] Дублирование имени '%s'!" % d.packet_name)
			ok = false
		names[d.packet_name] = true

		var pid := d.get_packet_id()

		if pid < AUTO_PACKET_ID_START or pid > AUTO_PACKET_ID_END:
			push_error("[builder] Пакет '%s': packet_id=%d вне допустимого диапазона %d..%d" % [
				d.packet_name, pid, AUTO_PACKET_ID_START, AUTO_PACKET_ID_END])
			ok = false

		if pid in RESERVED_PACKET_IDS:
			push_error("[builder] Пакет '%s': packet_id=%d зарезервирован служебными PacketTypes" % [
				d.packet_name, pid])
			ok = false

		if pid in ids:
			push_error("[builder] Коллизия ID! '%s' и '%s' → id=%d" % [
				ids[pid], d.packet_name, pid])
			ok = false
		ids[pid] = d.packet_name

		var field_names: Dictionary = {}
		for f: NetworkFieldDef in d.fields:
			if f.field_name.is_empty():
				push_error("[builder] Пакет '%s': поле без имени!" % d.packet_name)
				ok = false
			if f.field_name in field_names:
				push_error("[builder] Пакет '%s': дублирование поля '%s'!" % [
					d.packet_name, f.field_name])
				ok = false
			field_names[f.field_name] = true

	return ok


func _validate_methods(defs: Array[NetworkPacketDef]) -> void:
	var scripts: Array[GDScript] = []
	for path in KNOWN_SCRIPTS:
		if ResourceLoader.exists(path):
			scripts.append(load(path) as GDScript)

	for d in defs:
		if d.source_method != "":
			var found := false
			for s in scripts:
				for m in s.get_script_method_list():
					if m["name"] == d.source_method:
						found = true
						break
				if found:
					break
			if not found:
				push_warning("[builder] ⚠ Пакет '%s': source_method '%s' не найден ни в одном скрипте" % [
					d.packet_name, d.source_method])

		if d.receive_method != "":
			var found := false
			for s in scripts:
				for m in s.get_script_method_list():
					if m["name"] == d.receive_method:
						found = true
						break
				if found:
					break
			if not found:
				push_warning("[builder] ⚠ Пакет '%s': receive_method '%s' не найден ни в одном скрипте" % [
					d.packet_name, d.receive_method])


# ══════════════════════════════════════════════════
#  НАЗНАЧЕНИЕ PACKET ID
# ══════════════════════════════════════════════════

func _assign_packet_ids(defs: Array[NetworkPacketDef]) -> int:
	var changed := 0
	var used: Dictionary = RESERVED_PACKET_IDS.duplicate(true)

	var ordered: Array[NetworkPacketDef] = defs.duplicate()
	ordered.sort_custom(func(a: NetworkPacketDef, b: NetworkPacketDef) -> bool:
		var ap := a.resource_path if a.resource_path != "" else a.packet_name
		var bp := b.resource_path if b.resource_path != "" else b.packet_name
		return ap < bp)

	var to_assign: Array[NetworkPacketDef] = []

	for d in ordered:
		var pid := d.get_packet_id()
		var valid := pid >= AUTO_PACKET_ID_START and pid <= AUTO_PACKET_ID_END and pid not in used
		if valid:
			used[pid] = true
		else:
			to_assign.append(d)

	for d in to_assign:
		var old_id := d.get_packet_id()
		var new_id := _alloc_next_packet_id(used)
		if new_id == -1:
			push_error("[builder] Закончились свободные packet_id!")
			return -1

		d.packet_id = new_id
		used[new_id] = true

		if not _save_packet_def_resource(d):
			push_error("[builder] Не удалось сохранить packet_id для '%s'" % d.packet_name)
			return -1

		print("[builder] packet_id: '%s' %d → %d" % [d.packet_name, old_id, new_id])
		changed += 1

	return changed


func _alloc_next_packet_id(used: Dictionary) -> int:
	var candidate := AUTO_PACKET_ID_START
	for k in used.keys():
		var id := int(k)
		if id >= candidate:
			candidate = id + 1
	while candidate <= AUTO_PACKET_ID_END:
		if candidate not in used:
			return candidate
		candidate += 1
	return -1


func _save_packet_def_resource(d: NetworkPacketDef) -> bool:
	if d.resource_path == "":
		push_error("[builder] У ресурса '%s' нет resource_path" % d.packet_name)
		return false
	var err := ResourceSaver.save(d, d.resource_path)
	if err != OK:
		push_error("[builder] Не могу сохранить %s: %s" % [d.resource_path, error_string(err)])
		return false
	return true


# ══════════════════════════════════════════════════
#  ГЕНЕРАЦИЯ
# ══════════════════════════════════════════════════

func _generate(defs: Array[NetworkPacketDef]) -> String:
	var L := PackedStringArray()

	# ── Шапка ─────────────────────────────────────
	L.append("# ═══════════════════════════════════════════════════")
	L.append("# AUTO-GENERATED — DO NOT EDIT")
	L.append("# Source: %s" % ACTIONS_DIR)
	L.append("# Date:   %s" % Time.get_datetime_string_from_system())
	L.append("# ═══════════════════════════════════════════════════")
	L.append("class_name GeneratedPackets")
	L.append("")

	# ── Константы ID ──────────────────────────────
	for d in defs:
		L.append("const %s_ID := %d" % [d.packet_name.to_upper(), d.get_packet_id()])
	L.append("")

	# ── Header size ───────────────────────────────
	L.append("const _HEADER_SIZE := PacketTypes.HEADER_SIZE  # 8")
	L.append("")

	# ── Квантизационные константы ─────────────────
	var quant_lines := _collect_quantization_constants(defs)
	if not quant_lines.is_empty():
		L.append("# Quantization constants (precomputed)")
		L.append_array(quant_lines)
		L.append("")

	# ── Метаданные PACKETS ────────────────────────
	L.append("## Метаданные пакетов для NetworkActionManager")
	L.append("const PACKETS := {")
	for d in defs:
		var fn_arr := PackedStringArray()
		for f: NetworkFieldDef in d.fields:
			fn_arr.append("\"%s\"" % f.field_name)

		var sk_arr := PackedStringArray()
		for f: NetworkFieldDef in d.fields:
			var key: String = f.source_key if f.source_key != "" else f.field_name
			sk_arr.append("\"%s\": \"%s\"" % [f.field_name, key])

		L.append("\t%d: {" % d.get_packet_id())
		L.append("\t\t\"name\": \"%s\"," % d.packet_name)
		L.append("\t\t\"sync_mode\": %d," % d.sync_mode)
		L.append("\t\t\"channel\": %d," % d.channel)
		L.append("\t\t\"server_validates\": %s," % ("true" if d.server_validates else "false"))
		L.append("\t\t\"field_names\": [%s]," % ", ".join(fn_arr))
		L.append("\t\t\"send_rate_hz\": %d," % d.send_rate_hz)
		L.append("\t\t\"source_method\": \"%s\"," % d.source_method)
		L.append("\t\t\"receive_method\": \"%s\"," % d.receive_method)
		L.append("\t\t\"auto_peer_id\": %s," % ("true" if d.auto_peer_id else "false"))
		L.append("\t\t\"source_keys\": {%s}," % ", ".join(sk_arr))
		L.append("\t\t\"v_player_exists\": %s," % ("true" if d.validate_player_exists else "false"))
		L.append("\t\t\"v_authenticated\": %s," % ("true" if d.validate_authenticated else "false"))
		L.append("\t\t\"v_max_distance\": %s," % _fstr(d.validate_max_distance))
		L.append("\t\t\"v_max_speed\": %s," % _fstr(d.validate_max_speed))
		L.append("\t\t\"v_speed_tolerance\": %s," % _fstr(d.validate_speed_tolerance))
		L.append("\t\t\"v_cooldown\": %s," % _fstr(d.validate_cooldown))
		L.append("\t\t\"v_position_field\": \"%s\"," % d.validate_position_field)
		L.append("\t\t\"v_max_action_dist\": %s," % _fstr(d.validate_max_action_distance))
		L.append("\t},")
	L.append("}")
	L.append("")
	L.append("")

	# ── Write / Read для каждого пакета ───────────
	for d in defs:
		var body_size := _calc_body_size(d)
		var size_str := "%d bytes (fixed)" % body_size if body_size >= 0 else "variable"
		L.append("# ─── %s (id=%d, %s) ───" % [d.packet_name, d.get_packet_id(), size_str])
		L.append("")

		if body_size >= 0:
			L.append_array(_gen_write_direct(d, body_size))
		else:
			L.append_array(_gen_write_variable(d))

		L.append("")
		L.append("")
		L.append_array(_gen_read(d))
		L.append("")
		L.append("")

	# ── Вспомогательные функции ───────────────────
	L.append_array(_gen_helpers())

	return "\n".join(L) + "\n"


# ══════════════════════════════════════════════════
#  WRITE: DIRECT (fixed-size пакеты, без StreamPeerBuffer)
# ══════════════════════════════════════════════════

func _gen_write_direct(d: NetworkPacketDef, body_size: int) -> PackedStringArray:
	var L := PackedStringArray()

	var params := PackedStringArray()
	for f: NetworkFieldDef in d.fields:
		params.append("%s: %s" % [f.field_name, _gdscript_type(f)])

	L.append("static func write_%s(%s) -> PackedByteArray:" % [
		d.packet_name, ", ".join(params)])
	L.append("\tconst BODY_SIZE := %d" % body_size)
	L.append("\tvar pkt := PackedByteArray()")
	L.append("\tpkt.resize(_HEADER_SIZE + BODY_SIZE)")
	L.append("")
	L.append("\t# Header")
	L.append("\tpkt.encode_u16(0, %d)" % d.get_packet_id())
	L.append("\tpkt.encode_u16(2, BODY_SIZE)")
	L.append("\tpkt.encode_u16(4, 0)")
	L.append("\tpkt.encode_u16(6, 0)")
	L.append("")
	L.append("\t# Body")

	var offset := 0
	for f: NetworkFieldDef in d.fields:
		L.append_array(_gen_write_field_direct(f, offset))
		offset += _field_byte_size(f)

	L.append("\treturn pkt")
	return L


func _gen_write_field_direct(f: NetworkFieldDef, offset: int) -> PackedStringArray:
	var L := PackedStringArray()
	var n := f.field_name
	var bs := _resolve_byte_size(f)
	var off_str := "_HEADER_SIZE" if offset == 0 else "_HEADER_SIZE + %d" % offset

	match f.field_type:
		NetworkFieldDef.FieldType.BOOL:
			L.append("\tpkt.encode_u8(%s, 1 if %s else 0)" % [off_str, n])

		NetworkFieldDef.FieldType.INT:
			L.append("\tpkt.%s(%s, %s)" % [_encode_int_method(bs, f.is_signed), off_str, n])

		NetworkFieldDef.FieldType.FLOAT:
			if f.use_quantization:
				L.append("\tpkt.%s(%s, %s)" % [
					_encode_uint_method_direct(bs), off_str,
					_quant_encode_expr(n, f, bs)])
			elif bs == 2:
				L.append("\tpkt.encode_u16(%s, _f2h(%s))" % [off_str, n])
			else:
				L.append("\tpkt.encode_float(%s, %s)" % [off_str, n])

		NetworkFieldDef.FieldType.VECTOR2:
			for i in range(2):
				var c: String = ["x", "y"][i]
				var comp_offset := offset + i * _component_byte_size(f, bs)
				var comp_off_str := "_HEADER_SIZE" if comp_offset == 0 else "_HEADER_SIZE + %d" % comp_offset
				L.append_array(_gen_write_component_direct(
					"%s.%s" % [n, c], f, bs, comp_off_str))

		NetworkFieldDef.FieldType.VECTOR3:
			for i in range(3):
				var c: String = ["x", "y", "z"][i]
				var comp_offset := offset + i * _component_byte_size(f, bs)
				var comp_off_str := "_HEADER_SIZE" if comp_offset == 0 else "_HEADER_SIZE + %d" % comp_offset
				L.append_array(_gen_write_component_direct(
					"%s.%s" % [n, c], f, bs, comp_off_str))

	return L


func _gen_write_component_direct(
	expr: String, f: NetworkFieldDef, bs: int, off_str: String
) -> PackedStringArray:
	var L := PackedStringArray()
	if f.use_quantization:
		L.append("\tpkt.%s(%s, %s)" % [
			_encode_uint_method_direct(bs), off_str,
			_quant_encode_expr(expr, f, bs)])
	elif bs == 2:
		L.append("\tpkt.encode_u16(%s, _f2h(%s))" % [off_str, expr])
	else:
		L.append("\tpkt.encode_float(%s, %s)" % [off_str, expr])
	return L


## Генерирует inline-выражение квантизации с precomputed константами.
## Пример: int(clampf((v - _Q_N1_5_TO_1_5_MIN) * _Q_N1_5_TO_1_5_INV_RANGE, 0.0, 1.0) * 65535.0)
func _quant_encode_expr(value_expr: String, f: NetworkFieldDef, bs: int) -> String:
	var prefix := _quant_const_prefix(f.quantize_min, f.quantize_max)
	var max_val := _quant_max_val(bs)
	return "int(clampf((%s - %s_MIN) * %s_INV_RANGE, 0.0, 1.0) * %s.0)" % [
		value_expr, prefix, prefix, str(max_val)]


# ══════════════════════════════════════════════════
#  WRITE: VARIABLE (пакеты с String/PackedBytes, через StreamPeerBuffer)
# ══════════════════════════════════════════════════

func _gen_write_variable(d: NetworkPacketDef) -> PackedStringArray:
	var L := PackedStringArray()
	var params := PackedStringArray()
	for f: NetworkFieldDef in d.fields:
		params.append("%s: %s" % [f.field_name, _gdscript_type(f)])

	L.append("static func write_%s(%s) -> PackedByteArray:" % [
		d.packet_name, ", ".join(params)])
	L.append("\tvar _b := StreamPeerBuffer.new()")
	L.append("\t_b.big_endian = false")
	for f: NetworkFieldDef in d.fields:
		L.append_array(_gen_write_field_spb(f))
	L.append("\treturn PacketTypes.write_packet(%d, _b.data_array)" % d.get_packet_id())
	return L


func _gen_write_field_spb(f: NetworkFieldDef) -> PackedStringArray:
	var L := PackedStringArray()
	var n := f.field_name
	var bs := _resolve_byte_size(f)

	match f.field_type:
		NetworkFieldDef.FieldType.BOOL:
			L.append("\t_b.put_u8(1 if %s else 0)" % n)

		NetworkFieldDef.FieldType.INT:
			L.append("\t_b.%s(%s)" % [_put_int_method(bs, f.is_signed), n])

		NetworkFieldDef.FieldType.FLOAT:
			if f.use_quantization:
				var max_val := _quant_max_val(bs)
				L.append("\t_b.%s(int(clampf((%s - (%s)) / ((%s) - (%s)), 0.0, 1.0) * %s.0))" % [
					_put_uint_method(bs), n, _fstr(f.quantize_min),
					_fstr(f.quantize_max), _fstr(f.quantize_min), str(max_val)])
			elif bs == 2:
				L.append("\t_b.put_u16(_f2h(%s))" % n)
			else:
				L.append("\t_b.put_float(%s)" % n)

		NetworkFieldDef.FieldType.VECTOR2:
			for c in ["x", "y"]:
				L.append_array(_gen_write_component_spb("%s.%s" % [n, c], f, bs))

		NetworkFieldDef.FieldType.VECTOR3:
			for c in ["x", "y", "z"]:
				L.append_array(_gen_write_component_spb("%s.%s" % [n, c], f, bs))

		NetworkFieldDef.FieldType.STRING:
			L.append("\tvar _utf_%s := %s.to_utf8_buffer()" % [n, n])
			L.append("\t_b.put_u16(_utf_%s.size())" % n)
			L.append("\tif _utf_%s.size() > 0:" % n)
			L.append("\t\t_b.put_data(_utf_%s)" % n)

		NetworkFieldDef.FieldType.PACKED_BYTES:
			L.append("\t_b.put_u32(%s.size())" % n)
			L.append("\tif %s.size() > 0:" % n)
			L.append("\t\t_b.put_data(%s)" % n)

	return L


func _gen_write_component_spb(expr: String, f: NetworkFieldDef, bs: int) -> PackedStringArray:
	var L := PackedStringArray()
	if f.use_quantization:
		var max_val := _quant_max_val(bs)
		L.append("\t_b.%s(int(clampf((%s - (%s)) / ((%s) - (%s)), 0.0, 1.0) * %s.0))" % [
			_put_uint_method(bs), expr, _fstr(f.quantize_min),
			_fstr(f.quantize_max), _fstr(f.quantize_min), str(max_val)])
	elif bs == 2:
		L.append("\t_b.put_u16(_f2h(%s))" % expr)
	else:
		L.append("\t_b.put_float(%s)" % expr)
	return L


# ══════════════════════════════════════════════════
#  READ
# ══════════════════════════════════════════════════

func _gen_read(d: NetworkPacketDef) -> PackedStringArray:
	var L := PackedStringArray()
	L.append("static func read_%s(_b: StreamPeerBuffer) -> Dictionary:" % d.packet_name)
	for f: NetworkFieldDef in d.fields:
		L.append_array(_gen_read_field(f))
	L.append("\treturn {")
	for f: NetworkFieldDef in d.fields:
		L.append("\t\t\"%s\": _%s," % [f.field_name, f.field_name])
	L.append("\t}")
	return L


func _gen_read_field(f: NetworkFieldDef) -> PackedStringArray:
	var L := PackedStringArray()
	var vn := "_%s" % f.field_name
	var bs := _resolve_byte_size(f)

	match f.field_type:
		NetworkFieldDef.FieldType.BOOL:
			L.append("\tvar %s := _b.get_u8() != 0" % vn)

		NetworkFieldDef.FieldType.INT:
			L.append("\tvar %s := _b.%s()" % [vn, _get_int_method(bs, f.is_signed)])

		NetworkFieldDef.FieldType.FLOAT:
			if f.use_quantization:
				var prefix := _quant_const_prefix(f.quantize_min, f.quantize_max)
				var max_val := _quant_max_val(bs)
				L.append("\tvar %s := %s_MIN + (float(_b.%s()) / %s.0) * %s_RANGE" % [
					vn, prefix, _get_uint_method(bs), str(max_val), prefix])
			elif bs == 2:
				L.append("\tvar %s := _h2f(_b.get_u16())" % vn)
			else:
				L.append("\tvar %s := _b.get_float()" % vn)

		NetworkFieldDef.FieldType.VECTOR2:
			var cx := _read_comp_expr(f, bs)
			var cy := _read_comp_expr(f, bs)
			L.append("\tvar %s := Vector2(%s, %s)" % [vn, cx, cy])

		NetworkFieldDef.FieldType.VECTOR3:
			var cx := _read_comp_expr(f, bs)
			var cy := _read_comp_expr(f, bs)
			var cz := _read_comp_expr(f, bs)
			L.append("\tvar %s := Vector3(%s, %s, %s)" % [vn, cx, cy, cz])

		NetworkFieldDef.FieldType.STRING:
			L.append("\tvar _%s_len := _b.get_u16()" % f.field_name)
			L.append("\tvar %s := \"\"" % vn)
			L.append("\tif _%s_len > 0 and _%s_len <= 4096:" % [f.field_name, f.field_name])
			L.append("\t\t%s = _b.get_data(_%s_len)[1].get_string_from_utf8()" % [vn, f.field_name])

		NetworkFieldDef.FieldType.PACKED_BYTES:
			L.append("\tvar _%s_len := _b.get_u32()" % f.field_name)
			L.append("\tvar %s := PackedByteArray()" % vn)
			L.append("\tif _%s_len > 0 and _%s_len <= 65536:" % [f.field_name, f.field_name])
			L.append("\t\t%s = _b.get_data(_%s_len)[1]" % [vn, f.field_name])

	return L


func _read_comp_expr(f: NetworkFieldDef, bs: int) -> String:
	if f.use_quantization:
		var prefix := _quant_const_prefix(f.quantize_min, f.quantize_max)
		var max_val := _quant_max_val(bs)
		return "%s_MIN + (float(_b.%s()) / %s.0) * %s_RANGE" % [
			prefix, _get_uint_method(bs), str(max_val), prefix]
	elif bs == 2:
		return "_h2f(_b.get_u16())"
	else:
		return "_b.get_float()"


# ══════════════════════════════════════════════════
#  ХЕЛПЕРЫ (генерируются внизу выходного файла)
# ══════════════════════════════════════════════════

func _gen_helpers() -> PackedStringArray:
	var L := PackedStringArray()
	L.append("# ═══════════════════════════════════════════════════")
	L.append("#  Вспомогательные функции (half-float)")
	L.append("# ═══════════════════════════════════════════════════")
	L.append("")
	L.append("static func _f2h(v: float) -> int:")
	L.append("\tvar buf := PackedFloat32Array([v]).to_byte_array()")
	L.append("\tvar bits := buf.decode_u32(0)")
	L.append("\tvar s := (bits >> 31) & 1")
	L.append("\tvar e := int((bits >> 23) & 0xFF) - 127 + 15")
	L.append("\tvar m := (bits >> 13) & 0x3FF")
	L.append("\tif e <= 0: return s << 15")
	L.append("\tif e >= 31: return (s << 15) | 0x7C00")
	L.append("\treturn (s << 15) | (e << 10) | m")
	L.append("")
	L.append("")
	L.append("static func _h2f(h: int) -> float:")
	L.append("\tvar s := (h >> 15) & 1")
	L.append("\tvar e := (h >> 10) & 0x1F")
	L.append("\tvar m := h & 0x3FF")
	L.append("\tif e == 0: return 0.0")
	L.append("\tif e == 31: return INF if s == 0 else -INF")
	L.append("\tvar bits := (s << 31) | ((e - 15 + 127) << 23) | (m << 13)")
	L.append("\tvar buf := PackedByteArray()")
	L.append("\tbuf.resize(4)")
	L.append("\tbuf.encode_u32(0, bits)")
	L.append("\treturn buf.decode_float(0)")
	L.append("")
	return L


# ══════════════════════════════════════════════════
#  КВАНТИЗАЦИОННЫЕ КОНСТАНТЫ
# ══════════════════════════════════════════════════

## Собирает уникальные пары (min, max) из всех quantized полей
## и генерирует precomputed константы для выходного файла.
func _collect_quantization_constants(defs: Array[NetworkPacketDef]) -> PackedStringArray:
	var L := PackedStringArray()
	var seen: Dictionary = {}

	for d in defs:
		for f: NetworkFieldDef in d.fields:
			if not f.use_quantization:
				continue
			var key := "%s_%s" % [_fstr(f.quantize_min), _fstr(f.quantize_max)]
			if key in seen:
				continue
			seen[key] = true

			var prefix := _quant_const_prefix(f.quantize_min, f.quantize_max)
			var range_val: float = f.quantize_max - f.quantize_min
			var inv_range: float = 1.0 / range_val if range_val > 0.0 else 0.0

			L.append("const %s_MIN := %s" % [prefix, _fstr(f.quantize_min)])
			L.append("const %s_MAX := %s" % [prefix, _fstr(f.quantize_max)])
			L.append("const %s_RANGE := %s" % [prefix, _fstr(range_val)])
			L.append("const %s_INV_RANGE := %s" % [prefix, _fstr(inv_range)])

	return L


## Генерирует префикс константы из min/max значений.
## -1.5 / 1.5 → "_Q_N1_5_TO_1_5"
func _quant_const_prefix(min_v: float, max_v: float) -> String:
	var min_s := _fstr(min_v).replace(".", "_").replace("-", "N")
	var max_s := _fstr(max_v).replace(".", "_").replace("-", "N")
	return "_Q_%s_TO_%s" % [min_s, max_s]


# ══════════════════════════════════════════════════
#  УТИЛИТЫ — РАЗМЕРЫ
# ══════════════════════════════════════════════════

## Размер одного компонента вектора в байтах.
func _component_byte_size(f: NetworkFieldDef, bs: int) -> int:
	if f.use_quantization:
		return bs
	elif bs == 2:
		return 2  # half-float
	else:
		return 4  # float32


## Полный размер одного поля в байтах (для offset tracking).
## Вызывается ТОЛЬКО для fixed-size полей (не STRING, не PACKED_BYTES).
func _field_byte_size(f: NetworkFieldDef) -> int:
	var bs := _resolve_byte_size(f)
	match f.field_type:
		NetworkFieldDef.FieldType.BOOL:
			return 1
		NetworkFieldDef.FieldType.INT:
			return bs
		NetworkFieldDef.FieldType.FLOAT:
			return _component_byte_size(f, bs)
		NetworkFieldDef.FieldType.VECTOR2:
			return _component_byte_size(f, bs) * 2
		NetworkFieldDef.FieldType.VECTOR3:
			return _component_byte_size(f, bs) * 3
	return 0


func _calc_body_size(d: NetworkPacketDef) -> int:
	var total := 0
	for f: NetworkFieldDef in d.fields:
		match f.field_type:
			NetworkFieldDef.FieldType.STRING, NetworkFieldDef.FieldType.PACKED_BYTES:
				return -1
		total += _field_byte_size(f)
	return total


func _resolve_byte_size(f: NetworkFieldDef) -> int:
	if f.byte_size != NetworkFieldDef.ByteSize.AUTO:
		return [0, 1, 2, 4][f.byte_size]
	match f.field_type:
		NetworkFieldDef.FieldType.BOOL:    return 1
		NetworkFieldDef.FieldType.INT:     return 4
		NetworkFieldDef.FieldType.FLOAT:   return 4
		NetworkFieldDef.FieldType.VECTOR2:  return 4
		NetworkFieldDef.FieldType.VECTOR3:  return 4
	return 4


# ══════════════════════════════════════════════════
#  УТИЛИТЫ — ТИПЫ И МЕТОДЫ
# ══════════════════════════════════════════════════

func _gdscript_type(f: NetworkFieldDef) -> String:
	match f.field_type:
		NetworkFieldDef.FieldType.BOOL:         return "bool"
		NetworkFieldDef.FieldType.INT:          return "int"
		NetworkFieldDef.FieldType.FLOAT:        return "float"
		NetworkFieldDef.FieldType.VECTOR2:      return "Vector2"
		NetworkFieldDef.FieldType.VECTOR3:      return "Vector3"
		NetworkFieldDef.FieldType.STRING:        return "String"
		NetworkFieldDef.FieldType.PACKED_BYTES:  return "PackedByteArray"
	return "Variant"


## encode_* метод для PackedByteArray (direct write path)
func _encode_int_method(bs: int, is_signed: bool) -> String:
	if is_signed:
		match bs:
			1: return "encode_s8"
			2: return "encode_s16"
			4: return "encode_s32"
	match bs:
		1: return "encode_u8"
		2: return "encode_u16"
		4: return "encode_u32"
	return "encode_u32"


## encode_u* метод для квантизованных значений (direct write path)
func _encode_uint_method_direct(bs: int) -> String:
	match bs:
		1: return "encode_u8"
		2: return "encode_u16"
		4: return "encode_u32"
	return "encode_u16"


## put_* метод для StreamPeerBuffer (variable write path)
func _put_int_method(bs: int, is_signed: bool) -> String:
	if is_signed:
		return ["put_8", "put_8", "put_16", "put_32"][_bs_idx(bs)]
	return ["put_u8", "put_u8", "put_u16", "put_u32"][_bs_idx(bs)]


func _get_int_method(bs: int, is_signed: bool) -> String:
	if is_signed:
		return ["get_8", "get_8", "get_16", "get_32"][_bs_idx(bs)]
	return ["get_u8", "get_u8", "get_u16", "get_u32"][_bs_idx(bs)]


func _put_uint_method(bs: int) -> String:
	return ["put_u8", "put_u8", "put_u16", "put_u32"][_bs_idx(bs)]


func _get_uint_method(bs: int) -> String:
	return ["get_u8", "get_u8", "get_u16", "get_u32"][_bs_idx(bs)]


func _bs_idx(bs: int) -> int:
	match bs:
		1: return 1
		2: return 2
		4: return 3
	return 3


func _quant_max_val(bs: int) -> int:
	match bs:
		1: return 255
		2: return 65535
		4: return 4294967295
	return 65535


func _fstr(v: float) -> String:
	var s := str(v)
	if "." not in s and "e" not in s and "inf" not in s.to_lower():
		s += ".0"
	return s


# ══════════════════════════════════════════════════
#  СОХРАНЕНИЕ И ОТЧЁТ
# ══════════════════════════════════════════════════

func _save(code: String) -> bool:
	var file := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[builder] Не могу записать %s: %s" % [
			OUTPUT_PATH, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(code)
	file.close()
	print("[builder] Записан: %s" % OUTPUT_PATH)
	return true


func _report(defs: Array[NetworkPacketDef]) -> void:
	print("")
	print("═══════════════════════════════════════")
	print("   Сборка завершена!")
	print("═══════════════════════════════════════")
	print("")
	for d in defs:
		var body_size := _calc_body_size(d)
		var size_str := "%d байт" % body_size if body_size >= 0 else "переменный"
		var ch_str := "reliable" if d.channel == 0 else "unreliable"
		print("  %-20s  id=%-6d  %s  %s  [%d полей]" % [
			d.packet_name, d.get_packet_id(), size_str, ch_str, d.fields.size()])
	print("")
	print("Файлов: %d" % defs.size())
	print("Выход:  %s" % OUTPUT_PATH)
	print("")
