class_name BotVirtualPlayer
extends Node

## Лёгкий "виртуальный игрок" для нагрузочного теста.
## Не использует сцену персонажа, физику и рендер.
## Только генерирует movement state и принимает correction.

enum Mode {
	IDLE,
	CIRCLE,
	RANDOM_WALK,
}

var network_id: int = 0
var mode: int = Mode.CIRCLE

var move_speed: float = 4.0
var circle_radius: float = 8.0
var circle_angular_speed: float = 0.45

var random_walk_radius: float = 12.0
var random_turn_interval_min: float = 0.8
var random_turn_interval_max: float = 2.5

var movement_start_delay: float = 5.0
var _movement_unlock_time: float = 0.0

var net_idle_keepalive: float = 0.5
var net_pos_quantum: float = 0.02
var net_yaw_quantum: float = 0.01
var net_pitch_quantum: float = 0.01

var correction_hard_distance: float = 2.0
var correction_position_blend_speed: float = 10.0
var correction_rotation_blend_speed: float = 12.0

var _network_tick: int = 0

var _spawn_center: Vector3 = Vector3.ZERO
var _position: Vector3 = Vector3.ZERO
var _body_yaw: float = 0.0
var _head_pitch: float = 0.0

var _circle_angle: float = 0.0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _move_dir: Vector3 = Vector3.FORWARD
var _turn_timer: float = 0.0

var _pending_position_correction: Vector3 = Vector3.ZERO
var _pending_yaw_correction: float = 0.0
var _pending_pitch_correction: float = 0.0


func configure(spawn_position: Vector3, bot_mode: int, seed_value: int = 0) -> void:
	mode = bot_mode
	_body_yaw = 0.0
	_head_pitch = 0.0
	_network_tick = 0

	if seed_value == 0:
		_rng.randomize()
	else:
		_rng.seed = seed_value

	match mode:
		Mode.CIRCLE:
			# Выбираем стартовый угол.
			_circle_angle = _rng.randf_range(-PI, PI)

			# Смещаем центр круга так, чтобы spawn_position уже лежала на окружности.
			var offset := Vector3(
				cos(_circle_angle) * circle_radius,
				0.0,
				sin(_circle_angle) * circle_radius
			)

			_spawn_center = spawn_position - offset
			_position = spawn_position

			var tangent := Vector3(
				-sin(_circle_angle),
				0.0,
				cos(_circle_angle)
			).normalized()
			_body_yaw = _yaw_from_direction(tangent)

		_:
			_spawn_center = spawn_position
			_position = spawn_position
			_circle_angle = 0.0

	_pick_new_random_direction()
	_turn_timer = _rng.randf_range(random_turn_interval_min, random_turn_interval_max)
	_movement_unlock_time = _now() + movement_start_delay + _rng.randf_range(0.0, 1.5)

func _physics_process(delta: float) -> void:
	if _now() < _movement_unlock_time:
		_update_idle(delta)
		_apply_correction_blend(delta)
		return

	match mode:
		Mode.IDLE:
			_update_idle(delta)

		Mode.CIRCLE:
			_update_circle(delta)

		Mode.RANDOM_WALK:
			_update_random_walk(delta)

	_apply_correction_blend(delta)


func get_network_state() -> Dictionary:
	_network_tick = (_network_tick + 1) & 0xFFFF

	var state := {
		"tick": _network_tick,
		"position": _position,
		"rotation": Vector3(_head_pitch, _body_yaw, 0.0),

		# Служебные ключи для NAM idle suppression
		"_net_signature": _build_net_send_signature(_position, _body_yaw, _head_pitch),
		"_net_keepalive": net_idle_keepalive,
	}

	return state


func apply_correction_state(peer_id: int, data: Dictionary) -> void:
	if network_id != 0 and peer_id != network_id:
		return

	if "position" not in data:
		return

	var server_pos: Vector3 = data["position"]
	var server_yaw: float = float(data.get("body_yaw", _body_yaw))
	var server_pitch: float = float(data.get("head_pitch", _head_pitch))

	var pos_delta: Vector3 = server_pos - _position
	var pos_error: float = pos_delta.length()

	var yaw_delta: float = _angle_delta(_body_yaw, server_yaw)
	var pitch_delta: float = _angle_delta(_head_pitch, server_pitch)

	if pos_error >= correction_hard_distance:
		_position = server_pos
		_body_yaw = server_yaw
		_head_pitch = server_pitch
		_pending_position_correction = Vector3.ZERO
		_pending_yaw_correction = 0.0
		_pending_pitch_correction = 0.0
		return

	_pending_position_correction += pos_delta
	_pending_yaw_correction = wrapf(_pending_yaw_correction + yaw_delta, -PI, PI)
	_pending_pitch_correction = wrapf(_pending_pitch_correction + pitch_delta, -PI, PI)


