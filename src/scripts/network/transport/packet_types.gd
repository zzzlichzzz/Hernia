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

static var _cached_ping: PackedByteArray = PackedByteArray()
static var _cached_pong: PackedByteArray = PackedByteArray()
static var _pkt_cache_ready: bool = false

const HEADER_SIZE           := 8
const AUTH_REQUEST          := 9
const AUTH_RESPONSE         := 10
const CHAMELEON_SYNC        := 11
const MAX_FRAGMENT_BODY     := 1024
const PLAYER_SNAPSHOT_BATCH := 12

const SNAPSHOT_ENTRY_SIZE        := 32
const SNAPSHOT_BATCH_HEADER_SIZE := 2
const SNAPSHOT_BATCH_MAX_ENTRIES := int((MAX_FRAGMENT_BODY - SNAPSHOT_BATCH_HEADER_SIZE) / SNAPSHOT_ENTRY_SIZE)

const SNAPSHOT_PITCH_MIN := -1.5
const SNAPSHOT_PITCH_MAX := 1.5
const SNAPSHOT_YAW_MIN := -3.15
const SNAPSHOT_YAW_MAX := 3.15


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
	var body_size: int = body.size()

	# Собираем header отдельно, потом склеиваем
	var header := PackedByteArray()
	header.resize(HEADER_SIZE)
	header.encode_u16(0, type)
	header.encode_u16(2, body_size)
	header.encode_u16(4, fragment_id)
	header.encode_u16(6, total_fragments)

	if body_size == 0:
		return header

	header.append_array(body)
	return header


static func read_packet(raw: PackedByteArray) -> Dictionary:
	if raw.size() < HEADER_SIZE:
		push_warning("PacketTypes: пакет слишком короткий (%d)" % raw.size())
		return _bad_packet()

	# ——— Читаем header напрямую из PackedByteArray ———
	var pkt_type: int        = raw.decode_u16(0)
	var body_len: int        = raw.decode_u16(2)
	var fragment_id: int     = raw.decode_u16(4)
	var total_fragments: int = raw.decode_u16(6)

	if raw.size() < HEADER_SIZE + body_len:
		push_warning("PacketTypes: неполное тело (%d < %d)"
				% [raw.size(), HEADER_SIZE + body_len])
		return _bad_packet()

	# Только ОДИН StreamPeerBuffer для body (нужен downstream readers)
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

	var total: int = ceili(float(body.size()) / float(MAX_FRAGMENT_BODY))
	var fragments: Array[PackedByteArray] = []
	fragments.resize(total)

	var offset := 0
	for i in total:
		var end: int = mini(offset + MAX_FRAGMENT_BODY, body.size())
		var chunk := body.slice(offset, end)

		var header := PackedByteArray()
		header.resize(HEADER_SIZE)
		header.encode_u16(0, type)
		header.encode_u16(2, chunk.size())
		header.encode_u16(4, i)
		header.encode_u16(6, total)
		header.append_array(chunk)

		fragments[i] = header
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

## Записать bulk-данные хамелеонов.
## state: { Vector3i → int (source_block_id) }
static func write_chameleon_sync_body(state: Dictionary) -> PackedByteArray:
	var b := StreamPeerBuffer.new()
	b.big_endian = false
	b.put_u32(state.size())
	for pos: Vector3i in state:
		b.put_32(pos.x)
		b.put_32(pos.y)
		b.put_32(pos.z)
		b.put_u16(state[pos])
	return b.data_array


## Прочитать bulk-данные хамелеонов.
## Возвращает { Vector3i → int }
static func read_chameleon_sync(buf: StreamPeerBuffer) -> Dictionary:
	var count := buf.get_u32()
	# Защита от бомбы
	if count > 100000:
		push_warning("chameleon_sync: слишком много записей: %d" % count)
		return {}
	var entries := {}
	for i in count:
		var x := buf.get_32()
		var y := buf.get_32()
		var z := buf.get_32()
		var block_id := buf.get_u16()
		entries[Vector3i(x, y, z)] = block_id
	return entries

