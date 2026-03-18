class_name PlayerReplicationManager
extends Node

# ══════════════════════════════════════════════════
#  REUSABLE BUFFERS — allocated once, cleared each use
# ══════════════════════════════════════════════════

## Per-tick cache: peer_id -> bool (rebuilt once per tick)
var _ready_cache: Dictionary = {}

## Per-tick cache: peer_id -> world_id String (rebuilt once per tick)
var _world_cache: Dictionary = {}

## Reusable buffer for _gather_candidate_targets
var _candidate_buffer: Dictionary = {}

## Reusable buffer for stale target detection
var _stale_buffer: Dictionary = {}

## Reusable buffer for priority scoring (Vector2(-score, id))
var _sort_buffer: Array = []

## Reusable buffer for batch entries in replication
var _batch_buffer: Array[Dictionary] = []

# ══════════════════════════════════════════════════
#  PROFILING STATS
# ══════════════════════════════════════════════════

var _prof_window_accum: float = 0.0

# Текущие накопители окна
var _prof_aoi_passes_accum: int = 0
var _prof_aoi_time_ms_accum: float = 0.0
var _prof_aoi_observers_accum: int = 0
var _prof_candidate_targets_accum: int = 0
var _prof_visible_pairs_accum: int = 0

var _prof_repl_passes_accum: int = 0
var _prof_repl_time_ms_accum: float = 0.0
var _prof_repl_observers_accum: int = 0
var _prof_repl_targets_accum: int = 0

var _prof_batch_packets_accum: int = 0
var _prof_batch_entries_accum: int = 0

# Последний опубликованный snapshot за окно
var _prof_aoi_passes_ps: int = 0
var _prof_aoi_time_ms_ps: float = 0.0
var _prof_aoi_observers_ps: int = 0
var _prof_candidate_targets_ps: int = 0
var _prof_visible_pairs_ps: int = 0

var _prof_repl_passes_ps: int = 0
var _prof_repl_time_ms_ps: float = 0.0
var _prof_repl_observers_ps: int = 0
var _prof_repl_targets_ps: int = 0

var _prof_batch_packets_ps: int = 0
var _prof_batch_entries_ps: int = 0
##------------------------------------------------------------------------------
const DEFAULT_WORLD_ID := "default_world"

const REPLICATION_TPS := 20.0

const AOI_UPDATE_TPS := 5.0

const AOI_ENTER_DISTANCE := 100.0
const AOI_EXIT_DISTANCE  := 115.0

const LOD_NEAR_DISTANCE := 20.0
const LOD_MID_DISTANCE  := 45.0
const LOD_FAR_DISTANCE  := 90.0

const LOD_NEAR_HZ       := 20.0
const LOD_MID_HZ        := 10.0
const LOD_FAR_HZ        := 5.0
const LOD_VERY_FAR_HZ   := 4.0
## Приоритет клиентов для клиента
const PRIORITY_ALWAYS_TARGETS := 24
const PRIORITY_ROTATING_TARGETS := 24

const PRIORITY_DISTANCE_WEIGHT := 80.0
const PRIORITY_FRONT_WEIGHT := 25.0
const PRIORITY_OVERDUE_WEIGHT := 120.0

## Размер ячейки spatial grid.
const GRID_CELL_SIZE := 40.0

var _net: NetworkManager = null
var _pm: PlayerManager = null
var _authenticated: Dictionary = {}

## Callable(peer_id) -> String(world_id)
var _world_resolver: Callable = Callable()

var _replication_accumulator: float = 0.0
var _replication_time: float = 0.0
var _aoi_accumulator: float = 0.0

# observer_id -> { target_id -> last_send_time }
var _replication_last_send: Dictionary = {}

# observer_id -> { target_id -> last_sent_tick }
var _replication_last_tick: Dictionary = {}

# target_id -> latest authoritative movement tick
var _authoritative_move_ticks: Dictionary = {}
# target_id -> {
#   "tick": int,
#   "position": Vector3,
#   "velocity": Vector3,
#   "head_pitch": float,
#   "body_yaw": float,
# }
var _authoritative_states: Dictionary = {}

# observer_id -> { target_id -> true }
var _visible_targets: Dictionary = {}

