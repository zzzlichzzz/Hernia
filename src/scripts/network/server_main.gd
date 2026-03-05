extends Node

const PORT        := 9999
const MAX_CLIENTS := 32
const SPAWN_Y     := 2.0

var _net : NetworkManager
var _pm  : PlayerManager
var _nam : NetworkActionManager


func _ready() -> void:
	get_tree().auto_accept_quit = false

	print("═══════════════════════════════════════")
	print("[server] Запуск сервера на порту %d" % PORT)
	print("[server] Макс. клиентов: %d" % MAX_CLIENTS)
	print("═══════════════════════════════════════")

	# ── Сеть ──────────────────────────────────────
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

	# ── Базовые обработчики ───────────────────────
	_net.register_handler(PacketTypes.PING, _on_ping)

	# ── NAM ───────────────────────────────────────
	_nam.setup(_net)
	_nam.on_action("player_move", _on_player_move)
	_nam.on_validate("player_move", _validate_player_move)

	# ── Старт ─────────────────────────────────────
	var err := _net.create_server(PORT, MAX_CLIENTS)
	if err != OK:
		push_error("[server] Не удалось создать сервер! Error: %d" % err)
		get_tree().quit(1)
		return

	_log("✓ Сервер запущен, ожидание подключений...")


# ══════════════════════════════════════════════════
#  ПОДКЛЮЧЕНИЕ / ОТКЛЮЧЕНИЕ
# ══════════════════════════════════════════════════

func _on_peer_connected(id: int) -> void:
	var pos := Vector3(randf_range(-5.0, 5.0), SPAWN_Y, randf_range(-5.0, 5.0))
	var rot := Vector3.ZERO

	_log("→ Игрок %d подключается..." % id)

	# WELCOME новому игроку
	_net.send_to_peer(id, PacketTypes.write_welcome(id, pos, rot))

	# Список существующих игроков
	for eid: int in _pm.get_all_ids():
		var d: Dictionary = _pm.get_player_data(eid)
		_net.send_to_peer(id, PacketTypes.write_player_joined(
			eid, d["position"], d["rotation"]))

	# Добавляем в PlayerManager
	_pm.add_player(id, pos, rot)

	# Рассылаем PLAYER_JOINED всем остальным
	_net.broadcast_except(id, PacketTypes.write_player_joined(id, pos, rot))

	_log("✓ Игрок %d заспавнен в %s (онлайн: %d)" % [id, pos, _pm.get_all_ids().size()])


func _on_peer_disconnected(id: int) -> void:
	_pm.remove_player(id)
	_net.broadcast(PacketTypes.write_player_left(id))
	_log("✗ Игрок %d отключился (онлайн: %d)" % [id, _pm.get_all_ids().size()])


# ══════════════════════════════════════════════════
#  ХАРДКОД-ПАКЕТЫ
# ══════════════════════════════════════════════════

func _on_ping(peer_id: int, _body: StreamPeerBuffer) -> void:
	_net.send_to_peer(peer_id, PacketTypes.write_pong())


# ══════════════════════════════════════════════════
#  ГЕНЕРИРУЕМЫЕ ПАКЕТЫ (через NAM)
# ══════════════════════════════════════════════════

## Валидация player_move — вызывается ДО обработчика и маршрутизации.
## data["peer_id"] уже перезаписан NAM на реальный ID отправителя.
func _validate_player_move(peer_id: int, data: Dictionary) -> bool:
	# Игрок должен существовать
	if not _pm.has_player(peer_id):
		_log("✗ player_move от несуществующего игрока %d" % peer_id)
		return false

	# Защита от телепортации: максимум 50 единиц за один тик
	var old_data := _pm.get_player_data(peer_id)
	var old_pos: Vector3 = old_data["position"]
	var new_pos: Vector3 = data["position"]
	if old_pos.distance_to(new_pos) > 50.0:
		_log("✗ Игрок %d: подозрительное перемещение %.1f м" % [
			peer_id, old_pos.distance_to(new_pos)])
		return false

	return true


## Обработчик player_move — вызывается ПОСЛЕ валидации.
## NAM автоматически пересылает остальным клиентам (sync_mode=3).
func _on_player_move(peer_id: int, data: Dictionary) -> void:
	var pos: Vector3 = data["position"]
	var rot := Vector3(data["head_pitch"], data["body_yaw"], 0.0)
	_pm.update_player(peer_id, pos, rot)


# ══════════════════════════════════════════════════
#  ЗАВЕРШЕНИЕ
# ══════════════════════════════════════════════════

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
