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

# Ссылки на узлы
@onready var neck: Node3D = $Neck
@onready var camera: Camera3D = $Neck/Camera3D

func _ready() -> void:
	# Захватываем мышь для управления камерой
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Настраиваем коллизию: слой 1 (террейн) + слой 2 (frame-блоки)
	collision_layer = 1  # Сам игрок на слое 1
	collision_mask = 3  # Проверяем коллизии со слоями 1 и 2

func _input(event: InputEvent) -> void:
	# Вращение камеры мышью
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		# Поворот влево-вправо (вокруг оси Y)
		rotate_y(-event.relative.x * mouse_sensitivity)
		# Поворот вверх-вниз (вокруг оси X узла Neck)
		neck.rotate_x(-event.relative.y * mouse_sensitivity)
		# Ограничиваем поворот вверх-вниз, чтобы не перевернуться
		neck.rotation.x = clamp(neck.rotation.x, -PI/2, PI/2)

	# Нажатие Escape для освобождения мыши
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	# --- Гравитация ---
	if not is_on_floor():
		velocity.y -= gravity * delta

	# --- Прыжок ---
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity

	# --- Перемещение ---
	# Получаем вектор ввода (WASD)
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	# Создаем базис направления из поворота игрока (игнорируем поворот камеры вверх-вниз)
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# Выбор скорости: бег или ходьба
	var current_speed = sprint_speed if Input.is_action_pressed("sprint") else move_speed

	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		# Плавная остановка
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	move_and_slide()
