class_name NetworkManager
extends Node
## Обёртка ENetConnection + диспетчер + таймауты + фрагменты.

signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)

enum Mode { NONE, SERVER, CLIENT }
const SERVER_ID := 1

const MAX_CONNECTIONS_PER_IP := 3  # Максимум игроков с одного пира
const TIMEOUT_LIMIT   := 5
const TIMEOUT_MIN_MS  := 1000
const TIMEOUT_MAX_MS  := 5000
const HEARTBEAT_TIMEOUT := 10.0
const FRAGMENT_CLEANUP_INTERVAL := 5.0   # секунд между очистками

var _host       : ENetConnection   = null
var _mode       : Mode             = Mode.NONE
var _my_id      : int              = 0

var _ip_count   : Dictionary = {}         # ip_string → int
var _peer_ip    : Dictionary = {}         # peer_id → ip_string
var _peers      : Dictionary       = {}
var _next_id    : int              = 2

var _server_peer: ENetPacketPeer   = null

var _handlers   : Dictionary       = {}

var _last_seen  : Dictionary       = {}
var _server_last_seen : float      = 0.0

# ── Сборщик фрагментов ───────────────────────────
var _assembler := PacketTypes.FragmentAssembler.new()
var _fragment_cleanup_timer : float = 0.0



# ══════════════════════════════════════════════════
#  ОБРАБОТЧИКИ
# ══════════════════════════════════════════════════

func register_handler(msg_type: int, handler: Callable) -> void:
	_handlers[msg_type] = handler

func unregister_handler(msg_type: int) -> void:
	_handlers.erase(msg_type)


# ══════════════════════════════════════════════════
#  ОТПРАВКА
# ══════════════════════════════════════════════════

func send_to_peer(peer_id: int, packet: PackedByteArray,
		channel: int = 0, flags: int = ENetPacketPeer.FLAG_RELIABLE) -> Error:
	if _mode != Mode.SERVER:
		push_error("send_to_peer: не сервер"); return ERR_UNCONFIGURED
	if peer_id not in _peers:
		push_warning("send_to_peer: нет peer_id=%d" % peer_id); return ERR_DOES_NOT_EXIST
	return (_peers[peer_id] as ENetPacketPeer).send(channel, packet, flags)


func broadcast(packet: PackedByteArray,
		channel: int = 0, flags: int = ENetPacketPeer.FLAG_RELIABLE) -> void:
	for id: int in _peers:
		(_peers[id] as ENetPacketPeer).send(channel, packet, flags)


func broadcast_except(exclude_id: int, packet: PackedByteArray,
		channel: int = 0, flags: int = ENetPacketPeer.FLAG_RELIABLE) -> void:
	for id: int in _peers:
		if id != exclude_id:
			(_peers[id] as ENetPacketPeer).send(channel, packet, flags)


func send_to_server(packet: PackedByteArray,
		channel: int = 0, flags: int = ENetPacketPeer.FLAG_RELIABLE) -> Error:
	if _mode != Mode.CLIENT or _server_peer == null:
		push_error("send_to_server: нет соединения"); return ERR_UNCONFIGURED
	return _server_peer.send(channel, packet, flags)


## Отправить большой пакет с автофрагментацией.
## body — чистое тело (без заголовка).
func send_fragmented_to_peer(peer_id: int, type: int, body: PackedByteArray,
		channel: int = 0, flags: int = ENetPacketPeer.FLAG_RELIABLE) -> Error:
	var fragments := PacketTypes.fragment_packet(type, body)
	var err := OK
	for frag: PackedByteArray in fragments:
		var e := send_to_peer(peer_id, frag, channel, flags)
		if e != OK:
			err = e
	return err


## Отправить большой пакет серверу с автофрагментацией.
func send_fragmented_to_server(type: int, body: PackedByteArray,
		channel: int = 0, flags: int = ENetPacketPeer.FLAG_RELIABLE) -> Error:
	var fragments := PacketTypes.fragment_packet(type, body)
	var err := OK
	for frag: PackedByteArray in fragments:
		var e := send_to_server(frag, channel, flags)
		if e != OK:
			err = e
	return err