# world_id -> { cell(Vector2i) -> { peer_id -> true } }
var _spatial_cells: Dictionary = {}

# peer_id -> { "world_id": String, "cell": Vector2i }
var _peer_cells: Dictionary = {}

# observer_id -> Array[int] (target ids sorted by priority)
var _priority_target_lists: Dictionary = {}

# observer_id -> int
var _priority_rotating_cursor: Dictionary = {}

var _stats_batch_packets_sent_total: int = 0
var _stats_batch_entries_sent_total: int = 0
var _stats_batch_max_entries_seen: int = 0

func setup(
	net: NetworkManager,
	pm: PlayerManager,
	authenticated: Dictionary,
	world_resolver: Callable = Callable()
) -> void:
	_net = net
	_pm = pm
	_authenticated = authenticated
	_world_resolver = world_resolver


func set_world_resolver(world_resolver: Callable) -> void:
	_world_resolver = world_resolver


func tick(delta: float) -> void:
	if _net == null or _pm == null:
		return

	# ——— Build caches ONCE per frame ———
	_rebuild_tick_caches()

	_aoi_accumulator += delta
	var aoi_step := 1.0 / AOI_UPDATE_TPS
	while _aoi_accumulator >= aoi_step:
		_aoi_accumulator -= aoi_step

		var aoi_t0_us: int = Time.get_ticks_usec()
		_rebuild_spatial_grid()
		_update_visibility_sets()
		var aoi_elapsed_ms: float = float(Time.get_ticks_usec() - aoi_t0_us) / 1000.0

		_prof_aoi_passes_accum += 1
		_prof_aoi_time_ms_accum += aoi_elapsed_ms

	_replication_time += delta
	_replication_accumulator += delta

	var step := 1.0 / REPLICATION_TPS
	while _replication_accumulator >= step:
		_replication_accumulator -= step

		var repl_t0_us: int = Time.get_ticks_usec()
		_replicate_player_snapshots()
		var repl_elapsed_ms: float = float(Time.get_ticks_usec() - repl_t0_us) / 1000.0

		_prof_repl_passes_accum += 1
		_prof_repl_time_ms_accum += repl_elapsed_ms

	_prof_window_accum += delta
	if _prof_window_accum >= 1.0:
		_flush_profile_window()
		_prof_window_accum = 0.0


func on_player_spawned(peer_id: int) -> void:
	_authoritative_move_ticks[peer_id] = 0

	var pos := Vector3.ZERO
	var rot := Vector3.ZERO

	if _pm != null and _pm.has_player(peer_id):
		var d: Dictionary = _pm.get_player_data(peer_id)
		pos = d.get("position", Vector3.ZERO)
		rot = d.get("rotation", Vector3.ZERO)

	_authoritative_states[peer_id] = {
		"tick": 0,
		"position": pos,
		"velocity": Vector3.ZERO,
		"head_pitch": rot.x,
		"body_yaw": rot.y,
	}


func on_authoritative_move(peer_id: int, tick: int, pos: Vector3, head_pitch: float, body_yaw: float) -> void:
	var new_tick: int = tick & 0xFFFF
	var velocity := Vector3.ZERO

	if peer_id in _authoritative_states:
		var prev: Dictionary = _authoritative_states[peer_id]
		var prev_pos: Vector3 = prev.get("position", pos)
		var prev_tick: int = int(prev.get("tick", new_tick))

		var dt := _compute_authoritative_dt(prev_tick, new_tick)
		if dt > 0.0:
			velocity = (pos - prev_pos) / dt

	_authoritative_move_ticks[peer_id] = new_tick
	_authoritative_states[peer_id] = {
		"tick": new_tick,
		"position": pos,
		"velocity": velocity,
		"head_pitch": head_pitch,
		"body_yaw": body_yaw,
	}


func on_player_disconnected(peer_id: int) -> void:
	_cleanup_replication_peer(peer_id, true)


func refresh_visibility_now() -> void:
	_rebuild_spatial_grid()
	_update_visibility_sets()


