class_name ServerHUD
extends Control

## HUD сервера — отображение статистики в реальном времени.
## Не модифицирует другие скрипты. Только читает данные.

# ── Внешние зависимости (устанавливаются через setup) ──
var _net: NetworkManager = null
var _pm: PlayerManager = null
var _nam: NetworkActionManager = null

# ── Внутреннее состояние ──────────────────────
var _start_time: float = 0.0
var _update_interval: float = 0.5
var _update_timer: float = 0.0

# Счётчики для bandwidth/pps
var _packets_in: int = 0
var _packets_out: int = 0
var _bytes_in: int = 0
var _bytes_out: int = 0

# Снэпшот за предыдущую секунду
var _pps_in: int = 0
var _pps_out: int = 0
var _bps_in: int = 0
var _bps_out: int = 0
var _bandwidth_timer: float = 0.0

# Tick rate измерение
var _tick_count: int = 0
var _tick_timer: float = 0.0
var _current_tps: float = 0.0

# Пик онлайна
var _peak_online: int = 0

# ── Ноды UI ───────────────────────────────────
@onready var _title_label: Label = %TitleLabel
@onready var _online_label: Label = %OnlineLabel
@onready var _uptime_label: Label = %UptimeLabel
@onready var _tick_rate_label: Label = %TickRateLabel
@onready var _bandwidth_label: Label = %BandwidthLabel
@onready var _packets_label: Label = %PacketsLabel
@onready var _violations_label: Label = %ViolationsLabel
@onready var _player_list: VBoxContainer = %PlayerList


## Инициализация. Вызывать из server.gd после создания компонентов.
func setup(net: NetworkManager, pm: PlayerManager, nam: NetworkActionManager) -> void:
	_net = net
	_pm = pm
	_nam = nam
	_start_time = Time.get_unix_time_from_system()

	# Подписка на сигналы для подсчёта
	_net.peer_connected.connect(_on_peer_connected)
	_net.peer_disconnected.connect(_on_peer_disconnected)
	_nam.packet_received.connect(_on_packet_received)
	_nam.packet_sent.connect(_on_packet_sent)


func _process(delta: float) -> void:
	if _net == null:
		return

	# ── Tick rate ─────────────────────────────
	_tick_count += 1
	_tick_timer += delta
	if _tick_timer >= 1.0:
		_current_tps = _tick_count / _tick_timer
		_tick_count = 0
		_tick_timer = 0.0

	# ── Bandwidth snapshot (каждую секунду) ───
	_bandwidth_timer += delta
	if _bandwidth_timer >= 1.0:
		_pps_in = _packets_in
		_pps_out = _packets_out
		_bps_in = _bytes_in
		_bps_out = _bytes_out
		_packets_in = 0
		_packets_out = 0
		_bytes_in = 0
		_bytes_out = 0
		_bandwidth_timer = 0.0

	# ── Обновление UI (каждые 0.5 сек) ───────
	_update_timer += delta
	if _update_timer >= _update_interval:
		_update_timer = 0.0
		_refresh_ui()


func _refresh_ui() -> void:
	var online := _pm.get_all_ids().size() if _pm != null else 0
	_peak_online = maxi(_peak_online, online)

	# ── Заголовок ─────────────────────────────
	_title_label.text = "══ СЕРВЕР ══"

	# ── Онлайн ────────────────────────────────
	_online_label.text = "Онлайн: %d  (пик: %d)" % [online, _peak_online]

	# ── Аптайм ────────────────────────────────
	var uptime := Time.get_unix_time_from_system() - _start_time
	_uptime_label.text = "Аптайм: %s" % _format_uptime(uptime)

	# ── Tick rate ─────────────────────────────
	var tps_color := "green" if _current_tps >= 55.0 else ("yellow" if _current_tps >= 30.0 else "red")
	_tick_rate_label.text = "TPS: %.0f" % _current_tps

	# ── Bandwidth ─────────────────────────────
	_bandwidth_label.text = "Трафик: ↓%s/с  ↑%s/с" % [
		_format_bytes(_bps_in),
		_format_bytes(_bps_out),
	]

	# ── Пакеты ────────────────────────────────
	_packets_label.text = "Пакеты: ↓%d/с  ↑%d/с" % [_pps_in, _pps_out]

	# ── Нарушения ─────────────────────────────
	_violations_label.text = "Нарушения: %s" % _get_violations_text()

	# ── Список игроков ────────────────────────
	_refresh_player_list()


