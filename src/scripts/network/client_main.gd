extends Node3D

const ADDRESS := "127.0.0.1"
const PORT    := 9999

const PLAYER_SCENE        = preload("res://src/scenes/entities/player/HumanPlayer.tscn")
const REMOTE_PLAYER_SCENE = preload("res://src/scenes/entities/player/HumanPlayer.tscn")

var _net: NetworkManager = null
var _pm: PlayerManager = null
var _nam: NetworkActionManager = null
var _world_runtime: ClientWorldRuntimeManager = null
var _session: ClientSessionManager = null


func _ready() -> void:
	if Global.server_start:
		var client_scene = preload("res://src/scripts/network/server_main.tscn").instantiate()
		add_child(client_scene)
	_net = NetworkManager.new()
	_net.name = "NetworkManager"
	add_child(_net)

	_pm = PlayerManager.new()
	_pm.name = "PlayerManager"
	add_child(_pm)

	_nam = NetworkActionManager.new()
	_nam.name = "NetworkActionManager"
	add_child(_nam)

	_world_runtime = ClientWorldRuntimeManager.new()
	_world_runtime.name = "ClientWorldRuntimeManager"
	add_child(_world_runtime)

	_session = ClientSessionManager.new()
	_session.name = "ClientSessionManager"
	add_child(_session)

	_nam.setup(_net)
	_nam.auto_bind_receiver(_pm)

	_world_runtime.setup(
		_net,
		_pm,
		_nam,
		PLAYER_SCENE,
		REMOTE_PLAYER_SCENE,
		_get_player_container()
	)

	_session.setup(_net, _world_runtime)

	_session.session_ready.connect(_on_session_ready)
	_session.session_disconnected.connect(_on_session_disconnected)
	_session.auth_failed.connect(_on_auth_failed)

	var err := _session.connect_to_server(ADDRESS, PORT)
	if err != OK:
		push_error("[client] Не удалось подключиться")
		get_tree().quit(1)


## Безопасный поиск контейнера для игроков.
## Поддерживает разные структуры сцены.
func _get_player_container() -> Node:
	for path in ["World/Players", "Players", "."]:
		var node := get_node_or_null(path)
		if node != null:
			return node

	var container := Node3D.new()
	container.name = "Players"
	add_child(container)
	push_warning("[client] Контейнер Players не найден, создан автоматически")
	return container


func _on_session_ready(my_id: int) -> void:
	print("[client] Сессия готова, my_id=%d" % my_id)


func _on_session_disconnected() -> void:
	print("[client] Соединение потеряно")


func _on_auth_failed(message: String) -> void:
	print("[client] Auth failed: %s" % message)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if _session != null:
			_session.shutdown_session()

		if _net != null:
			_net.shutdown()

		get_tree().quit()
