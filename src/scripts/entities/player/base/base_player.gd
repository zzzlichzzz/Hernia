class_name BasePlayer
extends CharacterBody3D

## Базовый игрок. Содержит сетевой интерфейс, систему компонентов,
## управление камерой. Наследники добавляют конкретное поведение
## (движение, ввод) — сетевой код писать НЕ нужно.
##
## is_local = true  → обрабатывает ввод, камера активна, NAM собирает состояние
## is_local = false → принимает данные из сети, камера выключена

# ══════════════════════════════════════════════════
# СВОЙСТВА
# ══════════════════════════════════════════════════

var is_local: bool = false ## Локальный ли это игрок. Устанавливать ДО add_child().
var inventory_open: bool = false ## Открыт/закрыт инвентарь

## Сетевой ID (peer_id). Устанавливать ДО add_child().
var network_id: int = 0

# ══════════════════════════════════════════════════
# NETWORK SMOOTHING
# ══════════════════════════════════════════════════

## Насколько "назад во времени" рисуем удалённых игроков.
## Для 20 Hz и MMO-пинга 100-150ms хороший старт: 0.12 - 0.15
@export_range(0.05, 0.30, 0.01) var interpolation_back_time: float = 0.20

@export_range(0.0, 0.50, 0.01) var remote_extrapolation_limit: float = 0.15
## Размер буфера снапшотов remote-игрока.
@export_range(2, 64, 1) var max_snapshot_buffer: int = 20

## Если расхождение больше этого порога — телепортируем, а не интерполируем.
@export_range(1.0, 20.0, 0.5) var teleport_distance: float = 6.0

## Когда в буфере остался 1 снапшот и нового ещё нет —
## плавно дотягиваемся к нему.
@export_range(1.0, 30.0, 0.5) var tail_position_lerp_speed: float = 12.0
@export_range(1.0, 30.0, 0.5) var tail_rotation_lerp_speed: float = 14.0

var _net_snapshots: Array[Dictionary] = []
var _net_snap_start: int = 0  ## Логическое начало кольцевого буфера
var _net_snap_count: int = 0  ## Количество валидных снапшотов
var _net_remote_initialized: bool = false

## Предыдущая "подпись" состояния для skip-send оптимизации
## Используем 5 int вместо String
var _last_sig_px: int = 0
var _last_sig_py: int = 0
var _last_sig_pz: int = 0
var _last_sig_yaw: int = 0
var _last_sig_pitch: int = 0
var _last_send_time: float = 0.0

## Ring buffer для local prediction history
var _local_hist_ring: Array[Dictionary] = []
var _local_hist_ticks: Array[int] = []
var _local_hist_start: int = 0
var _local_hist_count: int = 0

var _network_tick: int = 0
var _last_received_tick: int = -1

@export_range(16, 256, 1) var max_local_history: int = 64
@export_range(0.01, 0.50, 0.01) var correction_ignore_distance: float = 0.08
@export_range(0.001, 0.50, 0.001) var correction_ignore_angle: float = 0.02
@export_range(0.10, 10.0, 0.05) var correction_hard_distance: float = 2.0
@export_range(1.0, 30.0, 0.5) var correction_position_blend_speed: float = 14.0
@export_range(1.0, 30.0, 0.5) var correction_rotation_blend_speed: float = 16.0

@export_group("Network Send Optimization")
@export_range(0.001, 0.5, 0.001) var net_pos_quantum: float = 0.02
@export_range(0.001, 0.2, 0.001) var net_yaw_quantum: float = 0.01
@export_range(0.001, 0.2, 0.001) var net_pitch_quantum: float = 0.01
@export_range(0.05, 2.0, 0.01) var net_idle_keepalive: float = 0.5

var _pending_position_correction: Vector3 = Vector3.ZERO
var _pending_yaw_correction: float = 0.0
var _pending_pitch_correction: float = 0.0
var _last_correction_tick: int = -1