## Разослать большой пакет всем с автофрагментацией.
func broadcast_fragmented(type: int, body: PackedByteArray,
		channel: int = 0, flags: int = ENetPacketPeer.FLAG_RELIABLE) -> void:
	var fragments := PacketTypes.fragment_packet(type, body)
	for frag: PackedByteArray in fragments:
		broadcast(frag, channel, flags)


## Разослать большой пакет всем кроме одного с автофрагментацией.
func broadcast_fragmented_except(exclude_id: int, type: int, body: PackedByteArray,
		channel: int = 0, flags: int = ENetPacketPeer.FLAG_RELIABLE) -> void:
	var fragments := PacketTypes.fragment_packet(type, body)
	for frag: PackedByteArray in fragments:
		broadcast_except(exclude_id, frag, channel, flags)


# ══════════════════════════════════════════════════
#  СОЗДАНИЕ / ЗАКРЫТИЕ
# ══════════════════════════════════════════════════

func create_server(port: int, max_clients: int = 32) -> Error:
	_host = ENetConnection.new()
	var err := _host.create_host_bound("*", port, max_clients)
	if err != OK:
		push_error("Сервер: %s" % error_string(err)); _host = null; return err
	_mode  = Mode.SERVER
	_my_id = SERVER_ID
	print("[net] Сервер слушает порт %d" % port)
	return OK


func create_client(address: String, port: int) -> Error:
	_host = ENetConnection.new()
	var err := _host.create_host(1)
	if err != OK:
		push_error("Клиент: %s" % error_string(err)); _host = null; return err
	_server_peer = _host.connect_to_host(address, port)
	if _server_peer == null:
		_host.destroy(); _host = null; return ERR_CANT_CONNECT
	_mode = Mode.CLIENT
	_server_last_seen = Time.get_unix_time_from_system()
	print("[net] Подключение к %s:%d …" % [address, port])
	return OK


func disconnect_from_server() -> void:
	if _mode == Mode.CLIENT and _server_peer:
		_server_peer.peer_disconnect(0)


func kick_peer(peer_id: int) -> void:
	if peer_id in _peers:
		(_peers[peer_id] as ENetPacketPeer).peer_disconnect(0)


func shutdown() -> void:
	if _host == null:
		return
	match _mode:
		Mode.SERVER:
			for id: int in _peers:
				(_peers[id] as ENetPacketPeer).peer_disconnect_now(0)
			_peers.clear(); _last_seen.clear(); _next_id = 2
		Mode.CLIENT:
			if _server_peer:
				_server_peer.peer_disconnect_now(0)
				_server_peer = null
	_assembler.clear()
	_host.destroy(); _host = null
	_mode = Mode.NONE; _my_id = 0
	print("[net] Хост закрыт")


func is_server() -> bool:  return _mode == Mode.SERVER
func get_my_id() -> int:   return _my_id
func set_my_id(id: int) -> void: _my_id = id

func get_peer_ids() -> Array:
	return _peers.keys()

func get_peer_idle_time(peer_id: int) -> float:
	if peer_id not in _last_seen: return 999.0
	return Time.get_unix_time_from_system() - _last_seen[peer_id]

func get_server_idle_time() -> float:
	if _mode != Mode.CLIENT: return 0.0
	return Time.get_unix_time_from_system() - _server_last_seen


func _apply_timeout(peer: ENetPacketPeer) -> void:
	peer.set_timeout(TIMEOUT_LIMIT, TIMEOUT_MIN_MS, TIMEOUT_MAX_MS)


# ══════════════════════════════════════════════════
#  ЦИКЛ
# ══════════════════════════════════════════════════

func poll() -> void:
	if _host == null:
		return
	while true:
		var ev := _host.service(0)
		var event_type: int = ev[0]
		if event_type == ENetConnection.EVENT_NONE:
			break
		var peer: ENetPacketPeer = ev[1]
		match event_type:
			ENetConnection.EVENT_CONNECT:    _on_enet_connect(peer)
			ENetConnection.EVENT_DISCONNECT: _on_enet_disconnect(peer)
			ENetConnection.EVENT_RECEIVE:    _on_enet_receive(peer)


func _process(delta: float) -> void:
	poll()

	# Серверный heartbeat
	if _mode == Mode.SERVER:
		_check_heartbeats()

	# Очистка устаревших фрагментов
	_fragment_cleanup_timer += delta
	if _fragment_cleanup_timer >= FRAGMENT_CLEANUP_INTERVAL:
		_fragment_cleanup_timer = 0.0
		_assembler.cleanup()


