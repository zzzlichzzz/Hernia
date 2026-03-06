# ═══════════════════════════════════════════════════
# AUTO-GENERATED — DO NOT EDIT
# Source: res://src/scripts/network/actions/
# Date:   2026-03-07T01:06:45
# ═══════════════════════════════════════════════════
class_name GeneratedPackets

const PLAYER_MOVE_ID := 37676

## Метаданные пакетов для NetworkActionManager
const PACKETS := {
	37676: {
		"name": "player_move",
		"sync_mode": 3,
		"channel": 0,
		"server_validates": true,
		"field_names": ["peer_id", "position", "head_pitch", "body_yaw"],
		"send_rate_hz": 20,
		"source_method": "get_network_state",
		"receive_method": "apply_network_state",
		"auto_peer_id": true,
		"source_keys": {"peer_id": "peer_id", "position": "position", "head_pitch": "rotation.x", "body_yaw": "rotation.y"},
		"v_player_exists": true,
		"v_authenticated": true,
		"v_max_distance": 50.0,
		"v_max_speed": 10.0,
		"v_speed_tolerance": 1.5,
		"v_cooldown": 0.0,
		"v_position_field": "position",
		"v_max_action_dist": 0.0,
	},
}


# ─── player_move (id=37676, 18 bytes (fixed)) ───

static func write_player_move(peer_id: int, position: Vector3, head_pitch: float, body_yaw: float) -> PackedByteArray:
	var _b := StreamPeerBuffer.new()
	_b.big_endian = false
	_b.put_u16(peer_id)
	_b.put_float(position.x)
	_b.put_float(position.y)
	_b.put_float(position.z)
	_b.put_u16(int(clampf((head_pitch - (-1.5)) / ((1.5) - (-1.5)), 0.0, 1.0) * 65535.0))
	_b.put_u16(int(clampf((body_yaw - (-3.15)) / ((3.15) - (-3.15)), 0.0, 1.0) * 65535.0))
	return PacketTypes.write_packet(37676, _b.data_array)


static func read_player_move(_b: StreamPeerBuffer) -> Dictionary:
	var _peer_id := _b.get_u16()
	var _position := Vector3(_b.get_float(), _b.get_float(), _b.get_float())
	var _head_pitch := (-1.5) + (float(_b.get_u16()) / 65535.0) * ((1.5) - (-1.5))
	var _body_yaw := (-3.15) + (float(_b.get_u16()) / 65535.0) * ((3.15) - (-3.15))
	return {
		"peer_id": _peer_id,
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

