extends Node

## ─── Сигналы сервера ───
signal on_peer_connected(peer_id: int)
signal on_peer_disconnected(peer_id: int)
signal on_server_packet(peer_id: int, data: PackedByteArray)

## ─── Сигналы клиента ───
signal on_connected_to_server()
signal on_disconnected_from_server()
signal on_client_packet(data: PackedByteArray)

## ─── Переменные ───
var available_peer_ids: Array = range(255, -1, -1)
var client_peers: Dictionary[int, ENetPacketPeer]
var server_peer: ENetPacketPeer
var connection: ENetConnection
var is_server: bool = false

func _process(_delta: float) -> void:
	if connection == null:
		return
	_handle_events()

func _handle_events() -> void:
	var packet_event: Array = connection.service()
	var event_type: ENetConnection.EventType = packet_event[0]

	while event_type != ENetConnection.EVENT_NONE:
		var peer: ENetPacketPeer = packet_event[1]

		match event_type:
			ENetConnection.EVENT_ERROR:
				push_warning("ENet: unknown error!")
				return
			ENetConnection.EVENT_CONNECT:
				if is_server:
					_peer_connected(peer)
				else:
					_connected_to_server()
			ENetConnection.EVENT_DISCONNECT:
				if is_server:
					_peer_disconnected(peer)
				else:
					_disconnected_from_server()
					return
			ENetConnection.EVENT_RECEIVE:
				if is_server:
					on_server_packet.emit(peer.get_meta("id"), peer.get_packet())
				else:
					on_client_packet.emit(peer.get_packet())

		packet_event = connection.service()
		event_type = packet_event[0]

# ─── Серверные методы ───

func start_server(ip: String = "127.0.0.1", port: int = 42069) -> bool:
	connection = ENetConnection.new()
	var error := connection.create_host_bound(ip, port)
	if error:
		push_error("Server start failed: ", error_string(error))
		connection = null
		return false
	print("Server started on %s:%d" % [ip, port])
	is_server = true
	return true

func _peer_connected(peer: ENetPacketPeer) -> void:
	var peer_id: int = available_peer_ids.pop_back()
	peer.set_meta("id", peer_id)
	client_peers[peer_id] = peer
	print("Peer connected: ", peer_id)
	on_peer_connected.emit(peer_id)

func _peer_disconnected(peer: ENetPacketPeer) -> void:
	var peer_id: int = peer.get_meta("id")
	available_peer_ids.push_back(peer_id)
	client_peers.erase(peer_id)
	print("Peer disconnected: ", peer_id)
	on_peer_disconnected.emit(peer_id)

# ─── Клиентские методы ───

func start_client(ip: String = "127.0.0.1", port: int = 42069) -> bool:
	connection = ENetConnection.new()
	var error := connection.create_host(1)
	if error:
		push_error("Client start failed: ", error_string(error))
		connection = null
		return false
	print("Client started, connecting to %s:%d" % [ip, port])
	server_peer = connection.connect_to_host(ip, port)
	return true

func disconnect_client() -> void:
	if is_server:
		return
	server_peer.peer_disconnect()

func _connected_to_server() -> void:
	print("Connected to server!")
	on_connected_to_server.emit()

func _disconnected_from_server() -> void:
	print("Disconnected from server!")
	on_disconnected_from_server.emit()
	connection = null
