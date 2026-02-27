extends Node3D

@onready var _camera: Camera3D = get_node("../Neck/Camera3D")
@onready var _raycast: RayCast3D = get_node("../Neck/Camera3D/RayCast3D")

var _terrain: VoxelTerrain = null
var _terrain_tool: VoxelTool = null
var _voxel_size: float = 1.0

@export var reach_distance: float = 10.0
@export var break_cooldown: float = 0.2
@export var place_cooldown: float = 0.2
@export var search_terrain_on_ready: bool = true

var _break_timer: float = 0.0
var _place_timer: float = 0.0
var _player: Node = null
var _selected_block_id: int = 0  # 0 = воздух (ничего не ставить)

signal block_broken(position: Vector3i, block_id: int)
signal block_placed(position: Vector3i, block_id: int)
signal target_changed(position: Vector3i, has_target: bool)
signal terrain_found(terrain: VoxelTerrain)
signal terrain_lost()

func _ready():
	await get_tree().process_frame
	_find_player()
	if search_terrain_on_ready:
		_find_and_setup_terrain()
	get_tree().node_added.connect(_on_node_added)

func _find_player():
	var parent = get_parent()
	while parent:
		if parent is CharacterBody3D:
			_player = parent
			if _player.has_signal("selected_slot_changed"):
				_player.selected_slot_changed.connect(_on_player_selected_slot_changed)
				_update_selected_block_from_player()
			break
		parent = parent.get_parent()
	if not _player:
		push_warning("PlayerInteraction: игрок не найден")

func _on_player_selected_slot_changed(_index: int):
	_update_selected_block_from_player()

func _update_selected_block_from_player():
	if _player and _player.has_method("get_selected_block_info"):
		var info = _player.get_selected_block_info()
		if not info.is_empty() and info.has("id") and info.id != -1:
			_selected_block_id = info.id
			print("PlayerInteraction: выбран блок ID ", _selected_block_id)
		else:
			_selected_block_id = 0
			print("PlayerInteraction: слот пуст, установка отключена")

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

func _find_terrain_in_tree() -> VoxelTerrain:
	var nodes = get_tree().get_nodes_in_group("voxel_terrain")
	if nodes.size() > 0:
		return nodes[0]
	for node in get_tree().get_root().get_children():
		var terrain = _find_terrain_recursive(node)
		if terrain:
			return terrain
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
		_raycast.collision_mask = 1
	print("✅ Terrain найден: ", _terrain.name)
	terrain_found.emit(_terrain)

func _on_node_added(node: Node):
	if _terrain == null and node is VoxelTerrain:
		await get_tree().process_frame
		_terrain = node
		_setup_terrain_tool()

func _process(delta):
	if _terrain == null or _terrain_tool == null:
		return
	
	if _break_timer > 0:
		_break_timer -= delta
	if _place_timer > 0:
		_place_timer -= delta
	
	var target = _get_target()
	var has_target = target.get("has_target", false)
	var pos = target.get("position", Vector3i.ZERO)
	target_changed.emit(pos, has_target)
	
	if has_target:
		_handle_input(target)

func _world_to_voxel(world_pos: Vector3) -> Vector3i:
	return Vector3i(
		floori(world_pos.x / _voxel_size),
		floori(world_pos.y / _voxel_size),
		floori(world_pos.z / _voxel_size)
	)

func _voxel_to_world(voxel_pos: Vector3i) -> Vector3:
	return Vector3(voxel_pos) * _voxel_size + Vector3.ONE * _voxel_size * 0.5

func _get_target() -> Dictionary:
	var result = {
		"has_target": false,
		"position": Vector3i.ZERO,
		"previous_position": Vector3i.ZERO,
		"block_id": 0
	}
	if _terrain_tool == null:
		return result
	
	var origin = _camera.global_position
	var forward = -_camera.global_transform.basis.z.normalized()
	var hit = _terrain_tool.raycast(origin, forward, reach_distance)
	if hit != null:
		result.has_target = true
		result.position = hit.position
		result.previous_position = hit.previous_position
		result.block_id = _terrain_tool.get_voxel(hit.position)
	return result

func _handle_input(target: Dictionary):
	var pos: Vector3i = target.get("position", Vector3i.ZERO)
	var prev_pos: Vector3i = target.get("previous_position", Vector3i.ZERO)
	
	if Input.is_action_pressed("break_block") and _break_timer <= 0:
		_break_block(pos)
		_break_timer = break_cooldown
	
	if Input.is_action_pressed("place_block") and _place_timer <= 0:
		if _selected_block_id != 0 and _can_place_at(prev_pos):
			_place_block(prev_pos)
			_place_timer = place_cooldown
	
	if Input.is_action_just_pressed("pick_block"):
		_pick_block(pos)

func _break_block(pos: Vector3i):
	if _terrain_tool == null:
		return
	var old_id = _terrain_tool.get_voxel(pos)
	if old_id == 0:
		return
	_terrain_tool.value = 0
	_terrain_tool.do_point(pos)
	var new_id = _terrain_tool.get_voxel(pos)
	if new_id == 0:
		print("⛏️ Блок сломан: ", pos, " (ID: ", old_id, " -> ", new_id, ")")
		block_broken.emit(pos, old_id)
	else:
		print("❌ Не удалось сломать блок: ", pos)

func _place_block(pos: Vector3i):
	if _terrain_tool == null:
		return
	var current = _terrain_tool.get_voxel(pos)
	if current != 0:
		return
	_terrain_tool.value = _selected_block_id
	_terrain_tool.do_point(pos)
	var new_id = _terrain_tool.get_voxel(pos)
	if new_id == _selected_block_id:
		print("🧱 Блок установлен: ", pos, " (ID: ", _selected_block_id, ")")
		block_placed.emit(pos, _selected_block_id)
	else:
		print("❌ Не удалось поставить блок: ", pos)

func _pick_block(pos: Vector3i):
	var block_id = _terrain_tool.get_voxel(pos)
	if block_id == 0:
		return
	print("👆 Выбран блок ID: ", block_id)

func _can_place_at(pos: Vector3i) -> bool:
	var player_pos = global_position
	var block_world_pos = _voxel_to_world(pos)
	return player_pos.distance_to(block_world_pos) > 1.5

func set_selected_block(block_id: int):
	_selected_block_id = block_id

func get_selected_block() -> int:
	return _selected_block_id

func get_terrain() -> VoxelTerrain:
	return _terrain

func has_terrain() -> bool:
	return _terrain != null and _terrain_tool != null

func set_terrain(terrain: VoxelTerrain):
	if terrain == null:
		_terrain = null
		_terrain_tool = null
		terrain_lost.emit()
		return
	_terrain = terrain
	_setup_terrain_tool()

func find_terrain() -> bool:
	return _find_and_setup_terrain()