# ══════════════════════════════════════════════════
#  PING / PONG
# ══════════════════════════════════════════════════
static func _ensure_pkt_cache() -> void:
	if _pkt_cache_ready:
		return
	_pkt_cache_ready = true

	_cached_ping.resize(HEADER_SIZE)
	_cached_ping.encode_u16(0, PING)
	_cached_ping.encode_u16(2, 0)
	_cached_ping.encode_u16(4, 0)
	_cached_ping.encode_u16(6, 0)

	_cached_pong.resize(HEADER_SIZE)
	_cached_pong.encode_u16(0, PONG)
	_cached_pong.encode_u16(2, 0)
	_cached_pong.encode_u16(4, 0)
	_cached_pong.encode_u16(6, 0)

static func write_ping() -> PackedByteArray:
	_ensure_pkt_cache()
	return _cached_ping

static func write_pong() -> PackedByteArray:
	_ensure_pkt_cache()
	return _cached_pong


# ══════════════════════════════════════════════════
#  WELCOME       сервер → клиент
# ══════════════════════════════════════════════════

static func write_welcome(id: int, pos: Vector3, rot: Vector3) -> PackedByteArray:
	return _write_state_packet(WELCOME, id, pos, rot)

static func read_welcome(buf: StreamPeerBuffer) -> Dictionary:
	return _read_state_body(buf)


# ══════════════════════════════════════════════════
#  PLAYER_JOINED   сервер → клиенты
# ══════════════════════════════════════════════════

static func write_player_joined(id: int, pos: Vector3, rot: Vector3) -> PackedByteArray:
	return _write_state_packet(PLAYER_JOINED, id, pos, rot)

static func read_player_joined(buf: StreamPeerBuffer) -> Dictionary:
	return _read_state_body(buf)


# ══════════════════════════════════════════════════
#  PLAYER_LEFT     сервер → клиенты
# ══════════════════════════════════════════════════

static func write_player_left(id: int) -> PackedByteArray:
	var pkt := PackedByteArray()
	pkt.resize(HEADER_SIZE + 4)  # header + one s32

	pkt.encode_u16(0, PLAYER_LEFT)
	pkt.encode_u16(2, 4)     # body_len = 4
	pkt.encode_u16(4, 0)     # fragment_id
	pkt.encode_u16(6, 0)     # total_fragments
	pkt.encode_s32(HEADER_SIZE, id)

	return pkt

static func read_player_left(buf: StreamPeerBuffer) -> Dictionary:
	return { "id": buf.get_32() }

## 28 bytes body: [ 4B id ][ 3×4B pos ][ 3×4B rot ]
static func _write_state_packet(type: int, id: int, pos: Vector3, rot: Vector3) -> PackedByteArray:
	const BODY_SIZE := 28  # 4 + 12 + 12
	var pkt := PackedByteArray()
	pkt.resize(HEADER_SIZE + BODY_SIZE)

	# Header
	pkt.encode_u16(0, type)
	pkt.encode_u16(2, BODY_SIZE)
	pkt.encode_u16(4, 0)
	pkt.encode_u16(6, 0)

	# Body
	var off: int = HEADER_SIZE
	pkt.encode_s32(off, id)
	pkt.encode_float(off + 4,  pos.x)
	pkt.encode_float(off + 8,  pos.y)
	pkt.encode_float(off + 12, pos.z)
	pkt.encode_float(off + 16, rot.x)
	pkt.encode_float(off + 20, rot.y)
	pkt.encode_float(off + 24, rot.z)

	return pkt

# ══════════════════════════════════════════════════
#  СБОРЩИК ФРАГМЕНТОВ
# ══════════════════════════════════════════════════

