class_name PacketTypes
## Типы пакетов и утилиты ручной сериализации.
##
## Формат заголовка (7 байт):
##   [ 1B type ][ 2B body_len ][ 2B fragment_id ][ 2B total_fragments ]
##
## Если total_fragments == 0 — обычный нефрагментированный пакет.
## Если total_fragments >  0 — fragment_id от 0 до total_fragments-1.

# ── Типы сообщений ────────────────────────────────
enum {
	CONNECT        = 1,
	DISCONNECT     = 2,
	PING           = 3,
	PONG           = 4,
	PLAYER_UPDATE  = 5,
	PLAYER_JOINED  = 6,
	PLAYER_LEFT    = 7,
	WELCOME        = 8,
}

const HEADER_SIZE       := 7
const MAX_FRAGMENT_BODY := 1024


# ══════════════════════════════════════════════════
#  ОБЩИЕ: запись / чтение пакета
# ══════════════════════════════════════════════════

static func write_packet(type: int,
		body: PackedByteArray = PackedByteArray(),
		fragment_id: int = 0,
		total_fragments: int = 0) -> PackedByteArray:
	var buf := StreamPeerBuffer.new()
	buf.big_endian = false
	buf.put_u8(type)
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
	var pkt_type        : int = r.get_u8()
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
#  ВНУТРЕННИЙ ХЕЛПЕР: «состояние игрока»
#  Тело:  [ 4B id ][ 3×4B pos ][ 3×4B rot ] = 28 байт
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

static func read_ping(_buf: StreamPeerBuffer) -> Dictionary:
	return {}

static func write_pong() -> PackedByteArray:
	return write_packet(PONG)

static func read_pong(_buf: StreamPeerBuffer) -> Dictionary:
	return {}


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
#  PLAYER_UPDATE   двусторонний (unreliable)
# ══════════════════════════════════════════════════

static func write_player_update(id: int, pos: Vector3, rot: Vector3) -> PackedByteArray:
	return write_packet(PLAYER_UPDATE, _write_state_body(id, pos, rot))

static func read_player_update(buf: StreamPeerBuffer) -> Dictionary:
	return _read_state_body(buf)


# ══════════════════════════════════════════════════
#  СБОРЩИК ФРАГМЕНТОВ
# ══════════════════════════════════════════════════

class FragmentAssembler:
	var _buffers: Dictionary = {}
	var timeout: float = 10.0

	func add_fragment(sender_id: int, type: int,
			fragment_id: int, total_fragments: int,
			body: StreamPeerBuffer) -> Variant:
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
		for key: String in _buffers:
			if now - (_buffers[key] as Dictionary)["timestamp"] > timeout:
				expired.append(key)
		for key: String in expired:
			push_warning("FragmentAssembler: таймаут сборки для %s" % key)
			_buffers.erase(key)

	func clear() -> void:
		_buffers.clear()

	func _make_key(sender_id: int, type: int) -> String:
		return "%d_%d" % [sender_id, type]
