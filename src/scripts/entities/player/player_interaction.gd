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
var _selected_block_id: int = 1
var _selected_block_name: String = "stone"

# ═══ ДАННЫЕ ПОЛУБЛОКОВ (загружаются из ресурса) ═══
const SLAB_DATA_PATH = "res://src/data/blocks/slab_data.tres"
var _slab_data: SlabData = null

signal block_broken(position: Vector3i, block_id: int)
signal block_placed(position: Vector3i, block_id: int)
signal target_changed(position: Vector3i, has_target: bool)
signal terrain_found(terrain: VoxelTerrain)
signal terrain_lost()


# ═══════════════════════════════════════════════════════════
#  ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════

func _ready():
	await get_tree().process_frame
	
	_load_slab_data()
	
	if search_terrain_on_ready:
		_find_and_setup_terrain()
	
	get_tree().node_added.connect(_on_node_added)


func _load_slab_data():
	"""Загружает данные полублоков из ресурса"""
	if ResourceLoader.exists(SLAB_DATA_PATH):
		_slab_data = load(SLAB_DATA_PATH)
		if _slab_data:
			print("✅ Данные полублоков загружены")
			print("   Полублоков: ", _slab_data.slab_registry.size())
		else:
			print("⚠️ Не удалось загрузить slab_data")
	else:
		print("⚠️ slab_data.tres не найден — полублоки отключены")


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
	terrain_found.emit(_terrain)

func _on_node_added(node: Node):
	if _terrain == null and node is VoxelTerrain:
		await get_tree().process_frame
		_terrain = node
		_setup_terrain_tool()


# ═══════════════════════════════════════════════════════════
#  ОСНОВНОЙ ЦИКЛ
# ═══════════════════════════════════════════════════════════

func _process(delta):
	if _terrain == null or _terrain_tool == null:
		return
	if _break_timer > 0:
		_break_timer -= delta
	if _place_timer > 0:
		_place_timer -= delta
	
	var target = _get_target()
	target_changed.emit(target["position"], target["has_target"])
	
	if target["has_target"]:
		_handle_input(target)


# ═══════════════════════════════════════════════════════════
#  РЕЙКАСТ
# ═══════════════════════════════════════════════════════════

func _get_target() -> Dictionary:
	var result = {
		"has_target": false,
		"position": Vector3i.ZERO,
		"previous_position": Vector3i.ZERO,
		"block_id": 0,
		"hit_normal": Vector3.ZERO,
		"hit_position": Vector3.ZERO
	}
	
	if _terrain_tool == null:
		return result
	
	var origin = _camera.global_position
	var forward = -_camera.global_transform.basis.z.normalized()
	
	var hit = _terrain_tool.raycast(origin, forward, reach_distance)
	if hit == null:
		return result
	
	result.has_target = true
	result.position = hit.position
	result.previous_position = hit.previous_position
	result.block_id = _terrain_tool.get_voxel(hit.position)
	result.hit_normal = Vector3(hit.previous_position - hit.position).normalized()
	
	if _raycast and _raycast.is_colliding():
		result.hit_position = _raycast.get_collision_point()
		result.hit_normal = _raycast.get_collision_normal()
	else:
		result.hit_position = _compute_face_hit(origin, forward, hit.position, result.hit_normal)
	
	return result

func _compute_face_hit(origin: Vector3, direction: Vector3, voxel_pos: Vector3i, normal: Vector3) -> Vector3:
	var axis: int
	var face_point: float
	if abs(normal.x) > 0.5:
		axis = 0
		face_point = float(voxel_pos.x) + (0.5 + 0.5 * sign(normal.x))
	elif abs(normal.y) > 0.5:
		axis = 1
		face_point = float(voxel_pos.y) + (0.5 + 0.5 * sign(normal.y))
	else:
		axis = 2
		face_point = float(voxel_pos.z) + (0.5 + 0.5 * sign(normal.z))
	var dir_component = direction[axis]
	if abs(dir_component) < 0.0001:
		return Vector3(voxel_pos) + Vector3(0.5, 0.5, 0.5) + normal * 0.5
	var t = (face_point - origin[axis]) / dir_component
	return origin + direction * t


# ═══════════════════════════════════════════════════════════
#  ВВОД
# ═══════════════════════════════════════════════════════════

func _handle_input(target: Dictionary):
	if Input.is_action_pressed("break_block") and _break_timer <= 0:
		_break_block(target["position"])
		_break_timer = break_cooldown
	
	if Input.is_action_pressed("place_block") and _place_timer <= 0:
		_place_block(target)
		_place_timer = place_cooldown
	
	if Input.is_action_just_pressed("pick_block"):
		_pick_block(target["position"])


# ═══════════════════════════════════════════════════════════
#  ЛОМАНИЕ
# ═══════════════════════════════════════════════════════════

func _break_block(pos: Vector3i):
	if _terrain_tool == null:
		return
	var old_id = _terrain_tool.get_voxel(pos)
	if old_id == 0:
		return
	_terrain_tool.value = 0
	_terrain_tool.do_point(pos)
	if _terrain_tool.get_voxel(pos) == 0:
		block_broken.emit(pos, old_id)


# ═══════════════════════════════════════════════════════════
#  РАЗМЕЩЕНИЕ
# ═══════════════════════════════════════════════════════════

