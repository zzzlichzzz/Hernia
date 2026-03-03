extends Node

## ─── Сигналы ───
signal on_local_id_assigned(local_id: int)
signal on_remote_id_assigned(remote_id: int)
signal on_player_transform(transform_data: PacketPlayerTransform)
# Добавляй свои сигналы:
# signal on_chat_message(msg_data: PacketChatMessage)

## ─── Данные ───
var id: int = -1
var remote_ids: Array[int]

func _ready() -> void:
	NetConnection.on_client_packet.connect(_on_packet)

func _on_packet(data: PackedByteArray) -> void:
	var packet_type: int = data.decode_u8(0)

	match packet_type:
		PacketBase.PACKET_TYPE.ID_ASSIGNMENT:
			_manage_ids(PacketIDAssignment.create_from_data(data))

		PacketBase.PACKET_TYPE.PLAYER_TRANSFORM:
			on_player_transform.emit(PacketPlayerTransform.create_from_data(data))

		# Добавляй обработку новых типов:
		# PacketBase.PACKET_TYPE.CHAT_MESSAGE:
		#     on_chat_message.emit(PacketChatMessage.create_from_data(data))

		_:
			push_error("Unhandled packet type: ", packet_type)

func _manage_ids(assignment: PacketIDAssignment) -> void:
	if id == -1:
		# Первое подключение — получаем свой ID и список всех
		id = assignment.id
		on_local_id_assigned.emit(id)

		remote_ids = assignment.remote_ids
		for remote_id in remote_ids:
			if remote_id == id:
				continue
			on_remote_id_assigned.emit(remote_id)
	else:
		# Новый игрок подключился
		remote_ids.append(assignment.id)
		on_remote_id_assigned.emit(assignment.id)