func _exit_tree() -> void:
	shutdown()


# ══════════════════════════════════════════════════
#  HEARTBEAT
# ══════════════════════════════════════════════════

func _check_heartbeats() -> void:
	var now := Time.get_unix_time_from_system()
	var to_kick: Array[int] = []
	for id: int in _last_seen:
		if now - _last_seen[id] > HEARTBEAT_TIMEOUT:
			print("[net|srv] Heartbeat timeout: id=%d" % id)
			to_kick.append(id)
	for id: int in to_kick:
		kick_peer(id)


# ══════════════════════════════════════════════════
#  ОБРАБОТЧИКИ ENET
# ══════════════════════════════════════════════════

func _on_enet_connect(peer: ENetPacketPeer) -> void:
	_apply_timeout(peer)

	if _mode == Mode.SERVER:
		var ip := peer.get_remote_address()

		# Проверка лимита IP
		var count: int = _ip_count.get(ip, 0)
		if count >= MAX_CONNECTIONS_PER_IP:
			print("[net|srv] ✗ IP %s: лимит подключений (%d)" % [ip, MAX_CONNECTIONS_PER_IP])
			peer.peer_disconnect_now(0)
			return

		var id := _next_id; _next_id += 1
		_peers[id] = peer
		_last_seen[id] = Time.get_unix_time_from_system()
		_peer_ip[id] = ip
		_ip_count[ip] = count + 1

		print("[net|srv] + id=%d ip=%s (с этого IP: %d, онлайн: %d)" % [
			id, ip, count + 1, _peers.size()])
		peer_connected.emit(id)
	else:
		_server_last_seen = Time.get_unix_time_from_system()
		print("[net|cli] Соединение установлено")
		peer_connected.emit(SERVER_ID)


func _on_enet_disconnect(peer: ENetPacketPeer) -> void:
	if _mode == Mode.SERVER:
		var id := _find_id(peer)
		if id == -1: return

		# Уменьшить счётчик IP
		if id in _peer_ip:
			var ip: String = _peer_ip[id]
			var count: int = _ip_count.get(ip, 1)
			if count <= 1:
				_ip_count.erase(ip)
			else:
				_ip_count[ip] = count - 1
			_peer_ip.erase(id)

		_peers.erase(id)
		_last_seen.erase(id)
		print("[net|srv] − id=%d (онлайн: %d)" % [id, _peers.size()])
		peer_disconnected.emit(id)
	else:
		_server_peer = null
		_assembler.clear()
		print("[net|cli] Соединение потеряно")
		peer_disconnected.emit(SERVER_ID)


func _on_enet_receive(peer: ENetPacketPeer) -> void:
	var sender_id: int
	if _mode == Mode.SERVER:
		sender_id = _find_id(peer)
		if sender_id != -1:
			_last_seen[sender_id] = Time.get_unix_time_from_system()
	else:
		sender_id = SERVER_ID
		_server_last_seen = Time.get_unix_time_from_system()

	while peer.get_available_packet_count() > 0:
		var raw := peer.get_packet()
		var parsed := PacketTypes.read_packet(raw)
		var pkt_type: int = parsed["type"]
		if pkt_type == -1:
			push_warning("[net] Битый пакет от id=%d" % sender_id)
			continue

		# ── Фрагментация ─────────────────────────
		if PacketTypes.is_fragment(parsed):
			var assembled = _assembler.add_fragment(
				sender_id,
				pkt_type,
				parsed["fragment_id"],
				parsed["total_fragments"],
				parsed["body"])
			if assembled == null:
				continue                     # ждём остальные фрагменты
			# Собрано! Подменяем body на полное
			parsed["body"] = assembled
			parsed["fragment_id"] = 0
			parsed["total_fragments"] = 0

		# ── Диспетчеризация ──────────────────────
		if pkt_type in _handlers:
			(_handlers[pkt_type] as Callable).call(sender_id, parsed["body"])


func _find_id(peer: ENetPacketPeer) -> int:
	for id: int in _peers:
		if _peers[id] == peer:
			return id
	return -1
