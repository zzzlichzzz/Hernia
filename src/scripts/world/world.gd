class_name World extends Node3D


var items: ItemArrayRegistry
var _terrain: VoxelTerrain = null
var _terrain_tool: VoxelTool = null
var _voxel_size: float = 1.0
var _chameleon_mgr: Node = null

@onready var player: Player = $Player

signal block_placed(position: Vector3i, block_id: int)
signal terrain_found(terrain: VoxelTerrain)
signal target_changed(position: Vector3i, has_target: bool)
signal terrain_lost()

func _init() -> void:
	items = load("res://src/data/items/items.tres")

func _ready() -> void:
	_find_and_setup_terrain()
	get_tree().node_added.connect(_on_node_added)
	
	_chameleon_mgr = ChameleonManager.get_instance()


func _break_block(pos: Vector3i):
	if getPlayer().getWorld()._terrain_tool == null:
		return
	var old_id = getPlayer().getWorld()._terrain_tool.get_voxel(pos)
	if old_id == 0:
		return
	
	# ══════════════════════════════════════════
	#  ХАМЕЛЕОН — очистка при разрушении
	# ══════════════════════════════════════════
	var cham = ChameleonManager.get_instance()
	if cham and cham.is_chameleon_block(old_id):
		cham.remove_chameleon(pos)
	# ══════════════════════════════════════════
	
	getPlayer().getWorld()._terrain_tool.value = 0
	getPlayer().getWorld()._terrain_tool.do_point(pos)
	var new_id = getPlayer().getWorld()._terrain_tool.get_voxel(pos)
	if new_id == 0:
		print("⛏️ Блок сломан: ", pos)
		block_broken.emit(pos, old_id)
	else:
		print("❌ Не удалось сломать блок: ", pos)

func _place_block(_selected_block_id: String, pos: Vector3i):
	if _terrain_tool == null:
		return
	var current = _terrain_tool.get_voxel(pos)
	if current != 0:
		return
		
	if not items.isItemBlock(_selected_block_id):
		return
	
	_terrain_tool.value = items.getItemBlockID(_selected_block_id)
	_terrain_tool.do_point(pos)
	var new_id = _terrain_tool.get_voxel(pos)
	if new_id == items.getItemBlockID(_selected_block_id):
		print("🧱 Блок установлен: ", pos)
		block_placed.emit(pos, _selected_block_id)


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
	if player.getRayCast():
		player.getRayCast().target_position = Vector3(0, 0, -player.reach_distance)
		player.getRayCast().collision_mask = 1 | player.FRAME_COLLISION_LAYER
	
	var cham = ChameleonManager.get_instance()
	if cham:
		cham.connect_to_terrain(_terrain)
	
	print("✅ Terrain найден: ", _terrain.name)
	terrain_found.emit(_terrain)



func _on_node_added(node: Node):
	if _terrain == null and node is VoxelTerrain:
		await get_tree().process_frame
		_terrain = node
		_setup_terrain_tool()

func _can_place_at(player_pos: Vector3i, pos: Vector3i) -> bool:
	var block_world_pos = _voxel_to_world(pos)
	return player_pos.distance_to(block_world_pos) > 1.5

func _world_to_voxel(world_pos: Vector3) -> Vector3i:
	return Vector3i(floori(world_pos.x), floori(world_pos.y), floori(world_pos.z))

func _voxel_to_world(voxel_pos: Vector3i) -> Vector3:
	return Vector3(voxel_pos) + Vector3(0.5, 0.5, 0.5)

func get_terrain() -> VoxelTerrain:
	return _terrain

func has_terrain() -> bool:
	return _terrain != null and _terrain_tool != null
	
func getItems() -> ItemArrayRegistry:
	return items
