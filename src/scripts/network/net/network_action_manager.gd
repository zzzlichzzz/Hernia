class_name NetworkActionManager
extends Node
## Автоматическая маршрутизация пакетов из GeneratedPackets.

var _net: NetworkManager
var _handlers: Dictionary = {}
var _validators: Dictionary = {}
var _gp: GeneratedPackets          # ← экземпляр для callv/call


func setup(net: NetworkManager) -> void:
	_net = net
	_gp = GeneratedPackets.new()
	for pid: int in GeneratedPackets.PACKETS:
		_net.register_handler(pid, _on_packet.bind(pid))


## Подписаться на получение действия.
## handler: func(peer_id: int, data: Dictionary) -> void
func on_action(action_name: String, handler: Callable) -> void:
	var pid := _find_id(action_name)
	if pid == -1:
		push_error("[NAM] Неизвестное действие: '%s'" % action_name)
		return
	_handlers[pid] = handler


## Установить валидатор на сервере.
## validator: func(peer_id: int, data: Dictionary) -> bool
func on_validate(action_name: String, validator: Callable) -> void:
	var pid := _find_id(action_name)
	if pid == -1:
		push_error("[NAM] Неизвестное действие: '%s'" % action_name)
		return
	_validators[pid] = validator


## Отправить действие серверу.
func send_action(action_name: String, args: Array) -> void:
	var pid := _find_id(action_name)
	if pid == -1:
		push_error("[NAM] Неизвестное действие: '%s'" % action_name)
		return
	var meta: Dictionary = GeneratedPackets.PACKETS[pid]
	var write_fn := "write_%s" % action_name
	var pkt: PackedByteArray = _gp.callv(write_fn, args)
	var flags := ENetPacketPeer.FLAG_RELIABLE if meta["channel"] == 0 \
		else ENetPacketPeer.FLAG_UNSEQUENCED
	_net.send_to_server(pkt, 0, flags)


# ══════════════════════════════════════════════════
#  ВНУТРЕННЯЯ ОБРАБОТКА
# ══════════════════════════════════════════════════

func _on_packet(peer_id: int, body: StreamPeerBuffer, pid: int) -> void:
	var meta: Dictionary = GeneratedPackets.PACKETS[pid]
	var action_name: String = meta["name"]
	var read_fn := "read_%s" % action_name
	var data: Dictionary = _gp.call(read_fn, body)

	if _net.is_server():
		_handle_server(pid, peer_id, data, meta)
	else:
		_handle_client(pid, peer_id, data)


func _handle_server(pid: int, peer_id: int, data: Dictionary, meta: Dictionary) -> void:
	# Валидация
	if meta["server_validates"] and pid in _validators:
		var valid: bool = (_validators[pid] as Callable).call(peer_id, data)
		if not valid:
			return

	# Локальный обработчик на сервере
	if pid in _handlers:
		(_handlers[pid] as Callable).call(peer_id, data)

	# Маршрутизация
	var sync_mode: int = meta["sync_mode"]
	var action_name: String = meta["name"]
	var write_fn := "write_%s" % action_name
	var values := data.values()
	var pkt: PackedByteArray = _gp.callv(write_fn, values)
	var flags := ENetPacketPeer.FLAG_RELIABLE if meta["channel"] == 0 \
		else ENetPacketPeer.FLAG_UNSEQUENCED

	match sync_mode:
		0:  pass                                                    # CLIENT_TO_SERVER
		1:  _net.broadcast(pkt, 0, flags)                           # SERVER_TO_ALL
		2:  _net.broadcast_except(peer_id, pkt, 0, flags)          # SERVER_TO_OTHERS
		3:  _net.broadcast_except(peer_id, pkt, 0, flags)          # CLIENT_TO_ALL_VIA_SERVER
		4:  _net.send_to_peer(peer_id, pkt, 0, flags)              # SERVER_TO_OWNER


func _handle_client(pid: int, _peer_id: int, data: Dictionary) -> void:
	if pid in _handlers:
		(_handlers[pid] as Callable).call(_peer_id, data)


func _find_id(action_name: String) -> int:
	for pid: int in GeneratedPackets.PACKETS:
		if (GeneratedPackets.PACKETS[pid] as Dictionary)["name"] == action_name:
			return pid
	return -1
