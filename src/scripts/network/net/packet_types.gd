class_name PacketTypes
## Типы пакетов и утилиты ручной сериализации.
##
## Формат:  [ 1B type ][ 2B body_len LE ][ body_len bytes body ]

# ── Типы ──────────────────────────────────────────
enum {
	CONNECT        = 1,
	DISCONNECT     = 2,
	PING           = 3,
	PONG           = 4,
	PLAYER_UPDATE  = 5,   # позиция + поворот
	PLAYER_JOINED  = 6,   # новый игрок (reliable)
	PLAYER_LEFT    = 7,   # игрок ушёл   (reliable)
	WELCOME        = 8,   # сервер → клиент: твой id + спавн
}

const HEADER_SIZE := 3


# ══════════════════════════════════════════════════
#  ОБЩИЕ
# ══════════════════════════════════════════════════

static func write_packet(type: int, body: PackedByteArray = PackedByteArray()) -> PackedByteArray:
	var buf := StreamPeerBuffer.new()
	buf.big_endian = false
	buf.put_u8(type)
	buf.put_u16(body.size())
	if body.size() > 0:
		buf.put_data(body)
	return buf.data_array


static func read_packet(raw: PackedByteArray) -> Dictionary:
	if raw.size() < HEADER_SIZE:
		push_warning("PacketTypes: пакет слишком короткий (%d)" % raw.size())
		return { "type": -1, "body": null }
	var r := StreamPeerBuffer.new()
	r.big_endian = false
	r.data_array = raw
	r.seek(0)
	var pkt_type : int = r.get_u8()
	var body_len : int = r.get_u16()
	if raw.size() < HEADER_SIZE + body_len:
		push_warning("PacketTypes: неполное тело (%d < %d)" % [raw.size(), HEADER_SIZE + body_len])
		return { "type": -1, "body": null }
	var body := StreamPeerBuffer.new()
	body.big_endian = false
	if body_len > 0:
		body.data_array = raw.slice(HEADER_SIZE, HEADER_SIZE + body_len)
	body.seek(0)
	return { "type": pkt_type, "body": body }


# ══════════════════════════════════════════════════
#  Внутренние хелперы: «состояние игрока»
#  Формат тела:  [ 4B id ][ 3×4B pos ][ 3×4B rot ] = 28 байт
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
#  Клиент → сервер: id можно 0, сервер берёт peer_id
#  Сервер → клиенты: id = реальный peer_id отправителя
# ══════════════════════════════════════════════════

static func write_player_update(id: int, pos: Vector3, rot: Vector3) -> PackedByteArray:
	return write_packet(PLAYER_UPDATE, _write_state_body(id, pos, rot))

static func read_player_update(buf: StreamPeerBuffer) -> Dictionary:
	return _read_state_body(buf)