func _place_block(target: Dictionary):
	var hit_pos: Vector3i = target["position"]
	var prev_pos: Vector3i = target["previous_position"]
	var hit_world: Vector3 = target["hit_position"]
	var hit_normal: Vector3 = target["hit_normal"]
	var hit_id: int = target["block_id"]
	
	var selected_is_slab = _is_slab_name(_selected_block_name)
	var looking_at_slab = _is_slab_id(hit_id)
	
	# ═══ СЛУЧАЙ 1: Полублок + полублок → объединение ═══
	if selected_is_slab and looking_at_slab:
		var hit_slab = _get_slab_info_by_id(hit_id)
		var selected_info = _get_slab_info_by_name(_selected_block_name)
		
		if hit_slab["name"] == selected_info["name"]:
			var full_id = hit_slab.get("full_id", -1)
			if full_id >= 0:
				_place_block_at(hit_pos, full_id)
				return
	
	# ═══ СЛУЧАЙ 2: Ставим полублок ═══
	if selected_is_slab:
		if not _can_place_at(prev_pos):
			return
		if _terrain_tool.get_voxel(prev_pos) != 0:
			return
		
		var selected_info = _get_slab_info_by_name(_selected_block_name)
		var variant = _determine_slab_variant(hit_world, hit_normal)
		var voxel_id: int
		
		if variant == "bottom":
			voxel_id = selected_info.get("bottom_id", _selected_block_id)
		else:
			voxel_id = selected_info.get("top_id", _selected_block_id)
		
		_place_block_at(prev_pos, voxel_id)
		return
	
	# ═══ СЛУЧАЙ 3: Обычный блок ═══
	if not _can_place_at(prev_pos):
		return
	if _terrain_tool.get_voxel(prev_pos) != 0:
		return
	_place_block_at(prev_pos, _selected_block_id)


func _place_block_at(pos: Vector3i, block_id: int):
	if _terrain_tool == null:
		return
	_terrain_tool.value = block_id
	_terrain_tool.do_point(pos)
	if _terrain_tool.get_voxel(pos) == block_id:
		block_placed.emit(pos, block_id)


func _determine_slab_variant(hit_world: Vector3, hit_normal: Vector3) -> String:
	if hit_normal.y > 0.5:
		return "bottom"
	elif hit_normal.y < -0.5:
		return "top"
	else:
		var local_y = hit_world.y - floor(hit_world.y)
		return "top" if local_y >= 0.5 else "bottom"


# ═══════════════════════════════════════════════════════════
#  ДОСТУП К ДАННЫМ ПОЛУБЛОКОВ (из ресурса)
# ═══════════════════════════════════════════════════════════

func _is_slab_name(block_name: String) -> bool:
	"""Проверяет: есть ли полублок с таким именем"""
	if _slab_data == null:
		return false
	return _slab_data.slab_registry.has(block_name)

func _is_slab_id(voxel_id: int) -> bool:
	"""Проверяет: является ли ID полублоком"""
	if _slab_data == null:
		return false
	return _slab_data.slab_id_map.has(str(voxel_id))

func _get_slab_info_by_id(voxel_id: int) -> Dictionary:
	"""Информация о полублоке по voxel ID"""
	if _slab_data == null:
		return {}
	var key = str(voxel_id)
	if not _slab_data.slab_id_map.has(key):
		return {}
	var map_info = _slab_data.slab_id_map[key]
	var name = map_info["name"]
	var full_info = _slab_data.slab_registry.get(name, {})
	return {
		"name": name,
		"variant": map_info["variant"],
		"bottom_id": full_info.get("bottom_id", -1),
		"top_id": full_info.get("top_id", -1),
		"full_id": full_info.get("full_id", -1)
	}

func _get_slab_info_by_name(slab_name: String) -> Dictionary:
	"""Информация о полублоке по имени"""
	if _slab_data == null:
		return {}
	return _slab_data.slab_registry.get(slab_name, {})


# ═══════════════════════════════════════════════════════════
#  ВЫБОР БЛОКА
# ═══════════════════════════════════════════════════════════

func _pick_block(pos: Vector3i):
	var block_id = _terrain_tool.get_voxel(pos)
	if block_id == 0:
		return
	
	_selected_block_id = block_id
	
	# Если это полублок — выбираем базовое имя
	if _is_slab_id(block_id):
		var slab_info = _get_slab_info_by_id(block_id)
		_selected_block_name = slab_info.get("name", "")
		_selected_block_id = slab_info.get("bottom_id", block_id)
		print("👆 Выбран полублок: ", _selected_block_name)
		return
	
	# Обычный блок — пока оставляем ID
	# Имя можно получить из VoxelBlockyLibrary если нужно
	print("👆 Выбран блок ID: ", block_id)


# ═══════════════════════════════════════════════════════════
#  УТИЛИТЫ
# ═══════════════════════════════════════════════════════════

func _world_to_voxel(world_pos: Vector3) -> Vector3i:
	return Vector3i(floori(world_pos.x), floori(world_pos.y), floori(world_pos.z))

func _voxel_to_world(voxel_pos: Vector3i) -> Vector3:
	return Vector3(voxel_pos) + Vector3(0.5, 0.5, 0.5)

func _can_place_at(pos: Vector3i) -> bool:
	return global_position.distance_to(_voxel_to_world(pos)) > 1.5


# ═══════════════════════════════════════════════════════════
#  ПУБЛИЧНЫЙ API
# ═══════════════════════════════════════════════════════════

func set_selected_block(block_id: int):
	_selected_block_id = block_id

func set_selected_block_by_name(block_name: String):
	_selected_block_name = block_name
	if _is_slab_name(block_name):
		var info = _get_slab_info_by_name(block_name)
		_selected_block_id = info.get("bottom_id", _selected_block_id)

func get_selected_block() -> int:
	return _selected_block_id

func get_selected_block_name() -> String:
	return _selected_block_name

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