func get_debug_position() -> Vector3:
	return _position


# ══════════════════════════════════════════════════
#  MOVEMENT MODES
# ══════════════════════════════════════════════════

func _update_idle(_delta: float) -> void:
	# Лёгкое движение головой, чтобы в совсем idle-режиме
	# можно было проверить keepalive и слабые update'ы.
	var t: float = float(Time.get_ticks_msec()) * 0.001
	_head_pitch = sin(t * 0.5) * 0.08


func _update_circle(delta: float) -> void:
	_circle_angle = wrapf(_circle_angle + circle_angular_speed * delta, -PI, PI)

	var x := cos(_circle_angle) * circle_radius
	var z := sin(_circle_angle) * circle_radius

	_position = _spawn_center + Vector3(x, 0.0, z)

	var tangent := Vector3(-sin(_circle_angle), 0.0, cos(_circle_angle)).normalized()
	_body_yaw = _yaw_from_direction(tangent)

	var t: float = float(Time.get_ticks_msec()) * 0.001
	_head_pitch = sin(t * 0.9 + float(network_id)) * 0.12


func _update_random_walk(delta: float) -> void:
	_turn_timer -= delta
	if _turn_timer <= 0.0:
		_pick_new_random_direction()
		_turn_timer = _rng.randf_range(random_turn_interval_min, random_turn_interval_max)

	var to_center := _spawn_center - _position
	to_center.y = 0.0

	var desired_dir := _move_dir
	if to_center.length() > random_walk_radius:
		desired_dir = to_center.normalized()

	_position += desired_dir * move_speed * delta
	_position.y = _spawn_center.y

	if desired_dir.length_squared() > 0.0001:
		_body_yaw = _yaw_from_direction(desired_dir)

	var t: float = float(Time.get_ticks_msec()) * 0.001
	_head_pitch = sin(t * 0.7 + float(network_id) * 0.31) * 0.10


func _pick_new_random_direction() -> void:
	var angle := _rng.randf_range(-PI, PI)
	_move_dir = Vector3(sin(angle), 0.0, cos(angle)).normalized()


# ══════════════════════════════════════════════════
#  CORRECTION
# ══════════════════════════════════════════════════

func _apply_correction_blend(delta: float) -> void:
	if _pending_position_correction.length_squared() > 0.0:
		var pos_alpha := clampf(correction_position_blend_speed * delta, 0.0, 1.0)
		var pos_step := _pending_position_correction * pos_alpha
		_position += pos_step
		_pending_position_correction -= pos_step

		if _pending_position_correction.length() <= 0.001:
			_pending_position_correction = Vector3.ZERO

	if absf(_pending_yaw_correction) > 0.0001:
		var yaw_alpha := clampf(correction_rotation_blend_speed * delta, 0.0, 1.0)
		var yaw_step := _pending_yaw_correction * yaw_alpha
		_body_yaw = wrapf(_body_yaw + yaw_step, -PI, PI)
		_pending_yaw_correction = wrapf(_pending_yaw_correction - yaw_step, -PI, PI)

		if absf(_pending_yaw_correction) <= 0.001:
			_pending_yaw_correction = 0.0

	if absf(_pending_pitch_correction) > 0.0001:
		var pitch_alpha := clampf(correction_rotation_blend_speed * delta, 0.0, 1.0)
		var pitch_step := _pending_pitch_correction * pitch_alpha
		_head_pitch += pitch_step
		_pending_pitch_correction = wrapf(_pending_pitch_correction - pitch_step, -PI, PI)

		if absf(_pending_pitch_correction) <= 0.001:
			_pending_pitch_correction = 0.0


# ══════════════════════════════════════════════════
#  HELPERS
# ══════════════════════════════════════════════════

func _yaw_from_direction(dir: Vector3) -> float:
	if dir.length_squared() <= 0.0001:
		return _body_yaw
	return atan2(-dir.x, -dir.z)


func _build_net_send_signature(pos: Vector3, yaw: float, pitch: float) -> String:
	var pyaw := wrapf(yaw, -PI, PI)
	var ppitch := wrapf(pitch, -PI, PI)

	return "%d|%d|%d|%d|%d" % [
		_quantize_for_signature(pos.x, net_pos_quantum),
		_quantize_for_signature(pos.y, net_pos_quantum),
		_quantize_for_signature(pos.z, net_pos_quantum),
		_quantize_for_signature(pyaw, net_yaw_quantum),
		_quantize_for_signature(ppitch, net_pitch_quantum),
	]


func _quantize_for_signature(v: float, step: float) -> int:
	if step <= 0.0:
		return int(round(v * 1000.0))
	return int(round(v / step))


func _angle_delta(from_angle: float, to_angle: float) -> float:
	return wrapf(to_angle - from_angle, -PI, PI)

func _now() -> float:
	return float(Time.get_ticks_msec()) * 0.001
