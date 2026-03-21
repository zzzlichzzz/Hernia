# ═══════════════════════════════════════════════════
# AUTO-GENERATED — DO NOT EDIT
# Source: res://src/scripts/network/packets/
# Date:   2026-03-18T20:44:31
# ═══════════════════════════════════════════════════
class_name GeneratedPackets

const BLOCK_BREAK_ID := 1101
const BLOCK_PLACE_ID := 1102
const CHAMELEON_PAINT_ID := 1103
const PLAYER_CORRECTION_ID := 1002
const PLAYER_MOVE_ID := 1001
const PLAYER_SNAPSHOT_ID := 1003

const _HEADER_SIZE := PacketTypes.HEADER_SIZE  # 8

# Quantization constants (precomputed)
const _Q_N1_5_TO_1_5_MIN := -1.5
const _Q_N1_5_TO_1_5_MAX := 1.5
const _Q_N1_5_TO_1_5_RANGE := 3.0
const _Q_N1_5_TO_1_5_INV_RANGE := 0.33333333333333
const _Q_N3_15_TO_3_15_MIN := -3.15
const _Q_N3_15_TO_3_15_MAX := 3.15
const _Q_N3_15_TO_3_15_RANGE := 6.3
const _Q_N3_15_TO_3_15_INV_RANGE := 0.15873015873016

## Метаданные пакетов для NetworkActionManager
const PACKETS := {
	1101: {
		"name": "block_break",
		"sync_mode": 3,
		"channel": 0,
		"server_validates": true,
		"field_names": ["peer_id", "block_position"],
		"send_rate_hz": 0,
		"source_method": "",
		"receive_method": "",
		"auto_peer_id": true,
		"source_keys": {"peer_id": "peer_id", "block_position": "block_position"},
		"v_player_exists": true,
		"v_authenticated": true,
		"v_max_distance": 0.0,
		"v_max_speed": 0.0,
		"v_speed_tolerance": 1.5,
		"v_cooldown": 0.1,
		"v_position_field": "block_position",
		"v_max_action_dist": 12.0,
	},
	1102: {
		"name": "block_place",
		"sync_mode": 3,
		"channel": 0,
		"server_validates": true,
		"field_names": ["peer_id", "block_position", "block_id"],
		"send_rate_hz": 0,
		"source_method": "",
		"receive_method": "",
		"auto_peer_id": true,
		"source_keys": {"peer_id": "peer_id", "block_position": "block_position", "block_id": "block_id"},
		"v_player_exists": true,
		"v_authenticated": true,
		"v_max_distance": 0.0,
		"v_max_speed": 0.0,
		"v_speed_tolerance": 1.5,
		"v_cooldown": 0.1,
		"v_position_field": "block_position",
		"v_max_action_dist": 12.0,
	},
	1103: {
		"name": "chameleon_paint",
		"sync_mode": 3,
		"channel": 0,
		"server_validates": true,
		"field_names": ["peer_id", "block_position", "source_block_id"],
		"send_rate_hz": 0,
		"source_method": "",
		"receive_method": "",
		"auto_peer_id": true,
		"source_keys": {"peer_id": "peer_id", "block_position": "block_position", "source_block_id": "source_block_id"},
		"v_player_exists": true,
		"v_authenticated": true,
		"v_max_distance": 0.0,
		"v_max_speed": 0.0,
		"v_speed_tolerance": 1.5,
		"v_cooldown": 0.1,
		"v_position_field": "block_position",
		"v_max_action_dist": 12.0,
	},
	1002: {
		"name": "player_correction",
		"sync_mode": 4,
		"channel": 1,
		"server_validates": false,
		"field_names": ["peer_id", "tick", "position", "head_pitch", "body_yaw"],
		"send_rate_hz": 0,
		"source_method": "",
		"receive_method": "apply_correction_state",
		"auto_peer_id": false,
		"source_keys": {"peer_id": "peer_id", "tick": "tick", "position": "position", "head_pitch": "head_pitch", "body_yaw": "body_yaw"},
		"v_player_exists": true,
		"v_authenticated": true,
		"v_max_distance": 0.0,
		"v_max_speed": 0.0,
		"v_speed_tolerance": 1.5,
		"v_cooldown": 0.0,
		"v_position_field": "position",
		"v_max_action_dist": 0.0,
	},
	1001: {
		"name": "player_move",
		"sync_mode": 0,
		"channel": 1,
		"server_validates": true,
		"field_names": ["peer_id", "tick", "position", "velocity", "head_pitch", "body_yaw"],
		"send_rate_hz": 20,
		"source_method": "get_network_state",
		"receive_method": "apply_network_state",
		"auto_peer_id": true,
		"source_keys": {"peer_id": "peer_id", "tick": "tick", "position": "position", "velocity": "velocity", "head_pitch": "rotation.x", "body_yaw": "rotation.y"},
		"v_player_exists": true,
		"v_authenticated": true,
		"v_max_distance": 50.0,
		"v_max_speed": 10.0,
		"v_speed_tolerance": 1.5,
		"v_cooldown": 0.0,
		"v_position_field": "position",
		"v_max_action_dist": 0.0,
	},
	1003: {
		"name": "player_snapshot",
		"sync_mode": 1,
		"channel": 1,
		"server_validates": false,
		"field_names": ["peer_id", "tick", "position", "head_pitch", "body_yaw"],
		"send_rate_hz": 0,
		"source_method": "",
		"receive_method": "apply_network_state",
		"auto_peer_id": false,
		"source_keys": {"peer_id": "peer_id", "tick": "tick", "position": "position", "head_pitch": "head_pitch", "body_yaw": "body_yaw"},
		"v_player_exists": true,
		"v_authenticated": true,
		"v_max_distance": 0.0,
		"v_max_speed": 0.0,
		"v_speed_tolerance": 1.5,
		"v_cooldown": 0.0,
		"v_position_field": "position",
		"v_max_action_dist": 0.0,
	},
}


