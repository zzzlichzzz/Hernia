extends CharacterBody3D

# Скорость движения
@export var move_speed: float = 5.0
# Скорость бега (при удержании Shift)
@export var sprint_speed: float = 8.0
# Сила гравитации
@export var gravity: float = 9.8
# Скорость прыжка
@export var jump_velocity: float = 4.5

# Чувствительность мыши
@export var mouse_sensitivity: float = 0.002

# Режим игры (0=Survival, 1=Creative, 2=Spectator)
var game_mode: int = 1  # По умолчанию Creative

# Ссылки на узлы
@onready var neck: Node3D = $Neck
@onready var camera: Camera3D = $Neck/Camera3D

# Флаг открытого инвентаря (управляется скриптом инвентаря)
var inventory_open: bool = false

func _ready() -> void:
	# Захватываем мышь для управления камерой
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Настраиваем коллизию: слой 1 (террейн) + слой 2 (frame-блоки)
	collision_layer = 1  # Сам игрок на слое 1
	collision_mask = 3  # Проверяем коллизии со слоями 1 и 2

func set_gamemode(mode: int) -> void:
	game_mode = mode
	match mode:
		0:  # Survival
			collision_layer = 1  # Слой 1 - земля
			collision_mask = 3   # Слои 1 и 2
			move_speed = 5.0
			jump_velocity = 4.5
			gravity = 9.8
			print("Game mode: Survival")
		1:  # Creative
			collision_layer = 1  # Слой 1 - земля
			collision_mask = 3   # Слои 1 и 2
			move_speed = 10.0
			jump_velocity = 0.0  # Полёт
			gravity = 0.0  # Нет гравитации
			print("Game mode: Creative")
		2:  # Spectator
			collision_layer = 0  # Нет слоя - проходим сквозь всё
			collision_mask = 0   # Нет маски - нет коллизий
			move_speed = 15.0
			jump_velocity = 0.0
			gravity = 0.0
			print("Game mode: Spectator")

func kill() -> void:
	if game_mode != 2:  # В Spectator нельзя умереть
		global_position.y += 10  # Respawn
		print("Player died and respawned")

func _input(event: InputEvent) -> void:
	# Блокируем ввод если открыт чат или инвентарь
	if inventory_open or _is_chat_open():
		return
	
	# Вращение камеры мышью (только если инвентарь закрыт)
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED and not inventory_open:
		rotate_y(-event.relative.x * mouse_sensitivity)
		neck.rotate_x(-event.relative.y * mouse_sensitivity)
		neck.rotation.x = clamp(neck.rotation.x, -PI/2, PI/2)

	# Нажатие Escape для освобождения мыши
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	# Если инвентарь или чат открыт, не двигаемся и сбрасываем скорость
	if inventory_open or _is_chat_open():
		velocity = Vector3.ZERO
		return

	# Полёт в Creative и Spectator режимах
	if game_mode == 1 or game_mode == 2:
		_process_flight(delta)
		return
	
	# Гравитация
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Прыжок
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity

	# Перемещение
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var current_speed = sprint_speed if Input.is_action_pressed("sprint") else move_speed

	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	move_and_slide()

func _process_flight(delta: float) -> void:
	# Вверх/вниз по Q и E или Space и Ctrl
	var vertical_input = 0.0
	if Input.is_key_pressed(KEY_SPACE):
		vertical_input = 1.0
	elif Input.is_key_pressed(KEY_CTRL):
		vertical_input = -1.0
	
	# Перемещение
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, vertical_input, input_dir.y)).normalized()
	
	var current_speed = sprint_speed if Input.is_action_pressed("sprint") else move_speed
	
	if direction:
		velocity = direction * current_speed
	else:
		velocity = velocity.move_toward(Vector3.ZERO, current_speed)
	
	# Вращение камеры во время полёта
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		pass  # Вращение обрабатывается в _input
	
	move_and_slide()

func _is_chat_open() -> bool:
	# Проверяем открыт ли чат
	var chat = get_tree().get_first_node_in_group("chat")
	if chat and chat.has_method("is_chat_open"):
		return chat.is_chat_open()
	return false
