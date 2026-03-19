class_name SinglePlayerFPS
extends BasePlayer

## FPS-контроллер для одиночной игры.
##
## Наследует BasePlayer — полная совместимость с модулями
## (BlockInteraction, HealthComponent и т.д.).
##
## Игрок является авторитетом для самого себя:
## — is_local = true, network_id = 0 (принудительно)
## — Все действия применяются немедленно
## — NAM не требуется: если отсутствует — сетевой код молча пропускается
## — Модули взаимодействия вызывают _send() → _nam == null → return
##
## Сетевой код BasePlayer остаётся в памяти, но никогда
## не выполняется: correction blend видит нули, remote step
## не вызывается, get_network_state() никто не опрашивает.

const SPEED := 5.0
const JUMP_VELOCITY := 4.5
const MOUSE_SENSITIVITY := 0.003

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


# ══════════════════════════════════════════════════
#  LIFECYCLE
# ══════════════════════════════════════════════════

func _ready() -> void:
	# Мы и сервер, и клиент. Устанавливаем ДО super._ready(),
	# чтобы BasePlayer сразу пошёл в ветку _setup_local().
	is_local = true
	network_id = 0
	super._ready()


func _setup_local() -> void:
	super._setup_local()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# _setup_remote() не переопределяем — никогда не вызовется,
# потому что is_local всегда true.


# ══════════════════════════════════════════════════
#  КАМЕРА
# ══════════════════════════════════════════════════

func _apply_mouse_rotation(relative: Vector2) -> void:
	if _head == null:
		return
	rotate_y(-relative.x * MOUSE_SENSITIVITY)
	_head.rotate_x(-relative.y * MOUSE_SENSITIVITY)
	_head.rotation.x = clampf(_head.rotation.x, -1.4, 1.4)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ══════════════════════════════════════════════════
#  ДВИЖЕНИЕ
# ══════════════════════════════════════════════════

func _process_local(delta: float) -> void:
	# Гравитация
	if not is_on_floor():
		velocity.y -= _gravity * delta

	# Прыжок
	if Input.is_key_pressed(KEY_SPACE) and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Направление
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


# _process_remote() не переопределяем — никогда не вызовется.
