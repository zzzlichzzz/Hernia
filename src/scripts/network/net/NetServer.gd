extends Node

## ─── Сигналы ───
signal on_player_transform(peer_id: int, transform_data: PacketPlayerTransform)
# Добавляй свои:
# signal on_chat_message(peer_id: int, msg_data: PacketChatMessage)

var peer_ids: Array[int]

func _ready() -> void:
	NetConnection.on_peer_connected.connect(_on_peer_connected)
	NetConnection.on_peer_disconnected.connect(_on_peer_disconnected)
	NetConnection.on_server_packet.connect(_on_packet)

func _on_peer_connected(peer_id: int) -> void:
	peer_ids.append(peer_id)
	# Рассылаем всем информацию о новом игроке
	PacketIDAssignment.create(peer_id, peer_ids).broadcast(NetConnection.connection)

func _on_peer_disconnected(peer_id: int) -> void:
	peer_ids.erase(peer_id)

func _on_packet(peer_id: int, data: PackedByteArray) -> void:
	var packet_type: int = data.decode_u8(0)

	match packet_type:
		PacketBase.PACKET_TYPE.PLAYER_TRANSFORM:
			on_player_transform.emit(peer_id, PacketPlayerTransform.create_from_data(data))

		# Добавляй обработку:
		# PacketBase.PACKET_TYPE.CHAT_MESSAGE:
		#     on_chat_message.emit(peer_id, PacketChatMessage.create_from_data(data))

		_:
			push_error("Unhandled packet type: ", packet_type)