# ─── block_break (id=1101, 16 bytes (fixed)) ───

static func write_block_break(peer_id: int, block_position: Vector3) -> PackedByteArray:
	const BODY_SIZE := 16
	var pkt := PackedByteArray()
	pkt.resize(_HEADER_SIZE + BODY_SIZE)

	# Header
	pkt.encode_u16(0, 1101)
	pkt.encode_u16(2, BODY_SIZE)
	pkt.encode_u16(4, 0)
	pkt.encode_u16(6, 0)

	# Body
	pkt.encode_u32(_HEADER_SIZE, peer_id)
	pkt.encode_float(_HEADER_SIZE + 4, block_position.x)
	pkt.encode_float(_HEADER_SIZE + 8, block_position.y)
	pkt.encode_float(_HEADER_SIZE + 12, block_position.z)
	return pkt


static func read_block_break(_b: StreamPeerBuffer) -> Dictionary:
	var _peer_id := _b.get_u32()
	var _block_position := Vector3(_b.get_float(), _b.get_float(), _b.get_float())
	return {
		"peer_id": _peer_id,
		"block_position": _block_position,
	}


# ─── block_place (id=1102, 18 bytes (fixed)) ───

static func write_block_place(peer_id: int, block_position: Vector3, block_id: int) -> PackedByteArray:
	const BODY_SIZE := 18
	var pkt := PackedByteArray()
	pkt.resize(_HEADER_SIZE + BODY_SIZE)

	# Header
	pkt.encode_u16(0, 1102)
	pkt.encode_u16(2, BODY_SIZE)
	pkt.encode_u16(4, 0)
	pkt.encode_u16(6, 0)

	# Body
	pkt.encode_u32(_HEADER_SIZE, peer_id)
	pkt.encode_float(_HEADER_SIZE + 4, block_position.x)
	pkt.encode_float(_HEADER_SIZE + 8, block_position.y)
	pkt.encode_float(_HEADER_SIZE + 12, block_position.z)
	pkt.encode_u16(_HEADER_SIZE + 16, block_id)
	return pkt


static func read_block_place(_b: StreamPeerBuffer) -> Dictionary:
	var _peer_id := _b.get_u32()
	var _block_position := Vector3(_b.get_float(), _b.get_float(), _b.get_float())
	var _block_id := _b.get_u16()
	return {
		"peer_id": _peer_id,
		"block_position": _block_position,
		"block_id": _block_id,
	}


# ─── chameleon_paint (id=1103, 18 bytes (fixed)) ───

static func write_chameleon_paint(peer_id: int, block_position: Vector3, source_block_id: int) -> PackedByteArray:
	const BODY_SIZE := 18
	var pkt := PackedByteArray()
	pkt.resize(_HEADER_SIZE + BODY_SIZE)

	# Header
	pkt.encode_u16(0, 1103)
	pkt.encode_u16(2, BODY_SIZE)
	pkt.encode_u16(4, 0)
	pkt.encode_u16(6, 0)

	# Body
	pkt.encode_u32(_HEADER_SIZE, peer_id)
	pkt.encode_float(_HEADER_SIZE + 4, block_position.x)
	pkt.encode_float(_HEADER_SIZE + 8, block_position.y)
	pkt.encode_float(_HEADER_SIZE + 12, block_position.z)
	pkt.encode_u16(_HEADER_SIZE + 16, source_block_id)
	return pkt