# ══════════════════════════════════════════════════
# NETWORK SMOOTHING — ring buffer approach
# ══════════════════════════════════════════════════


# ══════════════════════════════════════════════════
# КОМПОНЕНТЫ (ECS)
# ══════════════════════════════════════════════════

var _components: Array[PlayerComponent] = []

# ══════════════════════════════════════════════════
# НОДЫ
# ══════════════════════════════════════════════════

var _head: Node3D = null
var _camera: Camera3D = null

# ══════════════════════════════════════════════════
# LIFECYCLE
# ══════════════════════════════════════════════════

func _ready() -> void:
	_head = get_node_or_null("Neck")
	_camera = get_node_or_null("Neck/Camera3D")

	_register_components()

	# Предаллоцируем буферы
	_net_snapshots.resize(max_snapshot_buffer)
	for i in max_snapshot_buffer:
		_net_snapshots[i] = {}

	_local_hist_ring.resize(max_local_history)
	_local_hist_ticks.resize(max_local_history)
	for i in max_local_history:
		_local_hist_ring[i] = {}
		_local_hist_ticks[i] = -1

	if is_local:
		_setup_local()
	else:
		_setup_remote()


## Регистрация компонентов. Наследники вызывают super() и добавляют свои.
func _register_components() -> void:
	add_component(HealthComponent.new())


## Настройка для локального игрока.
func _setup_local() -> void:
	if _camera:
		_camera.current = true
	set_process_input(true)
	set_process_unhandled_input(true)

	_network_tick = 0
	_last_correction_tick = -1
	
	# Ring buffer reset
	_local_hist_start = 0
	_local_hist_count = 0
	for i in max_local_history:
		_local_hist_ticks[i] = -1
	
	_pending_position_correction = Vector3.ZERO
	_pending_yaw_correction = 0.0
	_pending_pitch_correction = 0.0
	
	_last_sig_px = 0
	_last_sig_py = 0
	_last_sig_pz = 0
	_last_sig_yaw = 0
	_last_sig_pitch = 0


func _setup_remote() -> void:
	if _camera:
		_camera.current = false
	set_process_input(false)
	set_process_unhandled_input(false)
	velocity = Vector3.ZERO
	
	# Ring buffer reset
	_net_snap_start = 0
	_net_snap_count = 0
	_net_remote_initialized = false
	_last_received_tick = -1


## Обработка мыши — _input вызывается РАНЬШЕ _unhandled_input,
## раньше Control-нод, минимальная задержка.
func _input(event: InputEvent) -> void:
	if not is_local:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_apply_mouse_rotation(event.relative)
		get_viewport().set_input_as_handled()


## Применить поворот мыши. Выделено в метод для переопределения.
func _apply_mouse_rotation(relative: Vector2) -> void:
	pass  # Наследники реализуют конкретную чувствительность


func _physics_process(delta: float) -> void:
	for comp in _components:
		comp.process(delta, is_local)

	if is_local:
		_process_local(delta)
		_apply_local_correction_blend(delta)
	else:
		# Убираем _network_remote_step отсюда!
		# Физику для remote не считаем
		_process_remote(delta)

func _process(delta: float) -> void:
	if not is_local:
		# Визуальная интерполяция в _process — привязана к render frame
		_network_remote_step(delta)

## Логика локального игрока. Переопределяется в наследниках.
func _process_local(_delta: float) -> void:
	pass


## Доп. логика удалённого игрока (анимации, эффекты и т.д.).
## Сетевая интерполяция уже выполняется в BasePlayer.
func _process_remote(_delta: float) -> void:
	pass

# ══════════════════════════════════════════════════
# СИСТЕМА КОМПОНЕНТОВ
# ══════════════════════════════════════════════════

func add_component(comp: PlayerComponent) -> void:
	comp.setup(self)
	_components.append(comp)


