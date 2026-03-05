extends Node

const PORT    := 9999
const SPAWN_Y := 2.0

var _net  : NetworkManager
var _pm   : PlayerManager
var _nam  : NetworkActionManager
var _args : CmdArgs

var _port        : int   = 9999
var _max_clients : int   = 32
var _spawn_y     : float = 2.0
var _verbose     : bool  = false


func _ready() -> void:
	_args = CmdArgs.new()
	_port        = _args.get_int("--port", _port)
	_max_clients = _args.get_int("--max-clients", _max_clients)
	_spawn_y     = _args.get_float("--spawn-y", _spawn_y)
	_verbose     = _args.has_flag("--verbose")

	get_tree().auto_accept_quit = false

	# Сеть
	_net = NetworkManager.new()
	_net.name = "NetworkManager"
	add_child(_net)

	_pm = PlayerManager.new()
	_pm.name = "PlayerManager"
	add_child(_pm)

	# NetworkActionManager — авто-маршрутизация сгенерированных пакетов
	_nam = NetworkActionManager.new()
	_nam.name = "NetworkActionManager"
	add_child(_nam)

	_net.peer_connected.connect(_on_peer_connected)
	_net.peer_disconnected.connect(_on_peer_disconnected)

	# Базовые обработчики (ручные, не через .tres)
	_net.register_handler(PacketTypes.PING, _on_ping)

	# Инициализация NAM (после register_handler для базовых!)
	_nam.setup(_net)

	# Серверная обработка player_move (обновление PM + пересылка через NAM)
	_nam.on_action("player_move", _on_player_move)

	var err := _net.create_server(_port, _max_clients)
	if err != OK:
		get_tree().quit(1)
		return
	_log("Сервер запущен на порту %d" % _port)


func _on_peer_connected(id: int) -> void:
	var pos := Vector3(randf_range(-5.0, 5.0), _spawn_y, randf_range(-5.0, 5.0))
	var rot := Vector3.ZERO
	_net.send_to_peer(id, PacketTypes.write_welcome(id, pos, rot))
	for eid: int in _pm.get_all_ids():
		var d: Dictionary = _pm.get_player_data(eid)
		_net.send_to_peer(id, PacketTypes.write_player_joined(
			eid, d["position"], d["rotation"]))
	_pm.add_player(id, pos, rot)
	_net.broadcast_except(id, PacketTypes.write_player_joined(id, pos, rot))
	_log("Игрок %d заспавнен в %s" % [id, pos])


func _on_peer_disconnected(id: int) -> void:
	_pm.remove_player(id)
	_net.broadcast(PacketTypes.write_player_left(id))
	_log("Игрок %d вышел" % id)


func _on_ping(peer_id: int, _body: StreamPeerBuffer) -> void:
	_net.send_to_peer(peer_id, PacketTypes.write_pong())


func _on_player_move(peer_id: int, data: Dictionary) -> void:
	# Обновляем PlayerManager данными из сгенерированного пакета
	var pos: Vector3 = data["position"]
	var rot := Vector3(data["head_pitch"], data["body_yaw"], 0.0)
	_pm.update_player(peer_id, pos, rot)


func _shutdown_graceful() -> void:
	_log("Завершение работы…")
	for id: int in _pm.get_all_ids():
		_net.send_to_peer(id, PacketTypes.write_player_left(id))
	if _net._host != null:
		_net._host.flush()
	_net.shutdown()
	_log("Сервер остановлен")
	get_tree().quit(0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_shutdown_graceful()


func _log(msg: String) -> void:
	var t := Time.get_time_string_from_system()
	print("[%s][server] %s" % [t, msg])
