class_name NetworkActionManager
extends Node
## Маршрутизация пакетов из GeneratedPackets.
##
## БЕЗОПАСНОСТЬ: поле "peer_id" в теле пакета автоматически
## перезаписывается на реальный ID отправителя на сервере.
## Это предотвращает подделку peer_id злоумышленником.

signal packet_sent(action_name: String)
signal packet_received(action_name: String, peer_id: int, data: Dictionary)

var _net: NetworkManager
var _handlers: Dictionary = {}      # pid → Callable
var _validators: Dictionary = {}    # pid → Callable
var _gp: RefCounted                 # экземпляр GeneratedPackets для callv
var _name_to_id: Dictionary = {}    # action_name → pid
var _debug: bool = false


func setup(net: NetworkManager, debug: bool = false) -> void:
	_net = net
	_debug = debug
	_gp = GeneratedPackets.new()

	for pid: int in GeneratedPackets.PACKETS:
		_net.register_handler(pid, _on_packet.bind(pid))
		var meta: Dictionary = GeneratedPackets.PACKETS[pid]
		_name_to_id[meta["name"]] = pid

	if _debug:
		print("[NAM] Зарегистрировано пакетов: %d" % GeneratedPackets.PACKETS.size())
		for pid: int in GeneratedPackets.PACKETS:
			var m: Dictionary = GeneratedPackets.PACKETS[pid]
			print("[NAM]   '%s' id=%d sync=%d ch=%d fields=%s" % [
				m["name"], pid, m["sync_mode"], m["channel"],
				str(m.get("field_names", []))])


func set_debug(enabled: bool) -> void:
	_debug = enabled


# ══════════════════════════════════════════════════
#  ПОДПИСКИ И ВАЛИДАТОРЫ
# ══════════════════════════════════════════════════

## Подписаться на получение действия.
## handler: func(peer_id: int, data: Dictionary) -> void
func on_action(action_name: String, handler: Callable) -> void:
	var pid := _find_id(action_name)
	if pid == -1:
		push_error("[NAM] on_action: неизвестное действие '%s'. Доступные: %s" % [
			action_name, str(_name_to_id.keys())])
		return
	_handlers[pid] = handler


## Установить валидатор на сервере.
## validator: func(peer_id: int, data: Dictionary) -> bool
func on_validate(action_name: String, validator: Callable) -> void:
	var pid := _find_id(action_name)
	if pid == -1:
		push_error("[NAM] on_validate: неизвестное действие '%s'" % action_name)
		return
	_validators[pid] = validator


# ══════════════════════════════════════════════════
#  ОТПРАВКА — КЛИЕНТ → СЕРВЕР
# ══════════════════════════════════════════════════

## Отправить действие. Клиент шлёт серверу, сервер — по sync_mode.
func send_action(action_name: String, args: Array) -> void:
	var pid := _find_id(action_name)
	if pid == -1:
		push_error("[NAM] send_action: неизвестное действие '%s'" % action_name)
		return

	var meta: Dictionary = GeneratedPackets.PACKETS[pid]
	var write_fn := "write_%s" % action_name
	var pkt: PackedByteArray = _gp.callv(write_fn, args)
	var flags := _channel_flags(meta["channel"])

	if _net.is_server():
		# Сервер: отправляем по sync_mode
		var sync_mode: int = meta["sync_mode"]
		match sync_mode:
			1:  # SERVER_TO_ALL
				_net.broadcast(pkt, 0, flags)
			2:  # SERVER_TO_OTHERS
				_net.broadcast(pkt, 0, flags)
			_:
				push_warning("[NAM] Сервер вызвал send_action для '%s' (sync=%d). " % [action_name, sync_mode]
					+ "Для отправки конкретному пиру используйте send_action_to()")
	else:
		# Клиент: всегда шлём серверу
		_net.send_to_server(pkt, 0, flags)

	if _debug:
		print("[NAM] → '%s' (%d байт)" % [action_name, pkt.size()])
	packet_sent.emit(action_name)