static func read_chameleon_paint(_b: StreamPeerBuffer) -> Dictionary:
	var _peer_id := _b.get_u32()
	var _block_position := Vector3(_b.get_float(), _b.get_float(), _b.get_float())
	var _source_block_id := _b.get_u16()
	return {
		"peer_id": _peer_id,
		"block_position": _block_position,
		"source_block_id": _source_block_id,
	}


# ─── player_correction (id=1002, 20 bytes (fixed)) ───

static func write_player_correction(peer_id: int, tick: int, position: Vector3, head_pitch: float, body_yaw: float) -> PackedByteArray:
	const BODY_SIZE := 20
	var pkt := PackedByteArray()
	pkt.resize(_HEADER_SIZE + BODY_SIZE)

	# Header
	pkt.encode_u16(0, 1002)
	pkt.encode_u16(2, BODY_SIZE)
	pkt.encode_u16(4, 0)
	pkt.encode_u16(6, 0)

	# Body
	pkt.encode_u16(_HEADER_SIZE, peer_id)
	pkt.encode_u16(_HEADER_SIZE + 2, tick)
	pkt.encode_float(_HEADER_SIZE + 4, position.x)
	pkt.encode_float(_HEADER_SIZE + 8, position.y)
	pkt.encode_float(_HEADER_SIZE + 12, position.z)
	pkt.encode_u16(_HEADER_SIZE + 16, int(clampf((head_pitch - _Q_N1_5_TO_1_5_MIN) * _Q_N1_5_TO_1_5_INV_RANGE, 0.0, 1.0) * 65535.0))
	pkt.encode_u16(_HEADER_SIZE + 18, int(clampf((body_yaw - _Q_N3_15_TO_3_15_MIN) * _Q_N3_15_TO_3_15_INV_RANGE, 0.0, 1.0) * 65535.0))
	return pkt


static func read_player_correction(_b: StreamPeerBuffer) -> Dictionary:
	var _peer_id := _b.get_u16()
	var _tick := _b.get_u16()
	var _position := Vector3(_b.get_float(), _b.get_float(), _b.get_float())
	var _head_pitch := _Q_N1_5_TO_1_5_MIN + (float(_b.get_u16()) / 65535.0) * _Q_N1_5_TO_1_5_RANGE
	var _body_yaw := _Q_N3_15_TO_3_15_MIN + (float(_b.get_u16()) / 65535.0) * _Q_N3_15_TO_3_15_RANGE
	return {
		"peer_id": _peer_id,
		"tick": _tick,
		"position": _position,
		"head_pitch": _head_pitch,
		"body_yaw": _body_yaw,
	}


# ─── player_move (id=1001, 32 bytes (fixed)) ───

static func write_player_move(peer_id: int, tick: int, position: Vector3, velocity: Vector3, head_pitch: float, body_yaw: float) -> PackedByteArray:
	const BODY_SIZE := 32
	var pkt := PackedByteArray()
	pkt.resize(_HEADER_SIZE + BODY_SIZE)

	# Header
	pkt.encode_u16(0, 1001)
	pkt.encode_u16(2, BODY_SIZE)
	pkt.encode_u16(4, 0)
	pkt.encode_u16(6, 0)

	# Body
	pkt.encode_u16(_HEADER_SIZE, peer_id)
	pkt.encode_u16(_HEADER_SIZE + 2, tick)
	pkt.encode_float(_HEADER_SIZE + 4, position.x)
	pkt.encode_float(_HEADER_SIZE + 8, position.y)
	pkt.encode_float(_HEADER_SIZE + 12, position.z)
	pkt.encode_float(_HEADER_SIZE + 16, velocity.x)
	pkt.encode_float(_HEADER_SIZE + 20, velocity.y)
	pkt.encode_float(_HEADER_SIZE + 24, velocity.z)
	pkt.encode_u16(_HEADER_SIZE + 28, int(clampf((head_pitch - _Q_N1_5_TO_1_5_MIN) * _Q_N1_5_TO_1_5_INV_RANGE, 0.0, 1.0) * 65535.0))
	pkt.encode_u16(_HEADER_SIZE + 30, int(clampf((body_yaw - _Q_N3_15_TO_3_15_MIN) * _Q_N3_15_TO_3_15_INV_RANGE, 0.0, 1.0) * 65535.0))
	return pkt


