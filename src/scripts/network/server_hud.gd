class_name ServerHUD
extends Control

## HUD сервера — отображение статистики в реальном времени.
## Теперь использует реальные transport-метрики из NetworkManager.

var _net: NetworkManager = null
var _pm: PlayerManager = null
var _nam: NetworkActionManager = null

var _start_time: float = 0.0
var _update_interval: float = 0.5
var _update_timer: float = 0.0

var _prof_aoi_passes_ps: int = 0
var _prof_aoi_time_ms_ps: float = 0.0
var _prof_aoi_observers_ps: int = 0
var _prof_candidate_targets_ps: int = 0
var _prof_visible_pairs_ps: int = 0

var _prof_repl_passes_ps: int = 0
var _prof_repl_time_ms_ps: float = 0.0
var _prof_repl_observers_ps: int = 0
var _prof_repl_targets_ps: int = 0

# Loop rate измерение (это не physics TPS, а частота _process HUD)
var _loop_count: int = 0
var _loop_timer: float = 0.0
var _current_loop_rate: float = 0.0
# TPS
var _server_tps: float = 0.0
var _tick_avg_ms: float = 0.0
var _tick_max_ms: float = 0.0
# Пик онлайна
var _peak_online: int = 0

# Последний snapshot transport stats
var _last_stats: Dictionary = {}
var _last_replication_stats: Dictionary = {}

var _batch_packets_ps: int = 0
var _batch_entries_ps: int = 0
var _batch_avg_entries: float = 0.0
var _batch_max_entries_seen: int = 0

# Дельты за последнюю секунду
var _pps_in: int = 0
var _pps_out: int = 0
var _bps_in: int = 0
var _bps_out: int = 0
var _invalid_in: int = 0

var _peer_bps_in: Dictionary = {}
var _peer_bps_out: Dictionary = {}

var _top_in_types_text: String = "—"
var _top_out_types_text: String = "—"

var _bandwidth_timer: float = 0.0

# ── Ноды UI ───────────────────────────────────
@onready var _title_label: Label = %TitleLabel
@onready var _online_label: Label = %OnlineLabel
@onready var _uptime_label: Label = %UptimeLabel
@onready var _tick_rate_label: Label = %TickRateLabel
@onready var _bandwidth_label: Label = %BandwidthLabel
@onready var _packets_label: Label = %PacketsLabel
@onready var _violations_label: Label = %ViolationsLabel
@onready var _player_list: VBoxContainer = %PlayerList


func setup(net: NetworkManager, pm: PlayerManager, nam: NetworkActionManager) -> void:
	_net = net
	_pm = pm
	_nam = nam
	_start_time = Time.get_unix_time_from_system()
	_last_stats = _net.get_stats_snapshot()
	_last_replication_stats = _get_replication_stats_snapshot()


func _process(delta: float) -> void:
	if _net == null:
		return

	# ── Loop rate ─────────────────────────────
	_loop_count += 1
	_loop_timer += delta
	if _loop_timer >= 1.0:
		_current_loop_rate = _loop_count / _loop_timer
		_loop_count = 0
		_loop_timer = 0.0

	# ── Transport snapshot (каждую секунду) ───
	_bandwidth_timer += delta
	if _bandwidth_timer >= 1.0:
		_bandwidth_timer = 0.0
		_refresh_transport_metrics()

	# ── Обновление UI (каждые 0.5 сек) ───────
	_update_timer += delta
	if _update_timer >= _update_interval:
		_update_timer = 0.0
		_refresh_ui()


