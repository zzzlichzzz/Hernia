extends CharacterBody3D
## Локальный игрок. FPS-контроллер.

const SPEED            := 5.0
const JUMP_VELOCITY    := 4.5
const MOUSE_SENSITIVITY := 0.003

@onready var _head: Node3D = $Head

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

## Сетевой ID (устанавливается извне после WELCOME)
var network_id: int = 0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		_head.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		_head.rotation.x = clampf(_head.rotation.x, -1.4, 1.4)

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
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


## ═══ СЕТЕВОЙ ИНТЕРФЕЙС ═══
## Возвращает Dictionary с ключами, совпадающими
## с source_key в .tres полях.
## NAM вызывает автоматически.
func get_network_state() -> Dictionary:
	return {
		"position": global_position,
		"rotation": Vector3(_head.rotation.x, rotation.y, 0.0),
	}