class FragmentAssembler:
	const MAX_FRAGMENTS_PER_PACKET := 64
	const MAX_ASSEMBLIES_PER_PEER  := 4
	const MAX_TOTAL_ASSEMBLIES     := 256

	var _buffers: Dictionary = {}
	## peer_id → count of active assemblies (быстрый лимит)
	var _peer_assembly_count: Dictionary = {}
	var timeout: float = 10.0


	func add_fragment(sender_id: int, type: int,
			fragment_id: int, total_fragments: int,
			body: StreamPeerBuffer) -> Variant:

		if total_fragments > MAX_FRAGMENTS_PER_PACKET:
			push_warning("FragmentAssembler: слишком много фрагментов %d" % total_fragments)
			return null

		if _buffers.size() >= MAX_TOTAL_ASSEMBLIES:
			push_warning("FragmentAssembler: буфер переполнен")
			return null

		# ——— Быстрый лимит на пира: O(1) вместо O(N) ———
		var peer_count: int = _peer_assembly_count.get(sender_id, 0)
		if peer_count >= MAX_ASSEMBLIES_PER_PEER:
			push_warning("FragmentAssembler: лимит сборок для peer %d" % sender_id)
			return null

		# ——— Int ключ вместо String ———
		var key: int = _make_key_int(sender_id, type)
		var now := Time.get_unix_time_from_system()

		var is_new := key not in _buffers
		if is_new:
			_buffers[key] = {
				"parts":     {},
				"total":     total_fragments,
				"timestamp": now,
				"sender":    sender_id,
			}
			_peer_assembly_count[sender_id] = peer_count + 1

		var entry: Dictionary = _buffers[key]
		if entry["total"] != total_fragments:
			push_warning("FragmentAssembler: total mismatch для key=%d" % key)
			_remove_assembly(key, sender_id)
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
				_remove_assembly(key, sender_id)
				return null
			full_body.append_array(entry["parts"][i])

		_remove_assembly(key, sender_id)

		var result := StreamPeerBuffer.new()
		result.big_endian = false
		result.data_array = full_body
		result.seek(0)
		return result


	func cleanup() -> void:
		var now := Time.get_unix_time_from_system()
		var expired: Array = []
		for bkey in _buffers:
			if now - (_buffers[bkey] as Dictionary)["timestamp"] > timeout:
				expired.append(bkey)
		for bkey in expired:
			var entry: Dictionary = _buffers[bkey]
			var sid: int = entry.get("sender", 0)
			_remove_assembly(bkey, sid)


	func clear() -> void:
		_buffers.clear()
		_peer_assembly_count.clear()


	func _remove_assembly(key: int, sender_id: int) -> void:
		_buffers.erase(key)
		var count: int = _peer_assembly_count.get(sender_id, 1) - 1
		if count <= 0:
			_peer_assembly_count.erase(sender_id)
		else:
			_peer_assembly_count[sender_id] = count


	## Int ключ: старшие 32 бита = sender_id, младшие 16 = type
	func _make_key_int(sender_id: int, type: int) -> int:
		return (sender_id << 16) | (type & 0xFFFF)

# ══════════════════════════════════════════════════
#  PLAYER SNAPSHOT BATCH
# ══════════════════════════════════════════════════

## entries: Array[Dictionary]
## Каждый entry:
## {
##   "peer_id": int,
##   "tick": int,
##   "position": Vector3,
##   "head_pitch": float,
##   "body_yaw": float,
## }
static func write_player_snapshot_batch_body(entries: Array) -> PackedByteArray:
	var b := StreamPeerBuffer.new()
	b.big_endian = false

	var count := mini(entries.size(), SNAPSHOT_BATCH_MAX_ENTRIES)
	b.put_u16(count)

	for i in count:
		var e: Dictionary = entries[i]

		var peer_id: int = int(e.get("peer_id", 0)) & 0xFFFF
		var tick: int = int(e.get("tick", 0)) & 0xFFFF
		var pos: Vector3 = e.get("position", Vector3.ZERO)
		var vel: Vector3 = e.get("velocity", Vector3.ZERO)
		var head_pitch: float = float(e.get("head_pitch", 0.0))
		var body_yaw: float = float(e.get("body_yaw", 0.0))

		b.put_u16(peer_id)
		b.put_u16(tick)

		b.put_float(pos.x)
		b.put_float(pos.y)
		b.put_float(pos.z)

		b.put_float(vel.x)
		b.put_float(vel.y)
		b.put_float(vel.z)

		b.put_u16(_encode_quantized_u16(head_pitch, SNAPSHOT_PITCH_MIN, SNAPSHOT_PITCH_MAX))
		b.put_u16(_encode_quantized_u16(body_yaw, SNAPSHOT_YAW_MIN, SNAPSHOT_YAW_MAX))

	return b.data_array