func _refresh_transport_metrics() -> void:
	var current: Dictionary = _net.get_stats_snapshot()

	_pps_in = int(current.get("packets_in_total", 0)) - int(_last_stats.get("packets_in_total", 0))
	_pps_out = int(current.get("packets_out_total", 0)) - int(_last_stats.get("packets_out_total", 0))
	_bps_in = int(current.get("bytes_in_total", 0)) - int(_last_stats.get("bytes_in_total", 0))
	_bps_out = int(current.get("bytes_out_total", 0)) - int(_last_stats.get("bytes_out_total", 0))
	_invalid_in = int(current.get("invalid_in_total", 0)) - int(_last_stats.get("invalid_in_total", 0))

	var cur_in_by_peer: Dictionary = current.get("bytes_in_by_peer", {})
	var prev_in_by_peer: Dictionary = _last_stats.get("bytes_in_by_peer", {})
	var cur_out_by_peer: Dictionary = current.get("bytes_out_by_peer", {})
	var prev_out_by_peer: Dictionary = _last_stats.get("bytes_out_by_peer", {})

	_peer_bps_in = _dict_int_delta(cur_in_by_peer, prev_in_by_peer)
	_peer_bps_out = _dict_int_delta(cur_out_by_peer, prev_out_by_peer)

	var cur_in_by_type: Dictionary = current.get("packets_in_by_type", {})
	var prev_in_by_type: Dictionary = _last_stats.get("packets_in_by_type", {})
	var cur_out_by_type: Dictionary = current.get("packets_out_by_type", {})
	var prev_out_by_type: Dictionary = _last_stats.get("packets_out_by_type", {})

	var delta_in_by_type: Dictionary = _dict_int_delta(cur_in_by_type, prev_in_by_type)
	var delta_out_by_type: Dictionary = _dict_int_delta(cur_out_by_type, prev_out_by_type)

	_top_in_types_text = _format_top_packet_types(delta_in_by_type)
	_top_out_types_text = _format_top_packet_types(delta_out_by_type)

	_last_stats = current

	# ── Replication / batch stats ─────────────────
	var repl_current: Dictionary = _get_replication_stats_snapshot()

	_batch_packets_ps = int(repl_current.get("batch_packets_sent_total", 0)) - int(_last_replication_stats.get("batch_packets_sent_total", 0))
	_batch_entries_ps = int(repl_current.get("batch_entries_sent_total", 0)) - int(_last_replication_stats.get("batch_entries_sent_total", 0))
	_batch_max_entries_seen = int(repl_current.get("batch_max_entries_seen", 0))

	if _batch_packets_ps > 0:
		_batch_avg_entries = float(_batch_entries_ps) / float(_batch_packets_ps)
	else:
		_batch_avg_entries = 0.0

	_last_replication_stats = repl_current
	_server_tps = float(repl_current.get("server_physics_tps", 0.0))
	_tick_avg_ms = float(repl_current.get("tick_avg_ms", 0.0))
	_tick_max_ms = float(repl_current.get("tick_max_ms", 0.0))
	_prof_aoi_passes_ps = int(repl_current.get("prof_aoi_passes_ps", 0))
	_prof_aoi_time_ms_ps = float(repl_current.get("prof_aoi_time_ms_ps", 0.0))
	_prof_aoi_observers_ps = int(repl_current.get("prof_aoi_observers_ps", 0))
	_prof_candidate_targets_ps = int(repl_current.get("prof_candidate_targets_ps", 0))
	_prof_visible_pairs_ps = int(repl_current.get("prof_visible_pairs_ps", 0))

	_prof_repl_passes_ps = int(repl_current.get("prof_repl_passes_ps", 0))
	_prof_repl_time_ms_ps = float(repl_current.get("prof_repl_time_ms_ps", 0.0))
	_prof_repl_observers_ps = int(repl_current.get("prof_repl_observers_ps", 0))
	_prof_repl_targets_ps = int(repl_current.get("prof_repl_targets_ps", 0))


func _refresh_ui() -> void:
	var online := _pm.get_all_ids().size() if _pm != null else 0
	_peak_online = maxi(_peak_online, online)

	_title_label.text = "══ СЕРВЕР ══"
	_online_label.text = "Онлайн: %d  (пик: %d)" % [online, _peak_online]

	var uptime := Time.get_unix_time_from_system() - _start_time
	_uptime_label.text = "Аптайм: %s" % _format_uptime(uptime)

	var aoi_avg_ms := _prof_aoi_time_ms_ps / maxf(float(_prof_aoi_passes_ps), 1.0)
	var repl_avg_ms := _prof_repl_time_ms_ps / maxf(float(_prof_repl_passes_ps), 1.0)

	# ——— Обновлённый tick rate label с TPS ———
	var tps_color: String
	if _server_tps >= 55.0:
		tps_color = "🟢"
	elif _server_tps >= 40.0:
		tps_color = "🟡"
	else:
		tps_color = "🔴"

	_tick_rate_label.text = "%s TPS: %.0f  (avg %.1fms  max %.1fms)\nLoop: %.0f/s\nAOI: %d/s  total %.1fms  avg %.2fms\nREPL: %d/s  total %.1fms  avg %.2fms" % [
		tps_color,
		_server_tps,
		_tick_avg_ms,
		_tick_max_ms,
		_current_loop_rate,
		_prof_aoi_passes_ps,
		_prof_aoi_time_ms_ps,
		aoi_avg_ms,
		_prof_repl_passes_ps,
		_prof_repl_time_ms_ps,
		repl_avg_ms,
	]

	var total_in := int(_last_stats.get("bytes_in_total", 0))
	var total_out := int(_last_stats.get("bytes_out_total", 0))
	_bandwidth_label.text = "Трафик: ↓%s/с ↑%s/с   total ↓%s ↑%s" % [
		_format_bytes(_bps_in),
		_format_bytes(_bps_out),
		_format_bytes(total_in),
		_format_bytes(total_out),
	]

	_packets_label.text = "Пакеты: ↓%d/с ↑%d/с  invalid:%d\nBatch: %d pkt/s  %d entries/s  avg: %.2f  max: %d\nAOI obs:%d  cand:%d  vis:%d\nREPL obs:%d  targets:%d\nTop in: %s\nTop out: %s" % [
		_pps_in,
		_pps_out,
		_invalid_in,
		_batch_packets_ps,
		_batch_entries_ps,
		_batch_avg_entries,
		_batch_max_entries_seen,
		_prof_aoi_observers_ps,
		_prof_candidate_targets_ps,
		_prof_visible_pairs_ps,
		_prof_repl_observers_ps,
		_prof_repl_targets_ps,
		_top_in_types_text,
		_top_out_types_text,
	]

	_violations_label.text = "Нарушения: %s" % _get_violations_text()
	_refresh_player_list()