## Получить компонент по типу. Возвращает null если нет.
func get_component(type: Variant) -> PlayerComponent:
	for comp in _components:
		if is_instance_of(comp, type):
			return comp
	return null


## Проверить наличие компонента.
func has_component(type: Variant) -> bool:
	return get_component(type) != null

# ══════════════════════════════════════════════════
# СЕТЕВОЙ ИНТЕРФЕЙС
# ══════════════════════════════════════════════════

## Собрать состояние для отправки. Вызывается NAM на локальном игроке.
func get_network_state() -> Dictionary:
	_network_tick = (_network_tick + 1) & 0xFFFF

	var pitch: float = _head.rotation.x if _head else 0.0
	var yaw: float = rotation.y
	var pos: Vector3 = global_position
	var vel: Vector3 = velocity

	var state := {
		"tick": _network_tick,
		"position": pos,
		"velocity": vel,
		"rotation": Vector3(pitch, yaw, 0.0),
	}

	_store_local_prediction(_network_tick, pos, yaw, pitch)

	for comp in _components:
		state.merge(comp.collect_state())

	# ——— Integer signature (без String аллокации) ———
	var sig_px: int = _quantize_for_signature(pos.x, net_pos_quantum)
	var sig_py: int = _quantize_for_signature(pos.y, net_pos_quantum)
	var sig_pz: int = _quantize_for_signature(pos.z, net_pos_quantum)
	var sig_yaw: int = _quantize_for_signature(wrapf(yaw, -PI, PI), net_yaw_quantum)
	var sig_pitch: int = _quantize_for_signature(wrapf(pitch, -PI, PI), net_pitch_quantum)

	var changed: bool = (
		sig_px != _last_sig_px or sig_py != _last_sig_py or
		sig_pz != _last_sig_pz or sig_yaw != _last_sig_yaw or
		sig_pitch != _last_sig_pitch
	)

	if changed:
		_last_sig_px = sig_px
		_last_sig_py = sig_py
		_last_sig_pz = sig_pz
		_last_sig_yaw = sig_yaw
		_last_sig_pitch = sig_pitch

	state["_net_changed"] = changed
	state["_net_keepalive"] = net_idle_keepalive

	return state


## Применить состояние из сети. Вызывается NAM на удалённом игроке.
func apply_network_state(peer_id: int, data: Dictionary) -> void:
	if is_local:
		return

	# Защита от случайной маршрутизации не в ту ноду
	if network_id != 0 and peer_id != network_id:
		return

	if "tick" in data:
		var pkt_tick := int(data["tick"])
		if not _accept_remote_tick(pkt_tick):
			return

	_queue_network_snapshot(data)

	for comp in _components:
		comp.apply_state(data)


## Обновить позицию/поворот напрямую. Вызывается PlayerManager.
## Используется для первичного спавна / жёсткого обновления.
func update_state(pos: Vector3, rot: Vector3) -> void:
	global_position = pos
	rotation.y = rot.y
	if _head:
		_head.rotation.x = rot.x

	if not is_local:
		velocity = Vector3.ZERO
		_net_snap_start = 0
		_net_snap_count = 0
		_net_remote_initialized = true
		_last_received_tick = -1

