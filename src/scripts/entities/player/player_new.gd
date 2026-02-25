extends CharacterBody3D

signal hotbar_changed(active_index)
signal block_count_updated(block_id, count)

@export var mouse_sensitivity: float = 0.002
@export var move_speed: float = 5.0
@export var jump_velocity: float = 4.5
@export var block_use_distance: float = 6.0

@export var camera_node: Camera3D
@export var raycast_node: RayCast3D

# Замените пути на реальные текстуры
var available_blocks: Array = [
	{"id": 1, "name": "Dirt", "icon": preload("res://src/assets/textures/blocks/dirt/dirt.png")},
	{"id": 2, "name": "Stone", "icon": preload("res://src/assets/textures/blocks/stone/stone.png")}
]
var active_block_index: int = 0

var _voxel_tool: VoxelTool

func _ready():
	# Поиск VoxelTerrain
	var terrain = _find_voxel_terrain(get_tree().get_current_scene())
	if terrain:
		_voxel_tool = terrain.get_voxel_tool()
	else:
		push_error("VoxelTerrain не найден! Убедитесь, что он есть в сцене.")

	# Поиск камеры, если не назначена
	if not camera_node:
		camera_node = get_node_or_null("Camera3D")
		if not camera_node:
			push_error("Camera3D не найдена! Назначьте её в инспекторе или назовите узел 'Camera3D'.")

	# Поиск RayCast3D
	if not raycast_node:
		if camera_node:
			raycast_node = camera_node.get_node_or_null("RayCast3D")
		if not raycast_node:
			push_error("RayCast3D не найден! Добавьте его как дочерний узел камеры с именем 'RayCast3D' или назначьте в инспекторе.")
		else:
			raycast_node.target_position = Vector3(0, 0, -block_use_distance)
	else:
		raycast_node.target_position = Vector3(0, 0, -block_use_distance)

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _find_voxel_terrain(node: Node) -> Node:
	if node is VoxelTerrain:
		return node
	for child in node.get_children():
		var found = _find_voxel_terrain(child)
		if found:
			return found
	return null

func _input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		if camera_node:
			camera_node.rotate_x(-event.relative.y * mouse_sensitivity)
			camera_node.rotation.x = clamp(camera_node.rotation.x, -PI/2, PI/2)

	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			active_block_index = (active_block_index - 1 + available_blocks.size()) % available_blocks.size()
			hotbar_changed.emit(active_block_index)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			active_block_index = (active_block_index + 1) % available_blocks.size()
			hotbar_changed.emit(active_block_index)

	if event is InputEventKey and event.pressed and not event.echo:
		var key_index = event.keycode - KEY_1
		if key_index >= 0 and key_index < available_blocks.size():
			active_block_index = key_index
			hotbar_changed.emit(active_block_index)

func _physics_process(delta):
	# Управление блоками (левая/правая кнопка мыши)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_break_block()
	elif Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_place_block()

	# --- ДВИЖЕНИЕ ИГРОКА (как в Minecraft) ---
	# Получаем направление от клавиш WASD (по умолчанию в Godot это "ui_up", "ui_down", "ui_left", "ui_right")
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	# Направление движения относительно поворота игрока (ось Z - вперёд, X - вправо)
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# Горизонтальная скорость
	if direction:
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed)
		velocity.z = move_toward(velocity.z, 0, move_speed)

	# Прыжок
	if is_on_floor() and Input.is_action_just_pressed("ui_accept"):  # Пробел
		velocity.y = jump_velocity

	# Гравитация (Godot автоматически применяет её в CharacterBody3D, если не задано иное)
	# Здесь можно добавить дополнительную гравитацию, но стандартная уже работает

	move_and_slide()

func _break_block():
	if not _voxel_tool or not raycast_node or not raycast_node.is_colliding():
		return

	var hit_point = raycast_node.get_collision_point()
	var block_pos = Vector3i(
		floor(hit_point.x),
		floor(hit_point.y),
		floor(hit_point.z)
	)
	_voxel_tool.set_voxel(block_pos, 0)  # 0 = воздух

func _place_block():
	if not _voxel_tool or not raycast_node or not raycast_node.is_colliding():
		return

	var hit_point = raycast_node.get_collision_point()
	var hit_normal = raycast_node.get_collision_normal()
	var place_pos = hit_point + hit_normal * 0.5
	var block_pos = Vector3i(
		floor(place_pos.x),
		floor(place_pos.y),
		floor(place_pos.z)
	)

	var block_id = available_blocks[active_block_index]["id"]
	_voxel_tool.set_voxel(block_pos, block_id)
