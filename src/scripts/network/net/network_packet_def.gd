class_name NetworkPacketDef
extends Resource
## Описание сетевого пакета.

## ═══ Уникальное имя ═══
@export var packet_name: String = ""

## ═══ Направление и маршрутизация ═══
enum SyncMode {
	CLIENT_TO_SERVER,         # 0
	SERVER_TO_ALL,            # 1
	SERVER_TO_OTHERS,         # 2
	CLIENT_TO_ALL_VIA_SERVER, # 3
	SERVER_TO_OWNER,          # 4
}
@export var sync_mode: SyncMode = SyncMode.CLIENT_TO_ALL_VIA_SERVER

## ═══ Надёжность канала ═══
enum ChannelMode { RELIABLE, UNRELIABLE }
@export var channel: ChannelMode = ChannelMode.RELIABLE

## ═══ Серверная валидация ═══
@export var server_validates: bool = false

## ═══ Поля (порядок = порядок байтов) ═══
@export var fields: Array[NetworkFieldDef] = []

## ═══ Описание (просто комментарий) ═══
@export_multiline var description: String = ""


## Packet ID — хеш от имени + смещение 100 (не пересекается с PacketTypes 1-8)
func get_packet_id() -> int:
	return 100 + (packet_name.hash() & 0xFFFF)
