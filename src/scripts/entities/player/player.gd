class_name Player extends CharacterBody3D

@export var move_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var gravity: float = 9.8
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.002
@export var reach_distance: float = 10.0

var game_mode: int = 1


@onready var neck: Node3D = $Neck
@onready var camera: Camera3D = $Neck/Camera3D
@onready var _raycast: RayCast3D = get_node("../Neck/Camera3D/RayCast3D")

var inventory_open: bool = false
var _terrain: VoxelTerrain = null
var _terrain_tool: VoxelTool = null
var _voxel_size: float = 1.0

var _is_local: bool = true
var _network_id: int = 0
var _nam: NetworkActionManager = null

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	collision_layer = 1
	collision_mask = 3
	_find_and_setup_terrain()
	_setup_network()
	

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


func _find_and_setup_terrain() -> bool:
	var current_scene = get_tree().current_scene
	if current_scene:
		_terrain = _find_terrain_recursive(current_scene)
		if _terrain:
			_setup_terrain_tool()
			return true

	_terrain = _find_terrain_in_tree()
	if _terrain:
		_setup_terrain_tool()
		return true

	var parent = get_parent()
	while parent:
		if parent is VoxelTerrain:
			_terrain = parent
			_setup_terrain_tool()
			return true
		parent = parent.get_parent()

	push_warning("❌ VoxelTerrain не найден!")
	return false
	
func _find_terrain_recursive(node: Node) -> VoxelTerrain:
	if node is VoxelTerrain:
		return node
	for child in node.get_children():
		var found = _find_terrain_recursive(child)
		if found:
			return found
	return null
	
func _setup_terrain_tool():
	if _terrain == null:
		return

	_terrain_tool = _terrain.get_voxel_tool()
	_terrain_tool.channel = VoxelBuffer.CHANNEL_TYPE
	_terrain_tool.mode = VoxelTool.MODE_SET
	_voxel_size = 1.0
	if _raycast:
		_raycast.target_position = Vector3(0, 0, -reach_distance)

	var cham = ChameleonManager.get_instance()
	if cham:
		cham.connect_to_terrain(_terrain)

	print("✅ Terrain найден: ", _terrain.name)
	#terrain_found.emit(_terrain)

func _find_terrain_in_tree() -> VoxelTerrain:
	var nodes = get_tree().get_nodes_in_group("voxel_terrain")
	if nodes.size() > 0:
		return nodes[0]
	for node in get_tree().get_root().get_children():
		var terrain = _find_terrain_recursive(node)
		if terrain:
			return terrain
	return null





func _is_chat_open() -> bool:
	var chat = get_tree().get_first_node_in_group("chat")
	return chat and chat.has_method("is_chat_open") and chat.is_chat_open()

func is_open_inventory() -> bool:
	return inventory_open
	
	
func _setup_network() -> void:
	var parent = get_parent()

	if parent is BasePlayer:
		_is_local = (parent as BasePlayer).is_local
		_network_id = (parent as BasePlayer).network_id
	else:
		_is_local = true
		_network_id = 0

	if not _is_local:
		set_process(false)
		set_physics_process(false)
		return

	_nam = _find_nam()
	if _nam:
		_nam.on_action("block_break", _on_remote_block_break)
		_nam.on_action("block_place", _on_remote_block_place)
		_nam.on_action("chameleon_paint", _on_remote_chameleon_paint)
		print("✅ PlayerInteraction: мультиплеер подключён")
	else:
		print("ℹ️ PlayerInteraction: NAM не найден, одиночный режим")



func _find_nam() -> NetworkActionManager:
	# NAM создаётся в client.gd как дочерний узел корня сцены
	var root := get_tree().current_scene
	if root == null:
		return null

	# Поиск по имени (быстрый путь)
	var node := root.get_node_or_null("NetworkActionManager")
	if node is NetworkActionManager:
		return node as NetworkActionManager

	# Поиск по типу (если имя другое)
	for child in root.get_children():
		if child is NetworkActionManager:
			return child as NetworkActionManager

	return null

#-------------------------------------
#-------------------------------------
#--------------ЗАГЛУШКА---------------
#-------------------------------------
#-------------------------------------
func _on_remote_block_break(peer_id: int, data: Dictionary) -> void:
	if _terrain_tool == null:
		return

	var pos := Vector3i(data["block_position"])

	# Хамелеон: очистка при разрушении
	var cham = ChameleonManager.get_instance()
	if cham:
		var old_id = _terrain_tool.get_voxel(pos)
		if cham.is_chameleon_block(old_id):
			cham.remove_chameleon(pos)

	_terrain_tool.value = 0
	_terrain_tool.do_point(pos)
	#block_broken.emit(pos, 0)


func _on_remote_block_place(peer_id: int, data: Dictionary) -> void:
	if _terrain_tool == null:
		return

	var pos := Vector3i(data["block_position"])
	var voxel_id: int = data["block_id"]

	_terrain_tool.value = voxel_id
	_terrain_tool.do_point(pos)
	#block_placed.emit(pos, voxel_id)

func _on_remote_chameleon_paint(peer_id: int, data: Dictionary) -> void:
	var cham = ChameleonManager.get_instance()
	if cham == null:
		return
	var pos := Vector3i(data["block_position"])
	var block_id: int = data["source_block_id"]
	cham.paint_chameleon_by_block_id(pos, block_id)
	