func apply_correction_state(peer_id: int, data: Dictionary) -> void:
	if not is_local:
		return

	var target_id: int = int(data.get("peer_id", peer_id))
	if network_id != 0 and target_id != network_id:
		return

	if "tick" not in data or "position" not in data:
		return

	var tick: int = int(data["tick"]) & 0xFFFF
	if not _accept_correction_tick(tick):
		return

	var server_pos: Vector3 = data["position"]
	var server_yaw: float = float(data.get("body_yaw", rotation.y))
	var server_pitch: float = float(data.get("head_pitch", _head.rotation.x if _head else 0.0))

	var predicted_pos: Vector3 = global_position
	var predicted_yaw: float = rotation.y
	var predicted_pitch: float = _head.rotation.x if _head else 0.0

	# ——— Ищем в ring buffer вместо Dictionary ———
	var hist: Dictionary = _find_local_prediction(tick)
	if not hist.is_empty():
		predicted_pos = hist["position"]
		predicted_yaw = float(hist["yaw"])
		predicted_pitch = float(hist["pitch"])

	var pos_delta: Vector3 = server_pos - predicted_pos
	var yaw_delta: float = _angle_delta(predicted_yaw, server_yaw)
	var pitch_delta: float = _angle_delta(predicted_pitch, server_pitch)

	var pos_error: float = pos_delta.length()
	var angle_error: float = maxf(absf(yaw_delta), absf(pitch_delta))

	_drop_local_history_through(tick)

	if pos_error <= correction_ignore_distance and angle_error <= correction_ignore_angle:
		return

	if pos_error >= correction_hard_distance:
		global_position += pos_delta
		rotation.y = wrapf(rotation.y + yaw_delta, -PI, PI)
		if _head:
			_head.rotation.x += pitch_delta
		_pending_position_correction = Vector3.ZERO
		_pending_yaw_correction = 0.0
		_pending_pitch_correction = 0.0
		return

	_pending_position_correction += pos_delta
	_pending_yaw_correction = wrapf(_pending_yaw_correction + yaw_delta, -PI, PI)
	_pending_pitch_correction = wrapf(_pending_pitch_correction + pitch_delta, -PI, PI)

func _store_local_prediction(tick: int, pos: Vector3, yaw: float, pitch: float) -> void:
	var idx: int
	if _local_hist_count < max_local_history:
		idx = (_local_hist_start + _local_hist_count) % max_local_history
		_local_hist_count += 1
	else:
		# Буфер полон — перезаписываем самый старый
		idx = _local_hist_start
		_local_hist_start = (_local_hist_start + 1) % max_local_history

	# Переиспользуем Dictionary
	var entry: Dictionary = _local_hist_ring[idx]
	entry["position"] = pos
	entry["yaw"] = yaw
	entry["pitch"] = pitch
	_local_hist_ticks[idx] = tick


func _drop_local_history_through(tick: int) -> void:
	# Удаляем с начала все тики <= tick
	while _local_hist_count > 0:
		var front_idx: int = _local_hist_start
		var front_tick: int = _local_hist_ticks[front_idx]
		if front_tick < 0 or not _is_older_or_equal_u16(front_tick, tick):
			break
		_local_hist_ticks[front_idx] = -1
		_local_hist_start = (_local_hist_start + 1) % max_local_history
		_local_hist_count -= 1

## Найти prediction по tick в ring buffer
func _find_local_prediction(tick: int) -> Dictionary:
	for i in range(_local_hist_count):
		var idx: int = (_local_hist_start + i) % max_local_history
		if _local_hist_ticks[idx] == tick:
			return _local_hist_ring[idx]
	return {}

func _apply_local_correction_blend(delta: float) -> void:
	if _pending_position_correction.length_squared() > 0.0:
		var pos_alpha := clampf(correction_position_blend_speed * delta, 0.0, 1.0)
		var pos_step := _pending_position_correction * pos_alpha
		global_position += pos_step
		_pending_position_correction -= pos_step

		if _pending_position_correction.length() <= 0.001:
			_pending_position_correction = Vector3.ZERO

	if absf(_pending_yaw_correction) > 0.0001:
		var yaw_alpha := clampf(correction_rotation_blend_speed * delta, 0.0, 1.0)
		var yaw_step := _pending_yaw_correction * yaw_alpha
		rotation.y = wrapf(rotation.y + yaw_step, -PI, PI)
		_pending_yaw_correction = wrapf(_pending_yaw_correction - yaw_step, -PI, PI)

		if absf(_pending_yaw_correction) <= 0.001:
			_pending_yaw_correction = 0.0

	if _head and absf(_pending_pitch_correction) > 0.0001:
		var pitch_alpha := clampf(correction_rotation_blend_speed * delta, 0.0, 1.0)
		var pitch_step := _pending_pitch_correction * pitch_alpha
		_head.rotation.x += pitch_step
		_pending_pitch_correction = wrapf(_pending_pitch_correction - pitch_step, -PI, PI)

		if absf(_pending_pitch_correction) <= 0.001:
			_pending_pitch_correction = 0.0