func clear() -> void:
	_replication_accumulator = 0.0
	_replication_time = 0.0
	_aoi_accumulator = 0.0

	_replication_last_send.clear()
	_replication_last_tick.clear()
	_authoritative_move_ticks.clear()
	_authoritative_states.clear()
	_visible_targets.clear()

	_spatial_cells.clear()
	_peer_cells.clear()

	_stats_batch_packets_sent_total = 0
	_stats_batch_entries_sent_total = 0
	_stats_batch_max_entries_seen = 0
	
	_prof_window_accum = 0.0

	_prof_aoi_passes_accum = 0
	_prof_aoi_time_ms_accum = 0.0
	_prof_aoi_observers_accum = 0
	_prof_candidate_targets_accum = 0
	_prof_visible_pairs_accum = 0

	_prof_repl_passes_accum = 0
	_prof_repl_time_ms_accum = 0.0
	_prof_repl_observers_accum = 0
	_prof_repl_targets_accum = 0

	_prof_batch_packets_accum = 0
	_prof_batch_entries_accum = 0

	_prof_aoi_passes_ps = 0
	_prof_aoi_time_ms_ps = 0.0
	_prof_aoi_observers_ps = 0
	_prof_candidate_targets_ps = 0
	_prof_visible_pairs_ps = 0

	_prof_repl_passes_ps = 0
	_prof_repl_time_ms_ps = 0.0
	_prof_repl_observers_ps = 0
	_prof_repl_targets_ps = 0

	_prof_batch_packets_ps = 0
	_prof_batch_entries_ps = 0
	
	_priority_target_lists.clear()
	_priority_rotating_cursor.clear()
	_authoritative_states.clear()
	_ready_cache.clear()
	_world_cache.clear()
	_candidate_buffer.clear()
	_stale_buffer.clear()
	_sort_buffer.clear()
	_batch_buffer.clear()


# ══════════════════════════════════════════════════
#  REPLICATION
# ══════════════════════════════════════════════════

func _replicate_player_snapshots() -> void:
	var observers_processed: int = 0
	var repl_targets_total: int = 0

	for observer_var in _visible_targets:  # ← no .keys()
		var observer_id: int = int(observer_var)

		if not _ready_cache.get(observer_id, false):  # ← cached
			continue

		observers_processed += 1

		var observer_world: String = _world_cache.get(observer_id, DEFAULT_WORLD_ID)  # ← cached
		var observer_data: Dictionary = _pm.get_player_data(observer_id)
		var obs_x: float = observer_data.get("position", Vector3.ZERO).x
		var obs_z: float = observer_data.get("position", Vector3.ZERO).z

		var send_map: Dictionary = _replication_last_send.get(observer_id, {})
		var tick_map: Dictionary = _replication_last_tick.get(observer_id, {})

		_batch_buffer.clear()  # ← reused, no new Array
		var selected_targets: Array[int] = _get_priority_replication_targets(observer_id)

		for target_id in selected_targets:
			repl_targets_total += 1

			if not _ready_cache.get(target_id, false):  # ← cached
				continue
			if _world_cache.get(target_id, DEFAULT_WORLD_ID) != observer_world:  # ← cached
				continue

			if target_id not in _authoritative_states:
				continue

			var auth_state: Dictionary = _authoritative_states[target_id]
			var target_tick: int = int(auth_state.get("tick", -1))
			if target_tick < 0:
				continue

			var target_pos: Vector3 = auth_state.get("position", Vector3.ZERO)

			# ——— Inlined horizontal distance ———
			var dx: float = obs_x - target_pos.x
			var dz: float = obs_z - target_pos.z
			var distance: float = sqrt(dx * dx + dz * dz)

			# ——— Inlined hz check ———
			var hz: float
			if distance <= LOD_NEAR_DISTANCE:
				hz = LOD_NEAR_HZ
			elif distance <= LOD_MID_DISTANCE:
				hz = LOD_MID_HZ
			elif distance <= LOD_FAR_DISTANCE:
				hz = LOD_FAR_HZ
			else:
				hz = LOD_VERY_FAR_HZ

			var last_tick_sent: int = int(tick_map.get(target_id, -1))
			if last_tick_sent == target_tick:
				continue

			var interval: float = 1.0 / hz
			var last_send_time: float = float(send_map.get(target_id, -1.0))
			if last_send_time >= 0.0 and (_replication_time - last_send_time) < interval:
				continue

			_batch_buffer.append({
				"peer_id": target_id,
				"tick": target_tick,
				"position": target_pos,
				"velocity": auth_state.get("velocity", Vector3.ZERO),
				"head_pitch": float(auth_state.get("head_pitch", 0.0)),
				"body_yaw": float(auth_state.get("body_yaw", 0.0)),
			})

			send_map[target_id] = _replication_time
			tick_map[target_id] = target_tick

		if not _batch_buffer.is_empty():
			_send_snapshot_batches(observer_id, _batch_buffer)

	_prof_repl_observers_accum += observers_processed
	_prof_repl_targets_accum += repl_targets_total

