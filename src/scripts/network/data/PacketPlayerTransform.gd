class_name PacketPlayerTransform extends PacketBase

## Раскладка байтов:
## [0]       — packet_type   (1 байт)
## [1]       — id            (1 байт)
## [2..5]    — position.x    (4 байта, float)
## [6..9]    — position.y    (4 байта, float)
## [10..13]  — position.z    (4 байта, float)
## [14..17]  — rotation_y    (4 байта, float)
## Итого: 18 байт

var id: int
var position: Vector3
var rotation_y: float          # Поворот вокруг оси Y (градусы или радианы — на твоё усмотрение)

static func create(id: int, position: Vector3, rotation_y: float = 0.0) -> PacketPlayerTransform:
	var info := PacketPlayerTransform.new()
	info.packet_type = PACKET_TYPE.PLAYER_TRANSFORM
	info.flag = ENetPacketPeer.FLAG_UNSEQUENCED
	info.id = id
	info.position = position
	info.rotation_y = rotation_y
	return info

static func create_from_data(data: PackedByteArray) -> PacketPlayerTransform:
	var info := PacketPlayerTransform.new()
	info.decode(data)
	return info

func encode() -> PackedByteArray:
	var data: PackedByteArray = super.encode()
	data.resize(18)
	data.encode_u8(1, id)
	data.encode_float(2, position.x)
	data.encode_float(6, position.y)
	data.encode_float(10, position.z)
	data.encode_float(14, rotation_y)
	return data

func decode(data: PackedByteArray) -> void:
	super.decode(data)
	id = data.decode_u8(1)
	position = Vector3(
		data.decode_float(2),
		data.decode_float(6),
		data.decode_float(10)
	)
	rotation_y = data.decode_float(14)
