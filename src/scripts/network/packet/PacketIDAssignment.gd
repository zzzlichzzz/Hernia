class_name PacketIDAssignment extends PacketBase

var id: int
var remote_ids: Array[int]

static func create(id: int, remote_ids: Array[int]) -> PacketIDAssignment:
	var info := PacketIDAssignment.new()
	info.packet_type = PACKET_TYPE.ID_ASSIGNMENT
	info.flag = ENetPacketPeer.FLAG_RELIABLE
	info.id = id
	info.remote_ids = remote_ids
	return info

static func create_from_data(data: PackedByteArray) -> PacketIDAssignment:
	var info := PacketIDAssignment.new()
	info.decode(data)
	return info

func encode() -> PackedByteArray:
	var data: PackedByteArray = super.encode()
	data.resize(2 + remote_ids.size())
	data.encode_u8(1, id)
	for i in remote_ids.size():
		data.encode_u8(2 + i, remote_ids[i])
	return data

func decode(data: PackedByteArray) -> void:
	super.decode(data)
	id = data.decode_u8(1)
	for i in range(2, data.size()):
		remote_ids.append(data.decode_u8(i))