func _get_replication_hz(distance: float) -> float:
	if distance <= LOD_NEAR_DISTANCE:
		return LOD_NEAR_HZ
	if distance <= LOD_MID_DISTANCE:
		return LOD_MID_HZ
	if distance <= LOD_FAR_DISTANCE:
		return LOD_FAR_HZ
	return LOD_VERY_FAR_HZ


func _send_snapshot_batches(observer_id: int, entries: Array[Dictionary]) -> void:
	var max_entries: int = PacketTypes.SNAPSHOT_BATCH_MAX_ENTRIES
	if max_entries <= 0:
		return

	var offset := 0
	while offset < entries.size():
		var end := mini(offset + max_entries, entries.size())
		var chunk: Array[Dictionary] = entries.slice(offset, end)

		var chunk_entry_count: int = chunk.size()

		_stats_batch_packets_sent_total += 1
		_stats_batch_entries_sent_total += chunk_entry_count
		if chunk_entry_count > _stats_batch_max_entries_seen:
			_stats_batch_max_entries_seen = chunk_entry_count

		_prof_batch_packets_accum += 1
		_prof_batch_entries_accum += chunk_entry_count

		var pkt := PacketTypes.write_player_snapshot_batch(chunk)
		_net.send_to_peer(observer_id, pkt, 1, 0)

		offset = end

## Rebuild per-tick caches once. Replaces hundreds of 
## _is_peer_ready_for_replication() + _get_peer_world() calls
func _rebuild_tick_caches() -> void:
	_ready_cache.clear()
	_world_cache.clear()

	var ids: Array = _pm.get_all_ids()
	for peer_var in ids:
		var peer_id: int = int(peer_var)
		var ready: bool = _authenticated.get(peer_id, false) and _pm.has_player(peer_id)
		_ready_cache[peer_id] = ready

		if ready:
			if _world_resolver.is_valid():
				var value: Variant = _world_resolver.call(peer_id)
				if value is String and value != "":
					_world_cache[peer_id] = value
					continue
			_world_cache[peer_id] = DEFAULT_WORLD_ID
# ══════════════════════════════════════════════════
#  AOI / VISIBILITY
# ══════════════════════════════════════════════════

