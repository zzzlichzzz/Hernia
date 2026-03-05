class_name NetworkActionManager
extends Node
## Автоматическая маршрутизация пакетов из GeneratedPackets.
## Поддержка tick rate (Гц) для периодических пакетов.

signal packet_sent(action_name: String)
signal packet_received(action_name: String, peer_id: int, data: Dictionary)

var _net: NetworkManager
var _handlers: Dictionary = {}
var _validators: Dictionary = {}
var _gp: GeneratedPackets

# ══════════════════════════════════════════════════
#  TICK RATE SYSTEM
# ══════════════════════════════════════════════════

var _tick_timers: Dictionary = {}       # packet_id → Timer
var _tick_data: Dictionary = {}         # packet_id → { data, dirty }
var _name_to_id: Dictionary = {}        # action_name → packet_id
var _debug: bool = false                # Включить отладку


func setup(net: NetworkManager, debug: bool = false) -> void:
	_net = net
	_debug = debug
	_gp = GeneratedPackets.new()

	print("[NAM] Инициализация NetworkActionManager...")
	print("[NAM] Пакеты в GeneratedPackets: %d" % GeneratedPackets.PACKETS.size())

	for pid: int in GeneratedPackets.PACKETS:
		_net.register_handler(pid, _on_packet.bind(pid))

		var meta: Dictionary = GeneratedPackets.PACKETS[pid]
		_name_to_id[meta["name"]] = pid

		print("[NAM]   Зарегистрирован пакет: '%s' (id=%d, sync_mode=%d, channel=%d)" % [
			meta["name"], pid, meta["sync_mode"], meta["channel"]])

	print("[NAM] Готов к работе!")


## Включить/выключить отладочное логирование
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
		push_error("[NAM] Неизвестное действие: '%s'" % action_name)
		push_error("[NAM] Доступные действия: %s" % str(_name_to_id.keys()))
		return
	_handlers[pid] = handler
	if _debug:
		print("[NAM] Обработчик подписан на '%s' (id=%d)" % [action_name, pid])


## Установить валидатор на сервере.
func on_validate(action_name: String, validator: Callable) -> void:
	var pid := _find_id(action_name)
	if pid == -1:
		push_error("[NAM] Неизвестное действие: '%s'" % action_name)
		return
	_validators[pid] = validator


# ══════════════════════════════════════════════════
#  ОТПРАВКА ПАКЕТОВ
# ══════════════════════════════════════════════════

## Отправить действие серверу НЕМЕДЛЕННО
func send_action(action_name: String, args: Array) -> void:
	var pid := _find_id(action_name)
	if pid == -1:
		push_error("[NAM] send_action: Неизвестное действие: '%s'" % action_name)
		return

	var meta: Dictionary = GeneratedPackets.PACKETS[pid]
	var write_fn := "write_%s" % action_name

	if not _gp.has_method(write_fn):
		push_error("[NAM] Метод '%s' не найден в GeneratedPackets!" % write_fn)
		push_error("[NAM] Возможно, нужно запустить network_packet_builder.tscn")
		return

	var pkt: PackedByteArray = _gp.callv(write_fn, args)
	var flags := ENetPacketPeer.FLAG_RELIABLE if meta["channel"] == 0 \
		else ENetPacketPeer.FLAG_UNSEQUENCED

	var err := _net.send_to_server(pkt, 0, flags)

	if _debug:
		print("[NAM] → Отправлен '%s' (id=%d, размер=%d байт, err=%d)" % [
			action_name, pid, pkt.size(), err])

	packet_sent.emit(action_name)


## Создать таймер для периодической отправки
func _ensure_tick_timer(pid: int, interval: float) -> void:
	if pid in _tick_timers:
		return
	if interval <= 0.0:
		return

	var timer := Timer.new()
	timer.name = "TickTimer_%d" % pid
	timer.wait_time = interval
	timer.autostart = false
	timer.one_shot = false
	timer.timeout.connect(_on_tick_timeout.bind(pid))
	add_child(timer)
	_tick_timers[pid] = timer
	_tick_data[pid] = { "data": {}, "dirty": false }

	print("[NAM] Создан таймер для пакета %d: %.3f сек (%.1f Гц)" % [pid, interval, 1.0/interval])


## Обработчик таймера
func _on_tick_timeout(pid: int) -> void:
	if pid not in _tick_data:
		return

	var entry: Dictionary = _tick_data[pid]
	if not entry["dirty"]:
		return

	var action_name: String = GeneratedPackets.PACKETS[pid]["name"]
	var args: Array = entry["data"].values()

	# Отправляем
	send_action(action_name, args)
	entry["dirty"] = false


