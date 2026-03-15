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
	# _input обрабатывается всегда для локального
	set_process_input(true)
	set_process_unhandled_input(true)


## Настройка для удалённого игрока.
func _setup_remote() -> void:
	if _camera:
		_camera.current = false
	set_process_input(false)
	set_process_unhandled_input(false)


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
		_process_remote(delta)
	


## Логика локального игрока. Переопределяется в наследниках.
func _process_local(_delta: float) -> void:
	pass


## Логика удалённого игрока (интерполяция и т.д.). Переопределяется в наследниках.
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
	if "position" in data:
		global_position = data["position"]
	if "body_yaw" in data:
		rotation.y = data["body_yaw"]
	if "head_pitch" in data and _head:
		_head.rotation.x = data["head_pitch"]
	for comp in _components:
		comp.apply_state(data)


## Обновить позицию/поворот напрямую. Вызывается PlayerManager.
func update_state(pos: Vector3, rot: Vector3) -> void:
	global_position = pos
	rotation.y = rot.y
	if _head:
		_head.rotation.x = rot.x

# ══════════════════════════════════════════════════
# БЫСТРЫЙ ДОСТУП К ЗДОРОВЬЮ
# ══════════════════════════════════════════════════

func get_health() -> HealthComponent:
	return get_component(HealthComponent) as HealthComponent
