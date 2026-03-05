extends Node
## Выделенный сервер.
## Поддерживает headless-режим и аргументы командной строки.
##
## Запуск:
##   godot --headless -- --port 8080 --max-clients 16 --verbose
##
## Аргументы (все необязательные):
##   --port <число>          Порт (по умолчанию 9999)
##   --max-clients <число>   Макс. клиентов (по умолчанию 32)
##   --verbose               Подробный лог
##   --spawn-y <число>       Высота спавна (по умолчанию 2.0)

var _net      : NetworkManager
var _pm       : PlayerManager
var _args     : CmdArgs
var _is_headless : bool = false

# Конфигурация (заполняется из CLI или дефолтов)
var _port        : int   = 9999
var _max_clients : int   = 32
var _spawn_y     : float = 2.0
var _verbose     : bool  = false


func _ready() -> void:
	# ── Разбор аргументов ─────────────────────────
	_args = CmdArgs.new()
	_is_headless = CmdArgs.is_headless()

	_port        = _args.get_int("--port", _port)
	_max_clients = _args.get_int("--max-clients", _max_clients)
	_spawn_y     = _args.get_float("--spawn-y", _spawn_y)
	_verbose     = _args.has_flag("--verbose")

	if _verbose:
		_args.print_all()

	_log("Режим: %s" % ("headless" if _is_headless else "windowed"))
	_log("Порт: %d | Макс. клиентов: %d | Spawn Y: %.1f" % [_port, _max_clients, _spawn_y])

	# ── Отключаем автозакрытие чтобы обработать Ctrl+C ──
	get_tree().auto_accept_quit = false

	# ── Сеть ──────────────────────────────────────
	_net = NetworkManager.new()
	_net.name = "NetworkManager"
	add_child(_net)

	_pm = PlayerManager.new()
	_pm.name = "PlayerManager"
	add_child(_pm)

	_net.peer_connected.connect(_on_peer_connected)
	_net.peer_disconnected.connect(_on_peer_disconnected)

	_net.register_handler(PacketTypes.PING,          _on_ping)
	_net.register_handler(PacketTypes.PLAYER_UPDATE, _on_player_update)

	var err := _net.create_server(_port, _max_clients)
	if err != OK:
		push_error("Не удалось запустить сервер на порту %d!" % _port)
		get_tree().quit(1)
		return

	_log("Сервер запущен. Ожидание подключений…")


# ══════════════════════════════════════════════════
#  ПОДКЛЮЧЕНИЕ / ОТКЛЮЧЕНИЕ
# ══════════════════════════════════════════════════

func _on_peer_connected(id: int) -> void:
	var pos := Vector3(randf_range(-5.0, 5.0), _spawn_y, randf_range(-5.0, 5.0))
	var rot := Vector3.ZERO

	# WELCOME новичку
	_net.send_to_peer(id, PacketTypes.write_welcome(id, pos, rot))

	# Отправить новичку всех существующих
	for eid: int in _pm.get_all_ids():
		var d: Dictionary = _pm.get_player_data(eid)
		_net.send_to_peer(id, PacketTypes.write_player_joined(
			eid, d["position"], d["rotation"]))

	# Добавить в менеджер
	_pm.add_player(id, pos, rot)

	# Уведомить остальных
	_net.broadcast_except(id, PacketTypes.write_player_joined(id, pos, rot))

	_log("Игрок %d заспавнен в %s (онлайн: %d)" % [id, pos, _pm.get_all_ids().size()])


func _on_peer_disconnected(id: int) -> void:
	_pm.remove_player(id)
	_net.broadcast(PacketTypes.write_player_left(id))
	_log("Игрок %d вышел (онлайн: %d)" % [id, _pm.get_all_ids().size()])


# ══════════════════════════════════════════════════
#  ОБРАБОТЧИКИ ПАКЕТОВ
# ══════════════════════════════════════════════════

func _on_ping(peer_id: int, _body: StreamPeerBuffer) -> void:
	_net.send_to_peer(peer_id, PacketTypes.write_pong())
	if _verbose:
		_log("PING от id=%d → PONG" % peer_id)


func _on_player_update(peer_id: int, body: StreamPeerBuffer) -> void:
	var data := PacketTypes.read_player_update(body)
	var pos: Vector3 = data["position"]
	var rot: Vector3 = data["rotation"]
	_pm.update_player(peer_id, pos, rot)
	var pkt := PacketTypes.write_player_update(peer_id, pos, rot)
	_net.broadcast_except(peer_id, pkt, 0, ENetPacketPeer.FLAG_UNSEQUENCED)


# ══════════════════════════════════════════════════
#  ЗАВЕРШЕНИЕ (Ctrl+C, закрытие окна)
# ══════════════════════════════════════════════════

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST:
			_shutdown_graceful()
		NOTIFICATION_CRASH:
			_log("CRASH — аварийное завершение")
			_net.shutdown()


func _shutdown_graceful() -> void:
	_log("Завершение работы…")

	# Уведомить всех клиентов
	for id: int in _pm.get_all_ids():
		_net.send_to_peer(id, PacketTypes.write_player_left(id))

	# Подождать чтобы пакеты ушли
	if _net._host != null:
		_net._host.flush()

	_net.shutdown()
	_log("Сервер остановлен")
	get_tree().quit(0)


# ══════════════════════════════════════════════════
#  ЛОГИРОВАНИЕ
# ══════════════════════════════════════════════════

func _log(msg: String) -> void:
	var time_str := Time.get_time_string_from_system()
	print("[%s][server] %s" % [time_str, msg])
