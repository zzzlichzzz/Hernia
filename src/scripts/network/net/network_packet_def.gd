class_name NetworkPacketDef
extends Resource
## Описание сетевого пакета.

## ═══ Уникальное имя ═══
@export var packet_name: String = ""

## ═══ Направление и маршрутизация ═══
enum SyncMode {
	CLIENT_TO_SERVER,
	SERVER_TO_ALL,
	SERVER_TO_OTHERS,
	CLIENT_TO_ALL_VIA_SERVER,
	SERVER_TO_OWNER,
}
@export var sync_mode: SyncMode = SyncMode.CLIENT_TO_ALL_VIA_SERVER

## ═══ Надёжность канала ═══
enum ChannelMode { RELIABLE, UNRELIABLE }
@export var channel: ChannelMode = ChannelMode.RELIABLE

## ═══ Частота отправки (Гц) ═══
## 0 = событийный пакет (отправляется вручную, без таймера)
## 20 = 20 раз в секунду (каждые 50 мс)
## 60 = 60 раз в секунду (каждые ~16 мс)
@export_range(0, 120, 1) var send_rate_hz: int = 0

## ═══ Серверная валидация ═══
@export var server_validates: bool = false

## ═══ Поля (порядок = порядок байтов) ═══
@export var fields: Array[NetworkFieldDef] = []

## ═══ Описание (просто комментарий, ни на что не влияет) ═══
@export_multiline var description: String = ""


## Packet ID — хеш от имени + смещение 100
func get_packet_id() -> int:
	return 100 + (packet_name.hash() & 0xFFFF)


## Интервал между отправками в секундах. 0 = событийный.
func get_send_interval() -> float:
	if send_rate_hz <= 0:
		return 0.0
	return 1.0 / float(send_rate_hz)
