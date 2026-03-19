class_name BotVirtualPlayer
extends Node

## Лёгкий виртуальный игрок для нагрузочного теста.
## Движение через velocity × delta — совместимо с серверной валидацией.
## Не использует сцену, физику и рендер.

enum Mode {
	IDLE,
	CIRCLE,
	RANDOM_WALK,
}

var network_id: int = 0
var mode: int = Mode.CIRCLE

# ══════════════════════════════════════════════════
#  НАСТРОЙКИ ДВИЖЕНИЯ
# ══════════════════════════════════════════════════

## Общая скорость передвижения (должна быть < v_max_speed в .tres)
var move_speed: float = 4.0

## Круговое движение
var circle_radius: float = 8.0
var circle_angular_speed: float = 0.45

## Случайная ходьба
var random_walk_radius: float = 12.0
var random_turn_interval_min: float = 0.8
var random_turn_interval_max: float = 2.5

## Задержка перед началом движения после спавна
var movement_start_delay: float = 5.0

## Мягкая коррекция к идеальному радиусу круга
## (чтобы бот не уплывал после серверных коррекций)
const CIRCLE_RADIUS_PULL_STRENGTH := 2.0

# ══════════════════════════════════════════════════
#  СЕТЕВЫЕ НАСТРОЙКИ
# ══════════════════════════════════════════════════

var net_idle_keepalive: float = 0.5
var net_pos_quantum: float = 0.02
var net_yaw_quantum: float = 0.01
var net_pitch_quantum: float = 0.01

# ══════════════════════════════════════════════════
#  ВНУТРЕННЕЕ СОСТОЯНИЕ
# ══════════════════════════════════════════════════

var _network_tick: int = 0

var _spawn_center: Vector3 = Vector3.ZERO
var _position: Vector3 = Vector3.ZERO
var _velocity: Vector3 = Vector3.ZERO
var _body_yaw: float = 0.0
var _head_pitch: float = 0.0

## Текущий угол на окружности (вычисляется из позиции, не наоборот)
var _circle_angle: float = 0.0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _move_dir: Vector3 = Vector3.FORWARD
var _turn_timer: float = 0.0

var _movement_unlock_time: float = 0.0

## Integer signature для _net_changed (как в BasePlayer)
var _last_sig_px: int = 0
var _last_sig_py: int = 0
var _last_sig_pz: int = 0
var _last_sig_yaw: int = 0
var _last_sig_pitch: int = 0


func configure(spawn_position: Vector3, bot_mode: int, seed_value: int = 0) -> void:
	mode = bot_mode
	_body_yaw = 0.0
	_head_pitch = 0.0
	_network_tick = 0
	_velocity = Vector3.ZERO

	if seed_value == 0:
		_rng.randomize()
	else:
		_rng.seed = seed_value

	match mode:
		Mode.CIRCLE:
			_circle_angle = _rng.randf_range(-PI, PI)

			# Ставим spawn_center так, чтобы бот начал на окружности
			var offset := Vector3(
				cos(_circle_angle) * circle_radius,
				0.0,
				sin(_circle_angle) * circle_radius
			)
			_spawn_center = spawn_position - offset
			_position = spawn_position

		_:
			_spawn_center = spawn_position
			_position = spawn_position
			_circle_angle = 0.0

	_pick_new_random_direction()
	_turn_timer = _rng.randf_range(random_turn_interval_min, random_turn_interval_max)
	_movement_unlock_time = _now() + movement_start_delay + _rng.randf_range(0.0, 1.5)

	_update_signature_cache()


func _physics_process(delta: float) -> void:
	if _now() < _movement_unlock_time:
		_velocity = Vector3.ZERO
		var t: float = _now()
		_head_pitch = sin(t * 0.5) * 0.08
		return

	match mode:
		Mode.IDLE:
			_update_idle(delta)
		Mode.CIRCLE:
			_update_circle(delta)
		Mode.RANDOM_WALK:
			_update_random_walk(delta)


# ══════════════════════════════════════════════════
#  СЕТЕВОЙ ИНТЕРФЕЙС (вызывается NAM через auto_bind)
# ══════════════════════════════════════════════════

func get_network_state() -> Dictionary:
	_network_tick = (_network_tick + 1) & 0xFFFF

	var sig_px: int = _quantize(_position.x, net_pos_quantum)
	var sig_py: int = _quantize(_position.y, net_pos_quantum)
	var sig_pz: int = _quantize(_position.z, net_pos_quantum)
	var sig_yaw: int = _quantize(wrapf(_body_yaw, -PI, PI), net_yaw_quantum)
	var sig_pitch: int = _quantize(wrapf(_head_pitch, -PI, PI), net_pitch_quantum)

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

	return {
		"tick": _network_tick,
		"position": _position,
		"velocity": _velocity,
		"rotation": Vector3(_head_pitch, _body_yaw, 0.0),
		"_net_changed": changed,
		"_net_keepalive": net_idle_keepalive,
	}


