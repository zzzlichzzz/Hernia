@tool
class_name NetworkPacketDef
extends Resource

## Уникальное имя пакета (snake_case, латиница).
@export var packet_name: String = "":
	set(value):
		packet_name = value
		resource_name = value if value != "" else "unnamed_packet"

enum SyncMode {
	CLIENT_TO_SERVER,
	SERVER_TO_ALL,
	SERVER_TO_OTHERS,
	CLIENT_TO_ALL_VIA_SERVER,
	SERVER_TO_OWNER,
}
## Маршрутизация: кто отправляет и кому доставить.
@export var sync_mode: SyncMode = SyncMode.CLIENT_TO_ALL_VIA_SERVER

enum ChannelMode { RELIABLE, UNRELIABLE }
## RELIABLE = гарантия доставки. UNRELIABLE = быстро, без гарантий.
@export var channel: ChannelMode = ChannelMode.RELIABLE

## Частота авто-отправки (Гц). 0 = событийный. 20 = 20 раз/сек.
@export_range(0, 120, 1) var send_rate_hz: int = 0

## Включить серверную валидацию пакета.
@export var server_validates: bool = false

## Поля пакета. Порядок = порядок байтов.
@export var fields: Array[NetworkFieldDef] = []

## Описание (комментарий, не влияет на генерацию).
@export_multiline var description: String = ""

@export_group("Auto Sync")
## Метод на локальном игроке → Dictionary с данными.
@export var source_method: String = ""
## Метод на удалённом игроке (peer_id, data). Вызывается при приёме.
@export var receive_method: String = ""
## Авто-подстановка peer_id из bind_source.
@export var auto_peer_id: bool = true

@export_group("Server Validation")
## Проверять существование игрока в PlayerManager.
@export var validate_player_exists: bool = true
## Проверять что игрок аутентифицирован.
@export var validate_authenticated: bool = true
## Макс. перемещение за пакет (0 = выкл). Антителепорт.
@export var validate_max_distance: float = 0.0
## Макс. скорость, юнит/сек (0 = выкл). Антиспидхак.
@export var validate_max_speed: float = 0.0
## Множитель запаса скорости (компенсация лага).
@export var validate_speed_tolerance: float = 1.5
## Мин. интервал между пакетами, сек (0 = выкл). Антиспам.
@export var validate_cooldown: float = 0.0
## Имя поля с позицией для проверок дистанции.
@export var validate_position_field: String = "position"
## Макс. дистанция от игрока до точки действия (0 = выкл).
@export var validate_max_action_distance: float = 0.0


func get_packet_id() -> int:
	return 100 + (packet_name.hash() & 0xFFFF)
