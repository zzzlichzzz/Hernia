class_name PacketTypes
## Типы пакетов и утилиты сериализации.
##
## Формат заголовка (8 байт):
##   [ 2B type ][ 2B body_len ][ 2B fragment_id ][ 2B total_fragments ]

# ── Хардкод-типы (служебные пакеты) ──────────────
enum {
	PING           = 3,
	PONG           = 4,
	PLAYER_JOINED  = 6,
	PLAYER_LEFT    = 7,
	WELCOME        = 8,
}

const HEADER_SIZE       := 8
const AUTH_REQUEST      := 9
const AUTH_RESPONSE     := 10
const MAX_FRAGMENT_BODY := 1024


# ══════════════════════════════════════════════════
#  АУТЕНТИФИКАЦИЯ
# ══════════════════════════════════════════════════

static func write_auth_request(token: String) -> PackedByteArray:
	var b := StreamPeerBuffer.new()
	b.big_endian = false
	var utf := token.to_utf8_buffer()
	b.put_u16(utf.size())
	if utf.size() > 0:
		b.put_data(utf)
	return write_packet(AUTH_REQUEST, b.data_array)


static func read_auth_request(buf: StreamPeerBuffer) -> Dictionary:
	var tok_len := buf.get_u16()
	var token := ""
	if tok_len > 0 and tok_len <= 256:
		token = buf.get_data(tok_len)[1].get_string_from_utf8()
	return { "token": token }


static func write_auth_response(success: bool, message: String = "") -> PackedByteArray:
	var b := StreamPeerBuffer.new()
	b.big_endian = false
	b.put_u8(1 if success else 0)
	var utf := message.to_utf8_buffer()
	b.put_u16(utf.size())
	if utf.size() > 0:
		b.put_data(utf)
	return write_packet(AUTH_RESPONSE, b.data_array)


static func read_auth_response(buf: StreamPeerBuffer) -> Dictionary:
	var success := buf.get_u8() != 0
	var msg_len := buf.get_u16()
	var message := ""
	if msg_len > 0 and msg_len <= 256:
		message = buf.get_data(msg_len)[1].get_string_from_utf8()
	return { "success": success, "message": message }


# ══════════════════════════════════════════════════
#  ЗАПИСЬ / ЧТЕНИЕ ПАКЕТА
# ══════════════════════════════════════════════════

static func write_packet(type: int,
		body: PackedByteArray = PackedByteArray(),
		fragment_id: int = 0,
		total_fragments: int = 0) -> PackedByteArray:
	var buf := StreamPeerBuffer.new()
	buf.big_endian = false
	buf.put_u16(type)
	buf.put_u16(body.size())
	buf.put_u16(fragment_id)
	buf.put_u16(total_fragments)
	if body.size() > 0:
		buf.put_data(body)
	return buf.data_array


static func read_packet(raw: PackedByteArray) -> Dictionary:
	if raw.size() < HEADER_SIZE:
		push_warning("PacketTypes: пакет слишком короткий (%d)" % raw.size())
		return _bad_packet()
	var r := StreamPeerBuffer.new()
	r.big_endian = false
	r.data_array = raw
	r.seek(0)
	var pkt_type        : int = r.get_u16()
	var body_len        : int = r.get_u16()
	var fragment_id     : int = r.get_u16()
	var total_fragments : int = r.get_u16()
	if raw.size() < HEADER_SIZE + body_len:
		push_warning("PacketTypes: неполное тело (%d < %d)"
				% [raw.size(), HEADER_SIZE + body_len])
		return _bad_packet()
	var body := StreamPeerBuffer.new()
	body.big_endian = false
	if body_len > 0:
		body.data_array = raw.slice(HEADER_SIZE, HEADER_SIZE + body_len)
	body.seek(0)
	return {
		"type":             pkt_type,
		"body":             body,
		"fragment_id":      fragment_id,
		"total_fragments":  total_fragments,
	}


static func _bad_packet() -> Dictionary:
	return {
		"type": -1,
		"body": null,
		"fragment_id": 0,
		"total_fragments": 0,
	}


# ══════════════════════════════════════════════════
#  ФРАГМЕНТАЦИЯ
# ══════════════════════════════════════════════════

static func needs_fragmentation(body_size: int) -> bool:
	return body_size > MAX_FRAGMENT_BODY


static func fragment_packet(type: int, body: PackedByteArray) -> Array[PackedByteArray]:
	if body.size() <= MAX_FRAGMENT_BODY:
		return [write_packet(type, body, 0, 0)]
	var fragments: Array[PackedByteArray] = []
	var offset := 0
	var total  := ceili(float(body.size()) / float(MAX_FRAGMENT_BODY))
	for i in total:
		var end   := mini(offset + MAX_FRAGMENT_BODY, body.size())
		var chunk := body.slice(offset, end)
		fragments.append(write_packet(type, chunk, i, total))
		offset = end
	return fragments


static func is_fragment(parsed: Dictionary) -> bool:
	return parsed["total_fragments"] > 0


# ══════════════════════════════════════════════════
#  ХЕЛПЕР: тело «состояние игрока»
#  [ 4B id ][ 3×4B pos ][ 3×4B rot ] = 28 байт
# ══════════════════════════════════════════════════