func apply_correction_state(peer_id: int, data: Dictionary) -> void:
	if network_id != 0 and peer_id != network_id:
		return
	if "position" not in data:
		return

	var server_pos: Vector3 = data["position"]
	var server_yaw: float = float(data.get("body_yaw", _body_yaw))
	var server_pitch: float = float(data.get("head_pitch", _head_pitch))

	# ——— Боту не нужен blend — принимаем коррекцию мгновенно ———
	# Это предотвращает цикл "correction → blend → drift → correction"
	# Настоящий клиент с prediction тоже быстро сходится.
	_position = server_pos
	_body_yaw = server_yaw
	_head_pitch = server_pitch

	# ——— Синхронизируем внутреннее состояние с исправленной позицией ———
	if mode == Mode.CIRCLE:
		var rel: Vector3 = _position - _spawn_center
		if rel.length_squared() > 0.01:
			_circle_angle = atan2(rel.z, rel.x)


func get_debug_position() -> Vector3:
	return _position


# ══════════════════════════════════════════════════
#  РЕЖИМЫ ДВИЖЕНИЯ
# ══════════════════════════════════════════════════

func _update_idle(_delta: float) -> void:
	_velocity = Vector3.ZERO
	var t: float = _now()
	_head_pitch = sin(t * 0.5) * 0.08


func _update_circle(delta: float) -> void:
	# 1. Обновляем угол
	_circle_angle = wrapf(_circle_angle + circle_angular_speed * delta, -PI, PI)

	# 2. Вычисляем касательную скорость (всегда перпендикулярна радиусу)
	var tangent_x: float = -sin(_circle_angle)
	var tangent_z: float = cos(_circle_angle)
	var orbital_speed: float = circle_radius * circle_angular_speed

	# 3. Мягкое притяжение к идеальному радиусу
	#    Без этого после коррекции бот может уплыть от круга
	var rel: Vector3 = _position - _spawn_center
	rel.y = 0.0
	var current_radius: float = rel.length()

	var radial_vx: float = 0.0
	var radial_vz: float = 0.0

	if current_radius > 0.01:
		var radius_error: float = circle_radius - current_radius
		var radial_dir_x: float = rel.x / current_radius
		var radial_dir_z: float = rel.z / current_radius
		var pull: float = radius_error * CIRCLE_RADIUS_PULL_STRENGTH
		radial_vx = radial_dir_x * pull
		radial_vz = radial_dir_z * pull

	# 4. Итоговая скорость = касательная + радиальная коррекция
	_velocity.x = tangent_x * orbital_speed + radial_vx
	_velocity.y = 0.0
	_velocity.z = tangent_z * orbital_speed + radial_vz

	# 5. Двигаемся через velocity × delta (совместимо с серверной валидацией)
	_position += _velocity * delta
	_position.y = _spawn_center.y

	# 6. Направление взгляда по касательной
	_body_yaw = atan2(-tangent_x, -tangent_z)

	# 7. Лёгкое покачивание головы
	var t: float = _now()
	_head_pitch = sin(t * 0.9 + float(network_id)) * 0.12


func _update_random_walk(delta: float) -> void:
	_turn_timer -= delta
	if _turn_timer <= 0.0:
		_pick_new_random_direction()
		_turn_timer = _rng.randf_range(random_turn_interval_min, random_turn_interval_max)

	# Проверяем расстояние до центра (без sqrt)
	var to_center := _spawn_center - _position
	to_center.y = 0.0

	var desired_dir := _move_dir
	var dist_sq: float = to_center.length_squared()
	if dist_sq > random_walk_radius * random_walk_radius:
		# Вышли за радиус — плавно возвращаемся к центру
		var dist: float = sqrt(dist_sq)
		var center_dir: Vector3 = to_center / dist

		# Смешиваем текущее направление с направлением к центру
		var overshoot_factor: float = clampf(
			(dist - random_walk_radius) / random_walk_radius, 0.0, 1.0
		)
		desired_dir = _move_dir.lerp(center_dir, overshoot_factor).normalized()

	_velocity = desired_dir * move_speed
	_position += _velocity * delta
	_position.y = _spawn_center.y

	if desired_dir.length_squared() > 0.0001:
		_body_yaw = atan2(-desired_dir.x, -desired_dir.z)

	var t: float = _now()
	_head_pitch = sin(t * 0.7 + float(network_id) * 0.31) * 0.10


func _pick_new_random_direction() -> void:
	var angle := _rng.randf_range(-PI, PI)
	_move_dir = Vector3(sin(angle), 0.0, cos(angle))


# ══════════════════════════════════════════════════
#  УТИЛИТЫ
# ══════════════════════════════════════════════════

func _update_signature_cache() -> void:
	_last_sig_px = _quantize(_position.x, net_pos_quantum)
	_last_sig_py = _quantize(_position.y, net_pos_quantum)
	_last_sig_pz = _quantize(_position.z, net_pos_quantum)
	_last_sig_yaw = _quantize(_body_yaw, net_yaw_quantum)
	_last_sig_pitch = _quantize(_head_pitch, net_pitch_quantum)


func _quantize(v: float, step: float) -> int:
	if step <= 0.0:
		return int(round(v * 1000.0))
	return int(round(v / step))


func _now() -> float:
	return float(Time.get_ticks_msec()) * 0.001
