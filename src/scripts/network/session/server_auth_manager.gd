class_name ServerAuthManager
extends Node

## Отвечает за:
## - peer connect bookkeeping
## - auth timeout
## - auth request / response
## - выдачу session_data после успешной аутентификации
##
## В будущем сюда же удобно подключить:
## - проверку transfer token от master server
## - выбор мира
## - загрузку персонажа
## - race_id / character_id / world_id

signal peer_authenticated(peer_id: int, session_data: Dictionary)
signal peer_auth_failed(peer_id: int, message: String)
signal peer_auth_timeout(peer_id: int)

var _net: NetworkManager = null
var _authenticated: Dictionary = {} # peer_id -> bool (внешняя ссылка)
var _connect_time: Dictionary = {}  # peer_id -> unix time

var _auth_timeout: float = 5.0
var _local_server_token: String = "my_game_v1"
var _default_spawn_y: float = 2.0

## Необязательный callback для внешней валидации.
## Сигнатура:
##   func(peer_id: int, token: String) -> Dictionary
##
## Ожидаемый результат:
## {
##   "success": bool,
##   "message": String,
##   "spawn_position": Vector3,
##   "spawn_rotation": Vector3,
##   "character_id": Variant,
##   "race_id": String,
##   "world_id": String,
## }
var _validator: Callable = Callable()


func setup(
	net: NetworkManager,
	authenticated_ref: Dictionary,
	auth_timeout: float = 5.0,
	local_server_token: String = "my_game_v1",
	default_spawn_y: float = 2.0,
	validator: Callable = Callable()
) -> void:
	_net = net
	_authenticated = authenticated_ref
	_auth_timeout = auth_timeout
	_local_server_token = local_server_token
	_default_spawn_y = default_spawn_y
	_validator = validator


func set_validator(validator: Callable) -> void:
	_validator = validator


func tick() -> void:
	_check_auth_timeout()


func on_peer_connected(peer_id: int) -> void:
	_authenticated[peer_id] = false
	_connect_time[peer_id] = Time.get_unix_time_from_system()


func clear_peer(peer_id: int) -> void:
	_authenticated.erase(peer_id)
	_connect_time.erase(peer_id)


func is_authenticated(peer_id: int) -> bool:
	return _authenticated.get(peer_id, false)


func get_connect_times() -> Dictionary:
	return _connect_time


func handle_auth_request(peer_id: int, body: StreamPeerBuffer) -> void:
	if _net == null:
		return

	# Повторный auth от уже авторизованного игрока игнорируем
	if _authenticated.get(peer_id, false):
		return

	var data := PacketTypes.read_auth_request(body)
	var token: String = data.get("token", "")

	var result := _validate_token(peer_id, token)
	var success: bool = bool(result.get("success", false))
	var message: String = result.get("message", "")

	if not success:
		_net.send_to_peer(peer_id, PacketTypes.write_auth_response(false, message))
		peer_auth_failed.emit(peer_id, message)

		await get_tree().create_timer(0.5).timeout
		if _net != null:
			_net.kick_peer(peer_id)
		return

	_authenticated[peer_id] = true
	_connect_time.erase(peer_id)

	_net.send_to_peer(peer_id, PacketTypes.write_auth_response(true))

	var session_data := _build_session_data(result)
	peer_authenticated.emit(peer_id, session_data)


# ══════════════════════════════════════════════════
#  INTERNAL
# ══════════════════════════════════════════════════

func _check_auth_timeout() -> void:
	if _net == null:
		return

	var now := Time.get_unix_time_from_system()
	var to_kick: Array[int] = []

	for peer_id in _connect_time.keys():
		var id: int = int(peer_id)
		if not _authenticated.get(id, false):
			if now - float(_connect_time[id]) > _auth_timeout:
				to_kick.append(id)

	for id in to_kick:
		peer_auth_timeout.emit(id)
		_net.kick_peer(id)
		_connect_time.erase(id)


func _validate_token(peer_id: int, token: String) -> Dictionary:
	# 1) Если есть внешний валидатор — пробуем его.
	if _validator.is_valid():
		var result = _validator.call(peer_id, token)
		if result is Dictionary:
			return result
		push_warning("[auth] validator returned non-Dictionary for peer_id=%d" % peer_id)
		return {
			"success": false,
			"message": "Internal auth error",
		}

	# 2) Локальный fallback — как сейчас у тебя было.
	if token != _local_server_token:
		return {
			"success": false,
			"message": "Bad token",
		}

	return {
		"success": true,
		"message": "",
		"spawn_position": Vector3(
			randf_range(-5.0, 5.0),
			_default_spawn_y,
			randf_range(-5.0, 5.0)
		),
		"spawn_rotation": Vector3.ZERO,

		# Поля на будущее:
		"character_id": peer_id,
		"race_id": "human",
		"world_id": "default_world",
	}


func _build_session_data(result: Dictionary) -> Dictionary:
	return {
		"spawn_position": result.get("spawn_position", Vector3.ZERO),
		"spawn_rotation": result.get("spawn_rotation", Vector3.ZERO),

		# На будущее для master server / character select / world transfer
		"character_id": result.get("character_id", null),
		"race_id": result.get("race_id", "human"),
		"world_id": result.get("world_id", "default_world"),
	}