static func _write_state_body(id: int, pos: Vector3, rot: Vector3) -> PackedByteArray:
	var b := StreamPeerBuffer.new()
	b.big_endian = false
	b.put_32(id)
	b.put_float(pos.x); b.put_float(pos.y); b.put_float(pos.z)
	b.put_float(rot.x); b.put_float(rot.y); b.put_float(rot.z)
	return b.data_array


static func _read_state_body(b: StreamPeerBuffer) -> Dictionary:
	return {
		"id":       b.get_32(),
		"position": Vector3(b.get_float(), b.get_float(), b.get_float()),
		"rotation": Vector3(b.get_float(), b.get_float(), b.get_float()),
	}


# ══════════════════════════════════════════════════
#  PING / PONG
# ══════════════════════════════════════════════════

static func write_ping() -> PackedByteArray:
	return write_packet(PING)

static func write_pong() -> PackedByteArray:
	return write_packet(PONG)


# ══════════════════════════════════════════════════
#  WELCOME       сервер → клиент
# ══════════════════════════════════════════════════

static func write_welcome(id: int, pos: Vector3, rot: Vector3) -> PackedByteArray:
	return write_packet(WELCOME, _write_state_body(id, pos, rot))

static func read_welcome(buf: StreamPeerBuffer) -> Dictionary:
	return _read_state_body(buf)


# ══════════════════════════════════════════════════
#  PLAYER_JOINED   сервер → клиенты
# ══════════════════════════════════════════════════

static func write_player_joined(id: int, pos: Vector3, rot: Vector3) -> PackedByteArray:
	return write_packet(PLAYER_JOINED, _write_state_body(id, pos, rot))

static func read_player_joined(buf: StreamPeerBuffer) -> Dictionary:
	return _read_state_body(buf)


# ══════════════════════════════════════════════════
#  PLAYER_LEFT     сервер → клиенты
# ══════════════════════════════════════════════════

static func write_player_left(id: int) -> PackedByteArray:
	var b := StreamPeerBuffer.new()
	b.big_endian = false
	b.put_32(id)
	return write_packet(PLAYER_LEFT, b.data_array)

static func read_player_left(buf: StreamPeerBuffer) -> Dictionary:
	return { "id": buf.get_32() }


# ══════════════════════════════════════════════════
#  СБОРЩИК ФРАГМЕНТОВ
# ══════════════════════════════════════════════════

class FragmentAssembler:
	const MAX_FRAGMENTS_PER_PACKET := 64
	const MAX_ASSEMBLIES_PER_PEER  := 4
	const MAX_TOTAL_ASSEMBLIES     := 256

	var _buffers: Dictionary = {}
	var timeout: float = 10.0


	func add_fragment(sender_id: int, type: int,
			fragment_id: int, total_fragments: int,
			body: StreamPeerBuffer) -> Variant:

		# ── Защита от бомбы ───────────────────────
		if total_fragments > MAX_FRAGMENTS_PER_PACKET:
			push_warning("FragmentAssembler: слишком много фрагментов %d" % total_fragments)
			return null

		if _buffers.size() >= MAX_TOTAL_ASSEMBLIES:
			push_warning("FragmentAssembler: буфер переполнен")
			return null

		# Лимит на пира
		var peer_count := 0
		for bkey: String in _buffers:
			if bkey.begins_with("%d_" % sender_id):
				peer_count += 1
		if peer_count >= MAX_ASSEMBLIES_PER_PEER:
			push_warning("FragmentAssembler: лимит сборок для peer %d" % sender_id)
			return null

		# ── Сборка ────────────────────────────────
		var key := _make_key(sender_id, type)
		var now := Time.get_unix_time_from_system()

		if key not in _buffers:
			_buffers[key] = {
				"parts":     {},
				"total":     total_fragments,
				"timestamp": now,
			}

		var entry: Dictionary = _buffers[key]
		if entry["total"] != total_fragments:
			push_warning("FragmentAssembler: total mismatch для key=%s" % key)
			_buffers.erase(key)
			return null

		entry["parts"][fragment_id] = body.data_array
		entry["timestamp"] = now

		if entry["parts"].size() < total_fragments:
			return null

		# Все фрагменты собраны
		var full_body := PackedByteArray()
		for i in total_fragments:
			if i not in entry["parts"]:
				push_warning("FragmentAssembler: пропущен фрагмент %d" % i)
				_buffers.erase(key)
				return null
			full_body.append_array(entry["parts"][i])

		_buffers.erase(key)
		var result := StreamPeerBuffer.new()
		result.big_endian = false
		result.data_array = full_body
		result.seek(0)
		return result


	func cleanup() -> void:
		var now := Time.get_unix_time_from_system()
		var expired: Array = []
		for bkey: String in _buffers:
			if now - (_buffers[bkey] as Dictionary)["timestamp"] > timeout:
				expired.append(bkey)
		for bkey: String in expired:
			_buffers.erase(bkey)


	func clear() -> void:
		_buffers.clear()


	func _make_key(sender_id: int, type: int) -> String:
		return "%d_%d" % [sender_id, type]