func _update_visibility_sets() -> void:
	var ids: Array = _pm.get_all_ids()

	var observers_processed: int = 0
	var candidate_targets_total: int = 0
	var visible_pairs_total: int = 0

	var enter_sq: float = AOI_ENTER_DISTANCE * AOI_ENTER_DISTANCE
	var exit_sq: float = AOI_EXIT_DISTANCE * AOI_EXIT_DISTANCE

	for observer_var in ids:
		var observer_id: int = int(observer_var)

		if not _ready_cache.get(observer_id, false):  # ← cached
			_clear_observer_replication_state(observer_id)
			continue

		observers_processed += 1
		_ensure_observer_replication_state(observer_id)

		var observer_world: String = _world_cache.get(observer_id, DEFAULT_WORLD_ID)  # ← cached
		var observer_data: Dictionary = _pm.get_player_data(observer_id)
		var observer_pos: Vector3 = observer_data.get("position", Vector3.ZERO)
		var obs_x: float = observer_pos.x
		var obs_z: float = observer_pos.z

		var visible_map: Dictionary = _visible_targets[observer_id]
		var send_map: Dictionary = _replication_last_send[observer_id]
		var tick_map: Dictionary = _replication_last_tick[observer_id]

		# ——— Gather candidates into reusable buffer ———
		_gather_candidate_targets_into(observer_pos, observer_world)
		_candidate_buffer.erase(observer_id)

		candidate_targets_total += _candidate_buffer.size()

		_stale_buffer.clear()  # ← reused, no new Dict

		# ——— Check candidates for enter/exit ———
		for target_var in _candidate_buffer:  # ← no .keys()
			var target_id: int = int(target_var)

			if not _ready_cache.get(target_id, false):  # ← cached
				continue

			var target_data: Dictionary = _pm.get_player_data(target_id)
			var target_pos: Vector3 = target_data.get("position", Vector3.ZERO)

			# ——— Inlined horizontal_distance_sq ———
			var dx: float = obs_x - target_pos.x
			var dz: float = obs_z - target_pos.z
			var dist_sq: float = dx * dx + dz * dz

			var currently_visible: bool = target_id in visible_map

			# ——— Inlined AOI hysteresis check ———
			var threshold_sq: float = exit_sq if currently_visible else enter_sq
			var should_be_visible: bool = dist_sq <= threshold_sq

			if should_be_visible:
				if not currently_visible:
					visible_map[target_id] = true
					send_map.erase(target_id)
					tick_map.erase(target_id)
					_send_player_enter(observer_id, target_id)
			else:
				if currently_visible:
					_stale_buffer[target_id] = true

		# ——— Find visible targets that left candidate range ———
		for target_var in visible_map:  # ← no .keys() — safe, not modifying visible_map here
			var target_id: int = int(target_var)
			if target_id not in _candidate_buffer:
				_stale_buffer[target_id] = true

		# ——— Process stale exits ———
		for target_var in _stale_buffer:  # ← no .keys()
			var target_id: int = int(target_var)
			if target_id in visible_map:
				visible_map.erase(target_id)
				send_map.erase(target_id)
				tick_map.erase(target_id)
				_send_player_exit(observer_id, target_id)

		visible_pairs_total += visible_map.size()

		_rebuild_priority_targets_for_observer(
			observer_id, observer_pos, observer_data, visible_map
		)

	_prof_aoi_observers_accum += observers_processed
	_prof_candidate_targets_accum += candidate_targets_total
	_prof_visible_pairs_accum += visible_pairs_total


func _ensure_observer_replication_state(observer_id: int) -> void:
	if observer_id not in _visible_targets:
		_visible_targets[observer_id] = {}
	if observer_id not in _replication_last_send:
		_replication_last_send[observer_id] = {}
	if observer_id not in _replication_last_tick:
		_replication_last_tick[observer_id] = {}

