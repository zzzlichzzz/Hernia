class_name FPSPlayer
extends BasePlayer

## FPS-контроллер. Наследует BasePlayer.
## Вся сетевая логика — в базовом классе.
## Здесь только ввод и движение.

const SPEED := 5.0
const JUMP_VELOCITY := 4.5
const MOUSE_SENSITIVITY := 0.003
const REACH_DISTANCE := 10.0

#@onready var _camera: RayCast3D = $Neck/Camera3D

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _setup_local() -> void:
	super._setup_local()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _setup_remote() -> void:
	super._setup_remote()


## Поворот камеры — вызывается из BasePlayer._input().
## _input раньше в цепочке чем _unhandled_input → меньше задержки.
func _apply_mouse_rotation(relative: Vector2) -> void:
	rotate_y(-relative.x * MOUSE_SENSITIVITY)
	_head.rotate_x(-relative.y * MOUSE_SENSITIVITY)
	_head.rotation.x = clampf(_head.rotation.x, -1.4, 1.4)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process_local(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta

	if Input.is_key_pressed(KEY_SPACE) and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W): input_dir.y -= 1.0
	if Input.is_key_pressed(KEY_S): input_dir.y += 1.0
	if Input.is_key_pressed(KEY_A): input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D): input_dir.x += 1.0
	input_dir = input_dir.normalized()

	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	if direction != Vector3.ZERO:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)
		velocity.z = move_toward(velocity.z, 0.0, SPEED)

	move_and_slide()


func _process_remote(_delta: float) -> void:
	pass