## Сервер отправляет действие конкретному пиру (SERVER_TO_OWNER и т.д.)
func send_action_to(peer_id: int, action_name: String, args: Array) -> void:
	if not _net.is_server():
		push_error("[NAM] send_action_to: только для сервера")
		return

	var pid := _find_id(action_name)
	if pid == -1:
		push_error("[NAM] send_action_to: неизвестное действие '%s'" % action_name)
		return

	var meta: Dictionary = GeneratedPackets.PACKETS[pid]
	var write_fn := "write_%s" % action_name
	var pkt: PackedByteArray = _gp.callv(write_fn, args)
	var flags := _channel_flags(meta["channel"])

	_net.send_to_peer(peer_id, pkt, 0, flags)

	if _debug:
		print("[NAM] → '%s' → peer %d (%d байт)" % [action_name, peer_id, pkt.size()])
	packet_sent.emit(action_name)


# ══════════════════════════════════════════════════
#  ПОЛУЧЕНИЕ ПАКЕТОВ
# ══════════════════════════════════════════════════

func _on_packet(peer_id: int, body: StreamPeerBuffer, pid: int) -> void:
	if pid not in GeneratedPackets.PACKETS:
		push_warning("[NAM] Неизвестный пакет id=%d" % pid)
		return

	var meta: Dictionary = GeneratedPackets.PACKETS[pid]
	var action_name: String = meta["name"]
	var read_fn := "read_%s" % action_name

	var data: Dictionary = _gp.call(read_fn, body)

	if _debug:
		print("[NAM] ← '%s' от peer=%d" % [action_name, peer_id])

	packet_received.emit(action_name, peer_id, data)

	if _net.is_server():
		_handle_server(pid, peer_id, data, meta)
	else:
		_handle_client(pid, peer_id, data)


func _handle_server(pid: int, peer_id: int, data: Dictionary, meta: Dictionary) -> void:
	# ── Безопасность: перезаписать peer_id реальным ID отправителя ──
	# Если в теле пакета есть поле "peer_id", клиент мог подделать его.
	# Сервер ВСЕГДА заменяет на проверенный ENet peer_id.
	if "peer_id" in data:
		data["peer_id"] = peer_id

	# ── Валидация ─────────────────────────────────
	if meta["server_validates"] and pid in _validators:
		var valid: bool = (_validators[pid] as Callable).call(peer_id, data)
		if not valid:
			if _debug:
				print("[NAM|SRV] ✗ '%s' от %d отклонён валидатором" % [meta["name"], peer_id])
			return

	# ── Локальный обработчик ──────────────────────
	if pid in _handlers:
		(_handlers[pid] as Callable).call(peer_id, data)

	# ── Маршрутизация ─────────────────────────────
	var sync_mode: int = meta["sync_mode"]
	if sync_mode == 0:   # CLIENT_TO_SERVER — не пересылаем
		return

	# Ресериализация с гарантированным порядком полей
	var action_name: String = meta["name"]
	var write_fn := "write_%s" % action_name
	var field_names: Array = meta.get("field_names", [])
	var values := []
	for fname in field_names:
		values.append(data[fname])

	var pkt: PackedByteArray = _gp.callv(write_fn, values)
	var flags := _channel_flags(meta["channel"])

	match sync_mode:
		1:  # SERVER_TO_ALL
			_net.broadcast(pkt, 0, flags)
		2:  # SERVER_TO_OTHERS
			_net.broadcast_except(peer_id, pkt, 0, flags)
		3:  # CLIENT_TO_ALL_VIA_SERVER
			_net.broadcast_except(peer_id, pkt, 0, flags)
		4:  # SERVER_TO_OWNER
			_net.send_to_peer(peer_id, pkt, 0, flags)

	if _debug:
		print("[NAM|SRV] ↗ '%s' sync=%d peers=%d" % [
			action_name, sync_mode, _net.get_peer_ids().size()])


func _handle_client(pid: int, peer_id: int, data: Dictionary) -> void:
	if pid in _handlers:
		(_handlers[pid] as Callable).call(peer_id, data)


# ══════════════════════════════════════════════════
#  УТИЛИТЫ
# ══════════════════════════════════════════════════

func _find_id(action_name: String) -> int:
	if action_name in _name_to_id:
		return _name_to_id[action_name]
	# Фолбэк: поиск в PACKETS (если вызвано до setup)
	for pid: int in GeneratedPackets.PACKETS:
		if (GeneratedPackets.PACKETS[pid] as Dictionary)["name"] == action_name:
			_name_to_id[action_name] = pid
			return pid
	return -1


func _channel_flags(channel: int) -> int:
	if channel == 0:
		return ENetPacketPeer.FLAG_RELIABLE
	return ENetPacketPeer.FLAG_UNSEQUENCED