static func write_player_snapshot_batch(entries: Array) -> PackedByteArray:
	var count: int = mini(entries.size(), SNAPSHOT_BATCH_MAX_ENTRIES)
	var body_size: int = SNAPSHOT_BATCH_HEADER_SIZE + count * SNAPSHOT_ENTRY_SIZE
	var total_size: int = HEADER_SIZE + body_size

	var pkt := PackedByteArray()
	pkt.resize(total_size)

	# ——— Header (8 bytes) ———
	pkt.encode_u16(0, PLAYER_SNAPSHOT_BATCH)
	pkt.encode_u16(2, body_size)
	pkt.encode_u16(4, 0)   # fragment_id
	pkt.encode_u16(6, 0)   # total_fragments

	# ——— Body: count ———
	pkt.encode_u16(HEADER_SIZE, count)

	# ——— Body: entries ———
	var off: int = HEADER_SIZE + SNAPSHOT_BATCH_HEADER_SIZE

	for i in count:
		var e: Dictionary = entries[i]

		# peer_id (u16) + tick (u16)
		pkt.encode_u16(off,     int(e.get("peer_id", 0)) & 0xFFFF)
		pkt.encode_u16(off + 2, int(e.get("tick", 0)) & 0xFFFF)

		# position (3 × float32)
		var pos: Vector3 = e.get("position", Vector3.ZERO)
		pkt.encode_float(off + 4,  pos.x)
		pkt.encode_float(off + 8,  pos.y)
		pkt.encode_float(off + 12, pos.z)

		# velocity (3 × float32)
		var vel: Vector3 = e.get("velocity", Vector3.ZERO)
		pkt.encode_float(off + 16, vel.x)
		pkt.encode_float(off + 20, vel.y)
		pkt.encode_float(off + 24, vel.z)

		# head_pitch + body_yaw (2 × quantized u16)
		var hp: float = float(e.get("head_pitch", 0.0))
		var by: float = float(e.get("body_yaw", 0.0))
		pkt.encode_u16(off + 28, _encode_quantized_u16(hp, SNAPSHOT_PITCH_MIN, SNAPSHOT_PITCH_MAX))
		pkt.encode_u16(off + 30, _encode_quantized_u16(by, SNAPSHOT_YAW_MIN, SNAPSHOT_YAW_MAX))

		off += SNAPSHOT_ENTRY_SIZE

	return pkt

## Оптимизированная версия: читает прямо из PackedByteArray
## Если вызывается из read_packet, body.data_array уже содержит тело
static func read_player_snapshot_batch(buf: StreamPeerBuffer) -> Array[Dictionary]:
	var raw: PackedByteArray = buf.data_array
	var base: int = buf.get_position()  # обычно 0

	if raw.size() < base + 2:
		return []

	var count: int = raw.decode_u16(base)
	base += 2

	if count > 512:
		push_warning("player_snapshot_batch: слишком много записей: %d" % count)
		return []

	var needed: int = base + count * SNAPSHOT_ENTRY_SIZE
	if raw.size() < needed:
		push_warning("player_snapshot_batch: недостаточно данных")
		return []

	var result: Array[Dictionary] = []
	result.resize(count)

	for i in count:
		var off: int = base + i * SNAPSHOT_ENTRY_SIZE

		var peer_id: int = raw.decode_u16(off)
		var tick: int    = raw.decode_u16(off + 2)

		var pos := Vector3(
			raw.decode_float(off + 4),
			raw.decode_float(off + 8),
			raw.decode_float(off + 12)
		)

		var vel := Vector3(
			raw.decode_float(off + 16),
			raw.decode_float(off + 20),
			raw.decode_float(off + 24)
		)

		var head_pitch: float = _decode_quantized_u16(
			raw.decode_u16(off + 28),
			SNAPSHOT_PITCH_MIN, SNAPSHOT_PITCH_MAX
		)
		var body_yaw: float = _decode_quantized_u16(
			raw.decode_u16(off + 30),
			SNAPSHOT_YAW_MIN, SNAPSHOT_YAW_MAX
		)

		result[i] = {
			"peer_id": peer_id,
			"tick": tick,
			"position": pos,
			"velocity": vel,
			"head_pitch": head_pitch,
			"body_yaw": body_yaw,
		}

	return result

static func _encode_quantized_u16(v: float, min_v: float, max_v: float) -> int:
	if max_v <= min_v:
		return 0
	return int(clampf((v - min_v) / (max_v - min_v), 0.0, 1.0) * 65535.0)


static func _decode_quantized_u16(raw: int, min_v: float, max_v: float) -> float:
	if max_v <= min_v:
		return min_v
	return min_v + (float(raw) / 65535.0) * (max_v - min_v)