func _accept_correction_tick(new_tick: int) -> bool:
	var tick := new_tick & 0xFFFF

	if _last_correction_tick == -1:
		_last_correction_tick = tick
		return true

	if not _is_newer_u16(tick, _last_correction_tick):
		return false

	_last_correction_tick = tick
	return true

func _is_older_or_equal_u16(value: int, reference: int) -> bool:
	var diff := (reference - value) & 0xFFFF
	return diff < 0x8000

func _angle_delta(from_angle: float, to_angle: float) -> float:
	return wrapf(to_angle - from_angle, -PI, PI)
# ══════════════════════════════════════════════════
# REMOTE INTERPOLATION
# ══════════════════════════════════════════════════

## Добавить снапшот в кольцевой буфер (без аллокации Dictionary)
func _push_snapshot(time: float, pos: Vector3, vel: Vector3, 
					 yaw: float, pitch: float) -> void:
	if _net_snap_count >= max_snapshot_buffer:
		# Буфер полон — перезаписываем самый старый
		_net_snap_start = (_net_snap_start + 1) % max_snapshot_buffer
		_net_snap_count -= 1

	var idx: int = (_net_snap_start + _net_snap_count) % max_snapshot_buffer
	
	# Переиспользуем предаллоцированный Dictionary
	var snap: Dictionary = _net_snapshots[idx]
	snap["time"] = time
	snap["position"] = pos
	snap["velocity"] = vel
	snap["yaw"] = yaw
	snap["pitch"] = pitch

	_net_snap_count += 1


## Получить снапшот по логическому индексу (0 = самый старый)
func _get_snapshot(logical_idx: int) -> Dictionary:
	var real_idx: int = (_net_snap_start + logical_idx) % max_snapshot_buffer
	return _net_snapshots[real_idx]


## Удалить N самых старых снапшотов (без сдвига массива)
func _trim_snapshots_front(n: int) -> void:
	if n <= 0:
		return
	if n >= _net_snap_count:
		_net_snap_count = 0
		_net_snap_start = 0
		return
	_net_snap_start = (_net_snap_start + n) % max_snapshot_buffer
	_net_snap_count -= n

func _queue_network_snapshot(data: Dictionary) -> void:
	if not data.has("position") and not data.has("body_yaw") and not data.has("head_pitch"):
		return

	var pitch_now: float = _head.rotation.x if _head else 0.0
	var vel := Vector3.ZERO
	if "velocity" in data and data["velocity"] is Vector3:
		vel = data["velocity"]

	_push_snapshot(
		_net_now(),
		data.get("position", global_position),
		vel,
		float(data.get("body_yaw", rotation.y)),
		float(data.get("head_pitch", pitch_now))
	)

func _accept_remote_tick(new_tick: int) -> bool:
	var tick := new_tick & 0xFFFF

	if _last_received_tick == -1:
		_last_received_tick = tick
		return true

	if not _is_newer_u16(tick, _last_received_tick):
		return false

	_last_received_tick = tick
	return true


func _is_newer_u16(new_tick: int, old_tick: int) -> bool:
	var diff := (new_tick - old_tick) & 0xFFFF
	return diff != 0 and diff < 0x8000

func _quantize_for_signature(v: float, step: float) -> int:
	if step <= 0.0:
		return int(round(v * 1000.0))
	return int(round(v / step))