static func read_player_move(_b: StreamPeerBuffer) -> Dictionary:
	var _peer_id := _b.get_u16()
	var _tick := _b.get_u16()
	var _position := Vector3(_b.get_float(), _b.get_float(), _b.get_float())
	var _velocity := Vector3(_b.get_float(), _b.get_float(), _b.get_float())
	var _head_pitch := _Q_N1_5_TO_1_5_MIN + (float(_b.get_u16()) / 65535.0) * _Q_N1_5_TO_1_5_RANGE
	var _body_yaw := _Q_N3_15_TO_3_15_MIN + (float(_b.get_u16()) / 65535.0) * _Q_N3_15_TO_3_15_RANGE
	return {
		"peer_id": _peer_id,
		"tick": _tick,
		"position": _position,
		"velocity": _velocity,
		"head_pitch": _head_pitch,
		"body_yaw": _body_yaw,
	}


# ─── player_snapshot (id=1003, 20 bytes (fixed)) ───

static func write_player_snapshot(peer_id: int, tick: int, position: Vector3, head_pitch: float, body_yaw: float) -> PackedByteArray:
	const BODY_SIZE := 20
	var pkt := PackedByteArray()
	pkt.resize(_HEADER_SIZE + BODY_SIZE)

	# Header
	pkt.encode_u16(0, 1003)
	pkt.encode_u16(2, BODY_SIZE)
	pkt.encode_u16(4, 0)
	pkt.encode_u16(6, 0)

	# Body
	pkt.encode_u16(_HEADER_SIZE, peer_id)
	pkt.encode_u16(_HEADER_SIZE + 2, tick)
	pkt.encode_float(_HEADER_SIZE + 4, position.x)
	pkt.encode_float(_HEADER_SIZE + 8, position.y)
	pkt.encode_float(_HEADER_SIZE + 12, position.z)
	pkt.encode_u16(_HEADER_SIZE + 16, int(clampf((head_pitch - _Q_N1_5_TO_1_5_MIN) * _Q_N1_5_TO_1_5_INV_RANGE, 0.0, 1.0) * 65535.0))
	pkt.encode_u16(_HEADER_SIZE + 18, int(clampf((body_yaw - _Q_N3_15_TO_3_15_MIN) * _Q_N3_15_TO_3_15_INV_RANGE, 0.0, 1.0) * 65535.0))
	return pkt


static func read_player_snapshot(_b: StreamPeerBuffer) -> Dictionary:
	var _peer_id := _b.get_u16()
	var _tick := _b.get_u16()
	var _position := Vector3(_b.get_float(), _b.get_float(), _b.get_float())
	var _head_pitch := _Q_N1_5_TO_1_5_MIN + (float(_b.get_u16()) / 65535.0) * _Q_N1_5_TO_1_5_RANGE
	var _body_yaw := _Q_N3_15_TO_3_15_MIN + (float(_b.get_u16()) / 65535.0) * _Q_N3_15_TO_3_15_RANGE
	return {
		"peer_id": _peer_id,
		"tick": _tick,
		"position": _position,
		"head_pitch": _head_pitch,
		"body_yaw": _body_yaw,
	}


# ═══════════════════════════════════════════════════
#  Вспомогательные функции (half-float)
# ═══════════════════════════════════════════════════

static func _f2h(v: float) -> int:
	var buf := PackedFloat32Array([v]).to_byte_array()
	var bits := buf.decode_u32(0)
	var s := (bits >> 31) & 1
	var e := int((bits >> 23) & 0xFF) - 127 + 15
	var m := (bits >> 13) & 0x3FF
	if e <= 0: return s << 15
	if e >= 31: return (s << 15) | 0x7C00
	return (s << 15) | (e << 10) | m


static func _h2f(h: int) -> float:
	var s := (h >> 15) & 1
	var e := (h >> 10) & 0x1F
	var m := h & 0x3FF
	if e == 0: return 0.0
	if e == 31: return INF if s == 0 else -INF
	var bits := (s << 31) | ((e - 15 + 127) << 23) | (m << 13)
	var buf := PackedByteArray()
	buf.resize(4)
	buf.encode_u32(0, bits)
	return buf.decode_float(0)