## Обновить данные для периодической отправки
func send_action_tick(action_name: String, args: Array, tick_rate_hz: int = 0) -> void:
	var pid := _find_id(action_name)
	if pid == -1:
		push_error("[NAM] send_action_tick: Неизвестное действие: '%s'" % action_name)
		return

	# Если tick_rate_hz > 0 — создаём таймер
	if tick_rate_hz > 0:
		var interval := 1.0 / float(tick_rate_hz)
		_ensure_tick_timer(pid, interval)

	# Сохраняем данные
	if pid not in _tick_data:
		_tick_data[pid] = { "data": {}, "dirty": false }

	_tick_data[pid]["data"] = _args_to_dict(args)
	_tick_data[pid]["dirty"] = true

	# Если таймера нет — отправляем немедленно!
	if pid not in _tick_timers:
		send_action(action_name, args)


## Преобразовать args в словарь
func _args_to_dict(args: Array) -> Dictionary:
	var result := {}
	for i in args.size():
		result[i] = args[i]
	return result


## Запустить все таймеры
func start_tick_timers() -> void:
	for pid: int in _tick_timers:
		var timer: Timer = _tick_timers[pid]
		if timer.is_stopped():
			timer.start()
			print("[NAM] Таймер %d запущен" % pid)


## Остановить все таймеры
func stop_tick_timers() -> void:
	for pid: int in _tick_timers:
		var timer: Timer = _tick_timers[pid]
		timer.stop()


## Установить tick rate
func set_tick_rate(action_name: String, hz: int) -> void:
	var pid := _find_id(action_name)
	if pid == -1:
		return

	if hz <= 0:
		if pid in _tick_timers:
			var timer: Timer = _tick_timers[pid]
			timer.stop()
			timer.queue_free()
			_tick_timers.erase(pid)
		return

	var interval := 1.0 / float(hz)
	_ensure_tick_timer(pid, interval)

	if pid in _tick_timers:
		var timer: Timer = _tick_timers[pid]
		timer.wait_time = interval


# ══════════════════════════════════════════════════
#  ПОЛУЧЕНИЕ ПАКЕТОВ
# ══════════════════════════════════════════════════

func _on_packet(peer_id: int, body: StreamPeerBuffer, pid: int) -> void:
	if pid not in GeneratedPackets.PACKETS:
		push_warning("[NAM] Получен неизвестный пакет id=%d" % pid)
		return

	var meta: Dictionary = GeneratedPackets.PACKETS[pid]
	var action_name: String = meta["name"]
	var read_fn := "read_%s" % action_name

	if not _gp.has_method(read_fn):
		push_error("[NAM] Метод '%s' не найден!" % read_fn)
		return

	var data: Dictionary = _gp.call(read_fn, body)

	if _debug:
		print("[NAM] ← Получен '%s' от peer=%d, данные=%s" % [action_name, peer_id, str(data)])

	packet_received.emit(action_name, peer_id, data)

	if _net.is_server():
		_handle_server(pid, peer_id, data, meta)
	else:
		_handle_client(pid, peer_id, data)


func _handle_server(pid: int, peer_id: int, data: Dictionary, meta: Dictionary) -> void:
	# Валидация
	if meta["server_validates"] and pid in _validators:
		var valid: bool = (_validators[pid] as Callable).call(peer_id, data)
		if not valid:
			if _debug:
				print("[NAM] Пакет '%s' от %d не прошёл валидацию" % [meta["name"], peer_id])
			return

	# Локальный обработчик
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

	if _debug:
		print("[NAM|SRV] Маршрутизация '%s': sync_mode=%d, peers=%d" % [
			action_name, sync_mode, _net.get_peer_ids().size()])

	match sync_mode:
		0:  # CLIENT_TO_SERVER — не пересылаем
			pass
		1:  # SERVER_TO_ALL
			_net.broadcast(pkt, 0, flags)
			if _debug:
				print("[NAM|SRV] → broadcast всем")
		2:  # SERVER_TO_OTHERS
			_net.broadcast_except(peer_id, pkt, 0, flags)
			if _debug:
				print("[NAM|SRV] → broadcast всем кроме %d" % peer_id)
		3:  # CLIENT_TO_ALL_VIA_SERVER
			_net.broadcast_except(peer_id, pkt, 0, flags)
			if _debug:
				print("[NAM|SRV] → broadcast всем кроме %d (via server)" % peer_id)
		4:  # SERVER_TO_OWNER
			_net.send_to_peer(peer_id, pkt, 0, flags)
			if _debug:
				print("[NAM|SRV] → отправлено обратно owner %d" % peer_id)


func _handle_client(pid: int, peer_id: int, data: Dictionary) -> void:
	if pid in _handlers:
		(_handlers[pid] as Callable).call(peer_id, data)


func _find_id(action_name: String) -> int:
	if action_name in _name_to_id:
		return _name_to_id[action_name]

	for pid: int in GeneratedPackets.PACKETS:
		if (GeneratedPackets.PACKETS[pid] as Dictionary)["name"] == action_name:
			_name_to_id[action_name] = pid
			return pid

	return -1
