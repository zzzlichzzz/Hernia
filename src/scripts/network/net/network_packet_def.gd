class_name NetworkPacketDef
extends Resource

@export var packet_name: String = ""

enum SyncMode {
	CLIENT_TO_SERVER,
	SERVER_TO_ALL,
	SERVER_TO_OTHERS,
	CLIENT_TO_ALL_VIA_SERVER,
	SERVER_TO_OWNER,
}
@export var sync_mode: SyncMode = SyncMode.CLIENT_TO_ALL_VIA_SERVER

enum ChannelMode { RELIABLE, UNRELIABLE }
@export var channel: ChannelMode = ChannelMode.RELIABLE

## Частота отправки (Гц). 0 = событийный (send_action вручную).
## 20 = 20 раз/сек. 60 = 60 раз/сек.
@export_range(0, 120, 1) var send_rate_hz: int = 0

@export var server_validates: bool = false
@export var fields: Array[NetworkFieldDef] = []
@export_multiline var description: String = ""


func get_packet_id() -> int:
	return 100 + (packet_name.hash() & 0xFFFF)