func _rebuild_priority_targets_for_observer(
	observer_id: int,
	observer_pos: Vector3,
	observer_data: Dictionary,
	visible_map: Dictionary
) -> void:
	if visible_map.is_empty():
		_priority_target_lists[observer_id] = []
		_priority_rotating_cursor[observer_id] = 0
		return

	var observer_rot: Vector3 = observer_data.get("rotation", Vector3.ZERO)
	var observer_yaw: float = observer_rot.y
	# Инлайним forward вектор (только XZ)
	var fwd_x: float = -sin(observer_yaw)
	var fwd_z: float = -cos(observer_yaw)

	var obs_x: float = observer_pos.x
	var obs_z: float = observer_pos.z
	var inv_aoi: float = 1.0 / AOI_EXIT_DISTANCE

	var send_map: Dictionary = _replication_last_send.get(observer_id, {})

	_sort_buffer.clear()  # ← reused Array, no alloc

	for target_var in visible_map:  # ← no .keys()
		var target_id: int = int(target_var)

		if not _pm.has_player(target_id):
			continue

		var target_data: Dictionary = _pm.get_player_data(target_id)
		var target_pos: Vector3 = target_data.get("position", Vector3.ZERO)

		# ——— Inlined distance + direction ———
		var dx: float = target_pos.x - obs_x
		var dz: float = target_pos.z - obs_z
		var distance: float = sqrt(dx * dx + dz * dz)

		var distance_norm: float = distance * inv_aoi
		if distance_norm > 1.0:
			distance_norm = 1.0
		var distance_score: float = (1.0 - distance_norm) * PRIORITY_DISTANCE_WEIGHT

		# ——— Front dot — inlined without Vector3 ———
		var front_dot: float = 0.0
		if distance > 0.0001:
			var inv_d: float = 1.0 / distance
			front_dot = fwd_x * dx * inv_d + fwd_z * dz * inv_d

		var front_score: float = clampf(
			(front_dot + 1.0) * 0.5, 0.0, 1.0
		) * PRIORITY_FRONT_WEIGHT

		# ——— Overdue score ———
		var expected_hz: float = _get_replication_hz_inline(distance)
		var expected_interval: float = 1.0 / expected_hz
		var last_send_time: float = float(send_map.get(target_id, -1.0))

		var overdue_ratio: float = 1.0
		if last_send_time >= 0.0:
			overdue_ratio = (_replication_time - last_send_time) / expected_interval
			if overdue_ratio < 0.0:
				overdue_ratio = 0.0
			elif overdue_ratio > 3.0:
				overdue_ratio = 3.0

		var overdue_score: float = overdue_ratio * PRIORITY_OVERDUE_WEIGHT
		var total_score: float = distance_score + front_score + overdue_score

		# Vector2(-score, id) — встроенная сортировка, 
		# без lambda, без Dictionary
		_sort_buffer.append(Vector2(-total_score, float(target_id)))

	# Встроенный sort для Vector2: по x (ascending) → по -score = descending
	_sort_buffer.sort()

	var count: int = _sort_buffer.size()
	var ordered: Array = []
	ordered.resize(count)
	for i in range(count):
		ordered[i] = int(_sort_buffer[i].y)

	_priority_target_lists[observer_id] = ordered

	var old_cursor: int = int(_priority_rotating_cursor.get(observer_id, 0))
	var tail_size: int = maxi(count - PRIORITY_ALWAYS_TARGETS, 0)
	if tail_size <= 0:
		_priority_rotating_cursor[observer_id] = 0
	else:
		_priority_rotating_cursor[observer_id] = old_cursor % tail_size

## Inlined version — avoids function call overhead
## Called ~5000 times per AOI pass (100 observers × 50 targets)
func _get_replication_hz_inline(distance: float) -> float:
	if distance <= LOD_NEAR_DISTANCE:
		return LOD_NEAR_HZ
	if distance <= LOD_MID_DISTANCE:
		return LOD_MID_HZ
	if distance <= LOD_FAR_DISTANCE:
		return LOD_FAR_HZ
	return LOD_VERY_FAR_HZ

func _get_priority_replication_targets(observer_id: int) -> Array[int]:
	var result: Array[int] = []

	if observer_id not in _priority_target_lists:
		return result

	var ordered_variant: Variant = _priority_target_lists[observer_id]
	if not (ordered_variant is Array):
		return result

	var ordered: Array = ordered_variant
	if ordered.is_empty():
		return result

	var total: int = ordered.size()
	var always_count := mini(PRIORITY_ALWAYS_TARGETS, total)

	# 1) Всегда берём верхушку самых важных
	for i in range(always_count):
		result.append(int(ordered[i]))

	# 2) Остальных добираем каруселью
	var tail_start := always_count
	var tail_size := total - tail_start
	if tail_size <= 0:
		return result

	var rotating_count := mini(PRIORITY_ROTATING_TARGETS, tail_size)
	var cursor: int = int(_priority_rotating_cursor.get(observer_id, 0))

	for i in range(rotating_count):
		var tail_idx := (cursor + i) % tail_size
		var idx := tail_start + tail_idx
		result.append(int(ordered[idx]))

	_priority_rotating_cursor[observer_id] = (cursor + rotating_count) % tail_size
	return result

func _clear_observer_replication_state(observer_id: int) -> void:
	_visible_targets.erase(observer_id)
	_replication_last_send.erase(observer_id)
	_replication_last_tick.erase(observer_id)
	_priority_target_lists.erase(observer_id)
	_priority_rotating_cursor.erase(observer_id)

func _send_player_enter(observer_id: int, target_id: int) -> void:
	if not _pm.has_player(target_id):
		return

	var data: Dictionary = _pm.get_player_data(target_id)
	var pos: Vector3 = data.get("position", Vector3.ZERO)
	var rot: Vector3 = data.get("rotation", Vector3.ZERO)

	_net.send_to_peer(observer_id, PacketTypes.write_player_joined(target_id, pos, rot))


