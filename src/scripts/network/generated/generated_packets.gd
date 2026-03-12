# ═══════════════════════════════════════════════════
# AUTO-GENERATED — DO NOT EDIT
# Source: res://src/scripts/network/actions/
# Date:   2026-03-12T21:21:52
# ═══════════════════════════════════════════════════
class_name GeneratedPackets

const BLOCK_BREAK_ID := 53016
const BLOCK_PLACE_ID := 51992
const CHAMELEON_PAINT_ID := 61104
const PLAYER_CORRECTION_ID := 35565
const PLAYER_MOVE_ID := 37676
const PLAYER_SNAPSHOT_ID := 2245

## Метаданные пакетов для NetworkActionManager
const PACKETS := {
	53016: {
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
	51992: {
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
	61104: {
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
	35565: {
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
	37676: {
		"name": "player_move",
		"sync_mode": 0,
		"channel": 1,
		"server_validates": true,
		"field_names": ["peer_id", "tick", "position", "head_pitch", "body_yaw"],
		"send_rate_hz": 20,
		"source_method": "get_network_state",
		"receive_method": "apply_network_state",
		"auto_peer_id": true,
		"source_keys": {"peer_id": "peer_id", "tick": "tick", "position": "position", "head_pitch": "rotation.x", "body_yaw": "rotation.y"},
		"v_player_exists": true,
		"v_authenticated": true,
		"v_max_distance": 50.0,
		"v_max_speed": 10.0,
		"v_speed_tolerance": 1.5,
		"v_cooldown": 0.0,
		"v_position_field": "position",
		"v_max_action_dist": 0.0,
	},
	2245: {
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


# ─── block_break (id=53016, 16 bytes (fixed)) ───

static func write_block_break(peer_id: int, block_position: Vector3) -> PackedByteArray:
	var _b := StreamPeerBuffer.new()
	_b.big_endian = false
	_b.put_u32(peer_id)
	_b.put_float(block_position.x)
	_b.put_float(block_position.y)
	_b.put_float(block_position.z)
	return PacketTypes.write_packet(53016, _b.data_array)


static func read_block_break(_b: StreamPeerBuffer) -> Dictionary:
	var _peer_id := _b.get_u32()
	var _block_position := Vector3(_b.get_float(), _b.get_float(), _b.get_float())
	return {
		"peer_id": _peer_id,
		"block_position": _block_position,
	}


# ─── block_place (id=51992, 18 bytes (fixed)) ───

static func write_block_place(peer_id: int, block_position: Vector3, block_id: int) -> PackedByteArray:
	var _b := StreamPeerBuffer.new()
	_b.big_endian = false
	_b.put_u32(peer_id)
	_b.put_float(block_position.x)
	_b.put_float(block_position.y)
	_b.put_float(block_position.z)
	_b.put_u16(block_id)
	return PacketTypes.write_packet(51992, _b.data_array)


static func read_block_place(_b: StreamPeerBuffer) -> Dictionary:
	var _peer_id := _b.get_u32()
	var _block_position := Vector3(_b.get_float(), _b.get_float(), _b.get_float())
	var _block_id := _b.get_u16()
	return {
		"peer_id": _peer_id,
		"block_position": _block_position,
		"block_id": _block_id,
	}


# ─── chameleon_paint (id=61104, 18 bytes (fixed)) ───

static func write_chameleon_paint(peer_id: int, block_position: Vector3, source_block_id: int) -> PackedByteArray:
	var _b := StreamPeerBuffer.new()
	_b.big_endian = false
	_b.put_u32(peer_id)
	_b.put_float(block_position.x)
	_b.put_float(block_position.y)
	_b.put_float(block_position.z)
	_b.put_u16(source_block_id)
	return PacketTypes.write_packet(61104, _b.data_array)


static func read_chameleon_paint(_b: StreamPeerBuffer) -> Dictionary:
	var _peer_id := _b.get_u32()
	var _block_position := Vector3(_b.get_float(), _b.get_float(), _b.get_float())
	var _source_block_id := _b.get_u16()
	return {
		"peer_id": _peer_id,
		"block_position": _block_position,
		"source_block_id": _source_block_id,
	}


# ─── player_correction (id=35565, 20 bytes (fixed)) ───

static func write_player_correction(peer_id: int, tick: int, position: Vector3, head_pitch: float, body_yaw: float) -> PackedByteArray:
	var _b := StreamPeerBuffer.new()
	_b.big_endian = false
	_b.put_u16(peer_id)
	_b.put_u16(tick)
	_b.put_float(position.x)
	_b.put_float(position.y)
	_b.put_float(position.z)
	_b.put_u16(int(clampf((head_pitch - (-1.5)) / ((1.5) - (-1.5)), 0.0, 1.0) * 65535.0))
	_b.put_u16(int(clampf((body_yaw - (-3.15)) / ((3.15) - (-3.15)), 0.0, 1.0) * 65535.0))
	return PacketTypes.write_packet(35565, _b.data_array)


static func read_player_correction(_b: StreamPeerBuffer) -> Dictionary:
	var _peer_id := _b.get_u16()
	var _tick := _b.get_u16()
	var _position := Vector3(_b.get_float(), _b.get_float(), _b.get_float())
	var _head_pitch := (-1.5) + (float(_b.get_u16()) / 65535.0) * ((1.5) - (-1.5))
	var _body_yaw := (-3.15) + (float(_b.get_u16()) / 65535.0) * ((3.15) - (-3.15))
	return {
		"peer_id": _peer_id,
		"tick": _tick,
		"position": _position,
		"head_pitch": _head_pitch,
		"body_yaw": _body_yaw,
	}


# ─── player_move (id=37676, 20 bytes (fixed)) ───

static func write_player_move(peer_id: int, tick: int, position: Vector3, head_pitch: float, body_yaw: float) -> PackedByteArray:
	var _b := StreamPeerBuffer.new()
	_b.big_endian = false
	_b.put_u16(peer_id)
	_b.put_u16(tick)
	_b.put_float(position.x)
	_b.put_float(position.y)
	_b.put_float(position.z)
	_b.put_u16(int(clampf((head_pitch - (-1.5)) / ((1.5) - (-1.5)), 0.0, 1.0) * 65535.0))
	_b.put_u16(int(clampf((body_yaw - (-3.15)) / ((3.15) - (-3.15)), 0.0, 1.0) * 65535.0))
	return PacketTypes.write_packet(37676, _b.data_array)


static func read_player_move(_b: StreamPeerBuffer) -> Dictionary:
	var _peer_id := _b.get_u16()
	var _tick := _b.get_u16()
	var _position := Vector3(_b.get_float(), _b.get_float(), _b.get_float())
	var _head_pitch := (-1.5) + (float(_b.get_u16()) / 65535.0) * ((1.5) - (-1.5))
	var _body_yaw := (-3.15) + (float(_b.get_u16()) / 65535.0) * ((3.15) - (-3.15))
	return {
		"peer_id": _peer_id,
		"tick": _tick,
		"position": _position,
		"head_pitch": _head_pitch,
		"body_yaw": _body_yaw,
	}


# ─── player_snapshot (id=2245, 20 bytes (fixed)) ───

static func write_player_snapshot(peer_id: int, tick: int, position: Vector3, head_pitch: float, body_yaw: float) -> PackedByteArray:
	var _b := StreamPeerBuffer.new()
	_b.big_endian = false
	_b.put_u16(peer_id)
	_b.put_u16(tick)
	_b.put_float(position.x)
	_b.put_float(position.y)
	_b.put_float(position.z)
	_b.put_u16(int(clampf((head_pitch - (-1.5)) / ((1.5) - (-1.5)), 0.0, 1.0) * 65535.0))
	_b.put_u16(int(clampf((body_yaw - (-3.15)) / ((3.15) - (-3.15)), 0.0, 1.0) * 65535.0))
	return PacketTypes.write_packet(2245, _b.data_array)


static func read_player_snapshot(_b: StreamPeerBuffer) -> Dictionary:
	var _peer_id := _b.get_u16()
	var _tick := _b.get_u16()
	var _position := Vector3(_b.get_float(), _b.get_float(), _b.get_float())
	var _head_pitch := (-1.5) + (float(_b.get_u16()) / 65535.0) * ((1.5) - (-1.5))
	var _body_yaw := (-3.15) + (float(_b.get_u16()) / 65535.0) * ((3.15) - (-3.15))
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
