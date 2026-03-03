class_name PacketBase

enum PACKET_TYPE {
	ID_ASSIGNMENT = 0,
	PLAYER_TRANSFORM = 10,
	# Добавляй свои типы здесь, например:
	# CHAT_MESSAGE = 20,
	# OBJECT_SPAWN = 30,
}

var packet_type: PACKET_TYPE
var flag: int

func encode() -> PackedByteArray:
	var data: PackedByteArray
	data.resize(1)
	data.encode_u8(0, packet_type)
	return data

func decode(data: PackedByteArray) -> void:
	packet_type = data.decode_u8(0)

## Отправить конкретному игроку
func send(target: ENetPacketPeer) -> void:
	target.send(0, encode(), flag)

## Отправить всем подключённым
func broadcast(server: ENetConnection) -> void:
	server.broadcast(0, encode(), flag)