func _send_player_exit(observer_id: int, target_id: int) -> void:
	_net.send_to_peer(observer_id, PacketTypes.write_player_left(target_id))


# ══════════════════════════════════════════════════
#  SPATIAL GRID
# ══════════════════════════════════════════════════

func _rebuild_spatial_grid() -> void:
	# Вместо clear() + полная перестройка → очищаем содержимое,
	# но переиспользуем верхний уровень структуры
	for world_id in _spatial_cells:
		var world_grid: Dictionary = _spatial_cells[world_id]
		world_grid.clear()
	# НЕ делаем _spatial_cells.clear() — переиспользуем ключи миров
	_peer_cells.clear()

	var ids: Array = _pm.get_all_ids()
	for peer_var in ids:
		var peer_id: int = int(peer_var)

		if not _ready_cache.get(peer_id, false):  # ← cached
			continue

		var world_id: String = _world_cache.get(peer_id, DEFAULT_WORLD_ID)  # ← cached
		var data: Dictionary = _pm.get_player_data(peer_id)
		var pos: Vector3 = data.get("position", Vector3.ZERO)

		var cx: int = floori(pos.x / GRID_CELL_SIZE)
		var cz: int = floori(pos.z / GRID_CELL_SIZE)
		var cell := Vector2i(cx, cz)

		_peer_cells[peer_id] = {
			"world_id": world_id,
			"cell": cell,
		}

		var world_grid: Dictionary
		if world_id in _spatial_cells:
			world_grid = _spatial_cells[world_id]
		else:
			world_grid = {}
			_spatial_cells[world_id] = world_grid

		var bucket: Dictionary
		if cell in world_grid:
			bucket = world_grid[cell]
		else:
			bucket = {}
			world_grid[cell] = bucket

		bucket[peer_id] = true

## Fills _candidate_buffer in-place. No allocation per call.
func _gather_candidate_targets_into(observer_pos: Vector3, world_id: String) -> void:
	_candidate_buffer.clear()

	if world_id not in _spatial_cells:
		return

	var world_grid: Dictionary = _spatial_cells[world_id]
	var cx: int = floori(observer_pos.x / GRID_CELL_SIZE)
	var cz: int = floori(observer_pos.z / GRID_CELL_SIZE)
	var radius_cells: int = _get_cell_query_radius()

	for dz in range(-radius_cells, radius_cells + 1):
		for dx in range(-radius_cells, radius_cells + 1):
			var cell := Vector2i(cx + dx, cz + dz)
			if cell not in world_grid:
				continue
			var bucket: Dictionary = world_grid[cell]
			# Итерация dict напрямую — без .keys() аллокации
			for peer_var in bucket:
				_candidate_buffer[int(peer_var)] = true

func _get_cell_query_radius() -> int:
	return int(ceili(AOI_EXIT_DISTANCE / GRID_CELL_SIZE))


func _world_to_cell(pos: Vector3) -> Vector2i:
	return Vector2i(
		floori(pos.x / GRID_CELL_SIZE),
		floori(pos.z / GRID_CELL_SIZE)
	)

## Оставляем для cold-path (cleanup, spawn, etc.)
func _is_peer_ready_for_replication(peer_id: int) -> bool:
	return _authenticated.get(peer_id, false) and _pm.has_player(peer_id)

func _get_peer_world(peer_id: int) -> String:
	if _world_resolver.is_valid():
		var value: Variant = _world_resolver.call(peer_id)
		if value is String:
			var world_id: String = value
			if world_id != "":
				return world_id
	return DEFAULT_WORLD_ID

func _compute_authoritative_dt(prev_tick: int, new_tick: int) -> float:
	var diff := (new_tick - prev_tick) & 0xFFFF
	if diff == 0 or diff >= 0x8000:
		return 0.0

	# Слишком большие разрывы не даём раздувать velocity.
	diff = mini(diff, 8)

	var tick_rate := float(Engine.physics_ticks_per_second)
	if tick_rate <= 0.0:
		tick_rate = 60.0

	return float(diff) / tick_rate
# ══════════════════════════════════════════════════
#  CLEANUP
# ══════════════════════════════════════════════════