func _refresh_player_list() -> void:
	# Удалить старые
	for child in _player_list.get_children():
		child.queue_free()

	if _pm == null:
		return

	var ids := _pm.get_all_ids()
	if ids.is_empty():
		var empty_label := Label.new()
		empty_label.text = "  (нет игроков)"
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_player_list.add_child(empty_label)
		return

	for id: int in ids:
		var data: Dictionary = _pm.get_player_data(id)
		var pos: Vector3 = data.get("position", Vector3.ZERO)
		var idle := _net.get_peer_idle_time(id)

		var label := Label.new()
		label.text = "  #%d  pos=(%.0f, %.0f, %.0f)  idle=%.1fs" % [
			id, pos.x, pos.y, pos.z, idle]

		if idle > 5.0:
			label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.0))
		else:
			label.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))

		_player_list.add_child(label)


# ══════════════════════════════════════════════════
# СЧЁТЧИКИ
# ══════════════════════════════════════════════════

func _on_peer_connected(_id: int) -> void:
	pass  # Обновится через _refresh_ui


func _on_peer_disconnected(_id: int) -> void:
	pass  # Обновится через _refresh_ui


func _on_packet_received(action_name: String, peer_id: int, data: Dictionary) -> void:
	_packets_in += 1
	# Примерная оценка размера (точный размер не доступен из NAM)
	_bytes_in += 8 + _estimate_data_size(data)


func _on_packet_sent(action_name: String) -> void:
	_packets_out += 1
	_bytes_out += 16  # Минимальная оценка


# ══════════════════════════════════════════════════
# ФОРМАТИРОВАНИЕ
# ══════════════════════════════════════════════════

func _format_uptime(seconds: float) -> String:
	var s := int(seconds)
	var h := s / 3600
	var m := (s % 3600) / 60
	var sec := s % 60
	if h > 0:
		return "%d:%02d:%02d" % [h, m, sec]
	return "%02d:%02d" % [m, sec]


func _format_bytes(bytes: int) -> String:
	if bytes < 1024:
		return "%d B" % bytes
	elif bytes < 1048576:
		return "%.1f KB" % (bytes / 1024.0)
	else:
		return "%.1f MB" % (bytes / 1048576.0)


func _estimate_data_size(data: Dictionary) -> int:
	var size := 0
	for key: String in data:
		var val: Variant = data[key]
		if val is int:
			size += 4
		elif val is float:
			size += 4
		elif val is Vector3:
			size += 12
		elif val is Vector2:
			size += 8
		elif val is bool:
			size += 1
		elif val is String:
			size += (val as String).length()
		elif val is PackedByteArray:
			size += (val as PackedByteArray).size()
		else:
			size += 4
	return size


func _get_violations_text() -> String:
	# Читаем _security_log из server.gd через get_parent
	var server := get_parent()
	if server == null or not server.has_method("get_security_log"):
		return "—"

	var log: Dictionary = server.get_security_log()
	if log.is_empty():
		return "0"

	var parts := PackedStringArray()
	var total := 0
	for reason: String in log:
		var count: int = log[reason]
		total += count
		parts.append("%s:%d" % [reason, count])

	if parts.size() > 3:
		return "%d (%s ...)" % [total, ", ".join(parts.slice(0, 3))]
	return "%d (%s)" % [total, ", ".join(parts)]
