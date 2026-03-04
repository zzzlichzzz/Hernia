extends Node

const PORT      := 9999
const SPAWN_Y   := 1.0

var _net: NetworkManager
var _pm : PlayerManager


func _ready() -> void:
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

	var err := _net.create_server(PORT)
	if err != OK:
		get_tree().quit(1)


# ── Подключение ──────────────────────────────────

func _on_peer_connected(id: int) -> void:
	# Случайная точка спавна
	var pos := Vector3(randf_range(-5.0, 5.0), SPAWN_Y, randf_range(-5.0, 5.0))
	var rot := Vector3.ZERO

	# 1) WELCOME новому клиенту — его id + спавн
	_net.send_to_peer(id, PacketTypes.write_welcome(id, pos, rot))

	# 2) Отправить новичку всех уже подключённых
	for eid: int in _pm.get_all_ids():
		var d: Dictionary = _pm.get_player_data(eid)
		_net.send_to_peer(id, PacketTypes.write_player_joined(eid, d["position"], d["rotation"]))

	# 3) Добавить нового в менеджер
	_pm.add_player(id, pos, rot)

	# 4) Сообщить остальным о новичке
	_net.broadcast_except(id, PacketTypes.write_player_joined(id, pos, rot))

	print("[server] Игрок %d заспавнен в %s" % [id, pos])


# ── Отключение ───────────────────────────────────

func _on_peer_disconnected(id: int) -> void:
	_pm.remove_player(id)
	_net.broadcast(PacketTypes.write_player_left(id))
	print("[server] Игрок %d вышел" % id)


# ── Обработчики пакетов ──────────────────────────

func _on_ping(peer_id: int, _body: StreamPeerBuffer) -> void:
	_net.send_to_peer(peer_id, PacketTypes.write_pong())


func _on_player_update(peer_id: int, body: StreamPeerBuffer) -> void:
	var data := PacketTypes.read_player_update(body)
	# Берём peer_id из соединения, НЕ из тела пакета (защита от спуфинга)
	var pos: Vector3 = data["position"]
	var rot: Vector3 = data["rotation"]

	_pm.update_player(peer_id, pos, rot)

	# Пересылаем остальным (unreliable)
	var pkt := PacketTypes.write_player_update(peer_id, pos, rot)
	_net.broadcast_except(peer_id, pkt, 0, ENetPacketPeer.FLAG_UNSEQUENCED)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_net.shutdown()
		get_tree().quit()