func _refresh_player_list() -> void:
	for child in _player_list.get_children():
		child.queue_free()

	if _pm == null or _net == null:
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

		var rx_bps: int = int(_peer_bps_in.get(id, 0))
		var tx_bps: int = int(_peer_bps_out.get(id, 0))

		var label := Label.new()
		label.text = "  #%d  pos=(%.0f, %.0f, %.0f)  idle=%.1fs  ↓%s/s ↑%s/s" % [
			id,
			pos.x, pos.y, pos.z,
			idle,
			_format_bytes(rx_bps),
			_format_bytes(tx_bps),
		]

		if idle > 5.0:
			label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.0))
		else:
			label.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))

		_player_list.add_child(label)


# ══════════════════════════════════════════════════
#  HELPERS
# ══════════════════════════════════════════════════

func _dict_int_delta(current: Dictionary, previous: Dictionary) -> Dictionary:
	var result: Dictionary = {}

	for key in current.keys():
		var delta := int(current.get(key, 0)) - int(previous.get(key, 0))
		if delta > 0:
			result[key] = delta

	return result


func _format_top_packet_types(delta_map: Dictionary, limit: int = 3) -> String:
	if delta_map.is_empty():
		return "—"

	var items: Array = []
	for key in delta_map.keys():
		items.append({
			"type": int(key),
			"count": int(delta_map[key]),
		})

	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["count"]) > int(b["count"])
	)

	var parts := PackedStringArray()
	var count := mini(limit, items.size())
	for i in range(count):
		var item: Dictionary = items[i]
		var type_id: int = int(item["type"])
		var amount: int = int(item["count"])
		parts.append("%s:%d" % [_packet_type_name(type_id), amount])

	return ", ".join(parts)


func _packet_type_name(type_id: int) -> String:
	match type_id:
		PacketTypes.PING:
			return "PING"
		PacketTypes.PONG:
			return "PONG"
		PacketTypes.PLAYER_JOINED:
			return "PLAYER_JOINED"
		PacketTypes.PLAYER_LEFT:
			return "PLAYER_LEFT"
		PacketTypes.WELCOME:
			return "WELCOME"
		PacketTypes.AUTH_REQUEST:
			return "AUTH_REQ"
		PacketTypes.AUTH_RESPONSE:
			return "AUTH_RESP"
		PacketTypes.CHAMELEON_SYNC:
			return "CHAM_SYNC"
		PacketTypes.PLAYER_SNAPSHOT_BATCH:
			return "SNAP_BATCH"
		_:
			if type_id in GeneratedPackets.PACKETS:
				var meta: Dictionary = GeneratedPackets.PACKETS[type_id]
				return String(meta.get("name", str(type_id)))
			return str(type_id)


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


func _get_violations_text() -> String:
	var server := get_parent()
	if server == null or not server.has_method("get_security_log"):
		return "—"

	var log: Dictionary = server.get_security_log()
	if log.is_empty():
		return "0"

	var parts := PackedStringArray()
	var total := 0

	for reason: String in log:
		var count: int = int(log[reason])
		total += count
		parts.append("%s:%d" % [reason, count])

	if parts.size() > 3:
		return "%d (%s ...)" % [total, ", ".join(parts.slice(0, 3))]
	return "%d (%s)" % [total, ", ".join(parts)]

func _get_replication_stats_snapshot() -> Dictionary:
	var server := get_parent()
	if server == null:
		return {}

	var repl := server.get_node_or_null("PlayerReplicationManager")
	if repl == null:
		return {}

	if repl.has_method("get_stats_snapshot"):
		return repl.get_stats_snapshot()

	return {}