func _network_remote_step(delta: float) -> void:
	if _net_snap_count == 0:
		return

	velocity = Vector3.ZERO
	var render_time: float = _net_now() - interpolation_back_time

	# ——— Trim old snapshots: найти сколько удалить за один проход ———
	var trim_count: int = 0
	# Оставляем минимум 1 снапшот перед render_time
	while trim_count < _net_snap_count - 1:
		var next_idx: int = trim_count + 1
		var next_snap: Dictionary = _get_snapshot(next_idx)
		if float(next_snap["time"]) > render_time:
			break
		trim_count += 1

	if trim_count > 0:
		_trim_snapshots_front(trim_count)

	# ——— Один снапшот: экстраполяция + плавное подтягивание ———
	if _net_snap_count == 1:
		var only: Dictionary = _get_snapshot(0)

		var target_pos: Vector3 = only["position"]
		var target_yaw: float = float(only["yaw"])
		var target_pitch: float = float(only["pitch"])
		var target_vel: Vector3 = only.get("velocity", Vector3.ZERO)

		var time_since: float = render_time - float(only["time"])
		if time_since > 0.0 and time_since <= remote_extrapolation_limit:
			target_pos = target_pos + target_vel * time_since

		_apply_remote_transform(
			target_pos,
			target_yaw,
			target_pitch,
			true,
			delta
		)
		return

	# ——— Два+ снапшота: интерполяция ———
	var a: Dictionary = _get_snapshot(0)
	var b: Dictionary = _get_snapshot(1)

	var t0: float = float(a["time"])
	var t1: float = float(b["time"])

	var alpha: float = 0.0
	if t1 > t0:
		alpha = clampf((render_time - t0) / (t1 - t0), 0.0, 1.0)

	var pos_a: Vector3 = a["position"]
	var pos_b: Vector3 = b["position"]

	var target_pos: Vector3 = pos_a.lerp(pos_b, alpha)
	var target_yaw: float = lerp_angle(float(a["yaw"]), float(b["yaw"]), alpha)
	var target_pitch: float = lerp_angle(float(a["pitch"]), float(b["pitch"]), alpha)

	_apply_remote_transform(target_pos, target_yaw, target_pitch, false, delta)


func _apply_remote_transform(
	target_pos: Vector3,
	target_yaw: float,
	target_pitch: float,
	smooth_tail: bool,
	delta: float
) -> void:
	if not _net_remote_initialized:
		global_position = target_pos
		rotation.y = target_yaw
		if _head:
			_head.rotation.x = target_pitch
		_net_remote_initialized = true
		return

	# ——— distance_squared вместо distance_to (убираем sqrt) ———
	var tp_dist_sq: float = teleport_distance * teleport_distance
	var dx: float = global_position.x - target_pos.x
	var dy: float = global_position.y - target_pos.y
	var dz: float = global_position.z - target_pos.z
	if (dx * dx + dy * dy + dz * dz) >= tp_dist_sq:
		global_position = target_pos
		rotation.y = target_yaw
		if _head:
			_head.rotation.x = target_pitch
		return

	if smooth_tail:
		var pos_alpha: float = clampf(tail_position_lerp_speed * delta, 0.0, 1.0)
		var rot_alpha: float = clampf(tail_rotation_lerp_speed * delta, 0.0, 1.0)

		global_position = global_position.lerp(target_pos, pos_alpha)
		rotation.y = lerp_angle(rotation.y, target_yaw, rot_alpha)

		if _head:
			_head.rotation.x = lerp_angle(_head.rotation.x, target_pitch, rot_alpha)
		return

	global_position = target_pos
	rotation.y = target_yaw
	if _head:
		_head.rotation.x = target_pitch


func _net_now() -> float:
	return float(Time.get_ticks_msec()) * 0.001

# ══════════════════════════════════════════════════
# БЫСТРЫЙ ДОСТУП К ЗДОРОВЬЮ
# ══════════════════════════════════════════════════

func get_health() -> HealthComponent:
	return get_component(HealthComponent) as HealthComponent