func _cleanup_replication_peer(peer_id: int, notify_exit: bool = false) -> void:
	if peer_id in _peer_cells:
		var peer_info: Dictionary = _peer_cells[peer_id]
		var world_id: String = peer_info.get("world_id", DEFAULT_WORLD_ID)
		var cell: Vector2i = peer_info.get("cell", Vector2i.ZERO)

		if world_id in _spatial_cells:
			var world_grid: Dictionary = _spatial_cells[world_id]
			if cell in world_grid:
				var bucket: Dictionary = world_grid[cell]
				bucket.erase(peer_id)

				if bucket.is_empty():
					world_grid.erase(cell)
				else:
					world_grid[cell] = bucket

				if world_grid.is_empty():
					_spatial_cells.erase(world_id)
				else:
					_spatial_cells[world_id] = world_grid

		_peer_cells.erase(peer_id)

	_visible_targets.erase(peer_id)
	_replication_last_send.erase(peer_id)
	_replication_last_tick.erase(peer_id)
	_authoritative_move_ticks.erase(peer_id)
	_priority_target_lists.erase(peer_id)
	_priority_rotating_cursor.erase(peer_id)
	_authoritative_states.erase(peer_id)

	for observer_var in _visible_targets.keys():
		var observer_id: int = int(observer_var)
		var visible_map: Dictionary = _visible_targets[observer_id]

		if peer_id in visible_map:
			visible_map.erase(peer_id)

			if notify_exit and observer_id != peer_id and _net.get_peer_ids().has(observer_id):
				_send_player_exit(observer_id, peer_id)

		if observer_id in _replication_last_send:
			(_replication_last_send[observer_id] as Dictionary).erase(peer_id)

		if observer_id in _replication_last_tick:
			(_replication_last_tick[observer_id] as Dictionary).erase(peer_id)

func _flush_profile_window() -> void:
	_prof_aoi_passes_ps = _prof_aoi_passes_accum
	_prof_aoi_time_ms_ps = _prof_aoi_time_ms_accum
	_prof_aoi_observers_ps = _prof_aoi_observers_accum
	_prof_candidate_targets_ps = _prof_candidate_targets_accum
	_prof_visible_pairs_ps = _prof_visible_pairs_accum

	_prof_repl_passes_ps = _prof_repl_passes_accum
	_prof_repl_time_ms_ps = _prof_repl_time_ms_accum
	_prof_repl_observers_ps = _prof_repl_observers_accum
	_prof_repl_targets_ps = _prof_repl_targets_accum

	_prof_batch_packets_ps = _prof_batch_packets_accum
	_prof_batch_entries_ps = _prof_batch_entries_accum

	_prof_aoi_passes_accum = 0
	_prof_aoi_time_ms_accum = 0.0
	_prof_aoi_observers_accum = 0
	_prof_candidate_targets_accum = 0
	_prof_visible_pairs_accum = 0

	_prof_repl_passes_accum = 0
	_prof_repl_time_ms_accum = 0.0
	_prof_repl_observers_accum = 0
	_prof_repl_targets_accum = 0

	_prof_batch_packets_accum = 0
	_prof_batch_entries_accum = 0

func get_stats_snapshot() -> Dictionary:
	return {
		# cumulative batch
		"batch_packets_sent_total": _stats_batch_packets_sent_total,
		"batch_entries_sent_total": _stats_batch_entries_sent_total,
		"batch_max_entries_seen": _stats_batch_max_entries_seen,

		# profiling window
		"prof_aoi_passes_ps": _prof_aoi_passes_ps,
		"prof_aoi_time_ms_ps": _prof_aoi_time_ms_ps,
		"prof_aoi_observers_ps": _prof_aoi_observers_ps,
		"prof_candidate_targets_ps": _prof_candidate_targets_ps,
		"prof_visible_pairs_ps": _prof_visible_pairs_ps,

		"prof_repl_passes_ps": _prof_repl_passes_ps,
		"prof_repl_time_ms_ps": _prof_repl_time_ms_ps,
		"prof_repl_observers_ps": _prof_repl_observers_ps,
		"prof_repl_targets_ps": _prof_repl_targets_ps,

		"prof_batch_packets_ps": _prof_batch_packets_ps,
		"prof_batch_entries_ps": _prof_batch_entries_ps,
	}
