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
@export_range(0.05, 0.30, 0.01) var interpolation_back_time: float = 0.12

## Размер буфера снапшотов remote-игрока.
@export_range(2, 64, 1) var max_snapshot_buffer: int = 20

## Если расхождение больше этого порога — телепортируем, а не интерполируем.
@export_range(1.0, 20.0, 0.5) var teleport_distance: float = 6.0

## Когда в буфере остался 1 снапшот и нового ещё нет —
## плавно дотягиваемся к нему.
@export_range(1.0, 30.0, 0.5) var tail_position_lerp_speed: float = 12.0
@export_range(1.0, 30.0, 0.5) var tail_rotation_lerp_speed: float = 14.0

var _net_snapshots: Array[Dictionary] = []
var _net_remote_initialized: bool = false

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


## Настройка для удалённого игрока.
func _setup_remote() -> void:
	if _camera:
		_camera.current = false
	set_process_input(false)
	set_process_unhandled_input(false)
	velocity = Vector3.ZERO
	_net_snapshots.clear()
	_net_remote_initialized = false


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
	# Компоненты обновляются для всех (и локальных, и удалённых)
	for comp in _components:
		comp.process(delta, is_local)

	if is_local:
		_process_local(delta)
	else:
		_network_remote_step(delta)
		_process_remote(delta)


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
	var state := {
		"position": global_position,
		"rotation": Vector3(
			_head.rotation.x if _head else 0.0,
			rotation.y,
			0.0
		),
	}
	for comp in _components:
		state.merge(comp.collect_state())
	return state


## Применить состояние из сети. Вызывается NAM на удалённом игроке.
func apply_network_state(peer_id: int, data: Dictionary) -> void:
	if is_local:
		return

	# Защита от случайной маршрутизации не в ту ноду
	if network_id != 0 and peer_id != network_id:
		return

	_queue_network_snapshot(data)

	# Компонентные состояния можно применять сразу
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
		_net_snapshots.clear()
		_net_remote_initialized = true

# ══════════════════════════════════════════════════
# REMOTE INTERPOLATION
# ══════════════════════════════════════════════════

func _queue_network_snapshot(data: Dictionary) -> void:
	if not data.has("position") and not data.has("body_yaw") and not data.has("head_pitch"):
		return

	var pitch_now := _head.rotation.x if _head else 0.0

	var snap := {
		"time": _net_now(),
		"position": data.get("position", global_position),
		"yaw": data.get("body_yaw", rotation.y),
		"pitch": data.get("head_pitch", pitch_now),
	}

	_net_snapshots.append(snap)

	while _net_snapshots.size() > max_snapshot_buffer:
		_net_snapshots.remove_at(0)


func _network_remote_step(delta: float) -> void:
	if _net_snapshots.is_empty():
		return

	velocity = Vector3.ZERO

	var render_time := _net_now() - interpolation_back_time

	# Выбрасываем старые снапшоты, пока второй уже "позади" render_time
	while _net_snapshots.size() >= 2 and float(_net_snapshots[1]["time"]) <= render_time:
		_net_snapshots.remove_at(0)

	# Если остался только один снапшот — мягко тянемся к нему
	if _net_snapshots.size() == 1:
		var only: Dictionary = _net_snapshots[0]
		_apply_remote_transform(
			only["position"] as Vector3,
			float(only["yaw"]),
			float(only["pitch"]),
			true,
			delta
		)
		return

	# Интерполяция между двумя снапшотами
	var a: Dictionary = _net_snapshots[0]
	var b: Dictionary = _net_snapshots[1]

	var t0 := float(a["time"])
	var t1 := float(b["time"])

	var alpha := 0.0
	if t1 > t0:
		alpha = clampf((render_time - t0) / (t1 - t0), 0.0, 1.0)

	var pos_a: Vector3 = a["position"]
	var pos_b: Vector3 = b["position"]

	var target_pos := pos_a.lerp(pos_b, alpha)
	var target_yaw := lerp_angle(float(a["yaw"]), float(b["yaw"]), alpha)
	var target_pitch := lerp_angle(float(a["pitch"]), float(b["pitch"]), alpha)

	_apply_remote_transform(target_pos, target_yaw, target_pitch, false, delta)


func _apply_remote_transform(
	target_pos: Vector3,
	target_yaw: float,
	target_pitch: float,
	smooth_tail: bool,
	delta: float
) -> void:
	# Первый сетевой снапшот — просто ставим как есть
	if not _net_remote_initialized:
		global_position = target_pos
		rotation.y = target_yaw
		if _head:
			_head.rotation.x = target_pitch
		_net_remote_initialized = true
		return

	# Слишком большое расхождение — считаем телепортом / резкой коррекцией
	if global_position.distance_to(target_pos) >= teleport_distance:
		global_position = target_pos
		rotation.y = target_yaw
		if _head:
			_head.rotation.x = target_pitch
		return

	# Если новых снапшотов нет, но один последний остался —
	# плавно дотягиваемся к нему
	if smooth_tail:
		var pos_alpha := clampf(tail_position_lerp_speed * delta, 0.0, 1.0)
		var rot_alpha := clampf(tail_rotation_lerp_speed * delta, 0.0, 1.0)

		global_position = global_position.lerp(target_pos, pos_alpha)
		rotation.y = lerp_angle(rotation.y, target_yaw, rot_alpha)

		if _head:
			_head.rotation.x = lerp_angle(_head.rotation.x, target_pitch, rot_alpha)
		return

	# Нормальный режим интерполяции: ставим вычисленное интерполированное состояние
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
