extends Node

const PORT    := 9999
const SPAWN_Y := 2.0

var _net  : NetworkManager
var _pm   : PlayerManager
var _nam  : NetworkActionManager

var _port        : int   = 9999
var _max_clients : int   = 32
var _spawn_y     : float = 2.0
var _debug       : bool  = false

# Статистика
var _packets_received : int = 0
var _packets_sent     : int = 0


func _ready() -> void:
	var args := CmdArgs.new()
	_port        = args.get_int("--port", _port)
	_max_clients = args.get_int("--max-clients", _max_clients)
	_spawn_y     = args.get_float("--spawn-y", _spawn_y)
	_debug       = args.has_flag("--debug") or args.has_flag("-v") or args.has_flag("--verbose")

	get_tree().auto_accept_quit = false

	print("═══════════════════════════════════════")
	print("[server] Запуск сервера")
	print("[server] Порт: %d" % _port)
	print("[server] Макс. клиентов: %d" % _max_clients)
	print("[server] Отладка: %s" % ("ВКЛ" if _debug else "ВЫКЛ"))
	print("═══════════════════════════════════════")

	# Сеть
	_net = NetworkManager.new()
	_net.name = "NetworkManager"
	add_child(_net)

	_pm = PlayerManager.new()
	_pm.name = "PlayerManager"
	add_child(_pm)

	_nam = NetworkActionManager.new()
	_nam.name = "NetworkActionManager"
	add_child(_nam)

	_net.peer_connected.connect(_on_peer_connected)
	_net.peer_disconnected.connect(_on_peer_disconnected)

	# Базовые обработчики
	_net.register_handler(PacketTypes.PING, _on_ping)

	# NAM setup с отладкой
	_nam.setup(_net, _debug)

	# Подписываемся на player_move
	_nam.on_action("player_move", _on_player_move)

	# Отслеживание пакетов
	_nam.packet_received.connect(_on_packet_received)

	var err := _net.create_server(_port, _max_clients)
	if err != OK:
		push_error("[server] Не удалось создать сервер! Error: %d" % err)
		get_tree().quit(1)
		return

	_log("✓ Сервер запущен на порту %d" % _port)
	_log("  Ожидание подключений...")


func _on_packet_received(action_name: String, peer_id: int, data: Dictionary) -> void:
	_packets_received += 1
	if _debug and _packets_received % 100 == 0:
		_log("Статистика: получено=%d, отправлено=%d, игроков=%d" % [
			_packets_received, _packets_sent, _pm.get_all_ids().size()])


func _on_peer_connected(id: int) -> void:
	var pos := Vector3(randf_range(-5.0, 5.0), _spawn_y, randf_range(-5.0, 5.0))
	var rot := Vector3.ZERO

	_log("→ Игрок %d подключается..." % id)

	# WELCOME новому игроку
	_net.send_to_peer(id, PacketTypes.write_welcome(id, pos, rot))
	_log("  → WELCOME отправлен (id=%d, pos=%s)" % [id, pos])

	# Список существующих игроков
	var existing_count := 0
	for eid: int in _pm.get_all_ids():
		var d: Dictionary = _pm.get_player_data(eid)
		_net.send_to_peer(id, PacketTypes.write_player_joined(
			eid, d["position"], d["rotation"]))
		existing_count += 1

	if existing_count > 0:
		_log("  → Отправлен список %d существующих игроков" % existing_count)

	# Добавляем в PlayerManager
	_pm.add_player(id, pos, rot)

	# Рассылаем PLAYER_JOINED всем остальным
	_net.broadcast_except(id, PacketTypes.write_player_joined(id, pos, rot))

	_log("✓ Игрок %d заспавнен в %s (онлайн: %d)" % [id, pos, _pm.get_all_ids().size()])


func _on_peer_disconnected(id: int) -> void:
	_pm.remove_player(id)
	_net.broadcast(PacketTypes.write_player_left(id))
	_log("✗ Игрок %d отключился (онлайн: %d)" % [id, _pm.get_all_ids().size()])


func _on_ping(peer_id: int, _body: StreamPeerBuffer) -> void:
	_net.send_to_peer(peer_id, PacketTypes.write_pong())


func _on_player_move(peer_id: int, data: Dictionary) -> void:
	# Обновляем позицию в PlayerManager
	var pos: Vector3 = data["position"]
	var rot := Vector3(data["head_pitch"], data["body_yaw"], 0.0)
	_pm.update_player(peer_id, pos, rot)

	if _debug and _packets_received % 60 == 0:
		_log("  player_move от %d: pos=%s" % [peer_id, pos])

	# NAM автоматически пересылает остальным клиентам!
	# Это происходит в _handle_server при sync_mode = 3


func _shutdown_graceful() -> void:
	_log("Завершение работы...")
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
