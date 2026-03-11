class_name Player extends CharacterBody3D

@export var move_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var gravity: float = 9.8
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.002

var game_mode: int = 1

@onready var neck: Node3D = $Neck
@onready var camera: Camera3D = $Neck/Camera3D

var inventory_open: bool = false

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	collision_layer = 1
	collision_mask = 3

func set_gamemode(mode: int) -> void:
	game_mode = mode
	match mode:
		0:
			collision_layer = 1; collision_mask = 3; move_speed = 5.0; jump_velocity = 4.5; gravity = 9.8
		1:
			collision_layer = 1; collision_mask = 3; move_speed = 10.0; jump_velocity = 0.0; gravity = 0.0
		2:
			collision_layer = 0; collision_mask = 0; move_speed = 15.0; jump_velocity = 0.0; gravity = 0.0

func kill() -> void:
	if game_mode != 2: global_position.y += 10

func _input(event: InputEvent) -> void:
	if inventory_open or _is_chat_open(): return
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		neck.rotate_x(-event.relative.y * mouse_sensitivity)
		neck.rotation.x = clamp(neck.rotation.x, -PI/2, PI/2)
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	if inventory_open or _is_chat_open(): velocity = Vector3.ZERO; return
	if game_mode == 1 or game_mode == 2: _process_flight(delta); return
	if not is_on_floor(): velocity.y -= gravity * delta
	if Input.is_action_just_pressed("ui_accept") and is_on_floor(): velocity.y = jump_velocity
	_move()

func _process_flight(_delta: float) -> void:
	var vertical_input = 1.0 if Input.is_key_pressed(KEY_SPACE) else (-1.0 if Input.is_key_pressed(KEY_CTRL) else 0.0)
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (transform.basis * Vector3(input_dir.x, vertical_input, input_dir.y)).normalized()
	var current_speed = sprint_speed if Input.is_action_pressed("sprint") else move_speed
	velocity = direction * current_speed if direction else velocity.move_toward(Vector3.ZERO, current_speed)
	move_and_slide()

func _move() -> void:
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var current_speed = sprint_speed if Input.is_action_pressed("sprint") else move_speed
	if direction:
		velocity.x = direction.x * current_speed; velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed); velocity.z = move_toward(velocity.z, 0, current_speed)
	move_and_slide()

func _is_chat_open() -> bool:
	var chat = get_tree().get_first_node_in_group("chat")
	return chat and chat.has_method("is_chat_open") and chat.is_chat_open()

func is_open_inventory() -> bool:
	return inventory_open
