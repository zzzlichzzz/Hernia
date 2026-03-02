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
var _selected_texture: String = "stone"

# Frame blocks
var _frame_manager: FrameBlockManager = null
var _edit_mode: bool = false

# Маппинг block_id → texture_name для фрейм-блоков
# Используем texture_top если доступно, иначе texture_name
var _block_to_texture: Dictionary = {
	1: "grass_block_top",  # block_grass → top texture
	2: "cherry_planks",    # cherry_planks
	3: "cherry_planks",    # cherry_stair
	4: "dirt",             # dirt
	5: "stone"             # stone
}

const FRAME_COLLISION_LAYER = 2
var _inventory: Node = null

signal block_broken(position: Vector3i, block_id: int)
signal block_placed(position: Vector3i, block_id: int)
signal target_changed(position: Vector3i, has_target: bool)
signal terrain_found(terrain: VoxelTerrain)
signal terrain_lost()


func _ready():
	await get_tree().process_frame
	_find_inventory()
	if search_terrain_on_ready:
		_find_and_setup_terrain()
	get_tree().node_added.connect(_on_node_added)
	
	# Frame-блок менеджер
	_frame_manager = FrameBlockManager.new()
	_frame_manager.name = "FrameBlockManager"
	add_child(_frame_manager)
	
	if _terrain:
		_frame_manager.set_terrain(_terrain)
	
	# Настраиваем RayCast для обнаружения frame-блоков
	if _raycast:
		_raycast.collision_mask = 1 | FRAME_COLLISION_LAYER  # Layer 1 (terrain) + Layer 2 (frames)
	
	print("✅ FrameBlockManager создан")


func _find_inventory():
	# Ищем CreativeInventory среди детей родителя (игрока)
	var parent = get_parent()
	if parent:
		for child in parent.get_children():
			if child.has_method("get_selected_block_info"):
				_inventory = child
				if _inventory.has_signal("selected_slot_changed"):
					_inventory.selected_slot_changed.connect(_on_selected_slot_changed)
				_update_selected_block_from_inventory()
				break
	if not _inventory:
		push_warning("PlayerInteraction: CreativeInventory не найден")

func _on_selected_slot_changed(_index: int):
	_update_selected_block_from_inventory()

func _update_selected_block_from_inventory():
	if _inventory:
		var info = _inventory.get_selected_block_info()
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
		_raycast.collision_mask = 1 | FRAME_COLLISION_LAYER
	
	if _frame_manager:
		_frame_manager.set_terrain(_terrain)
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
	
	# Если чат или инвентарь открыт, не обрабатываем взаимодействие
	if _is_chat_or_inventory_open():
		return
	
	if _break_timer > 0:
		_break_timer -= delta
	if _place_timer > 0:
		_place_timer -= delta
	
	_handle_input()

func _is_chat_or_inventory_open() -> bool:
	# Проверяем открыт ли чат
	var chat = get_tree().get_first_node_in_group("chat")
	if chat and chat.has_method("is_chat_open"):
		if chat.is_chat_open():
			return true
	
	# Проверяем открыт ли инвентарь
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has("inventory_open"):
		if player.inventory_open:
			return true
	
	return false


func _handle_input():
	# Проверяем, открыт ли инвентарь
	var player = get_parent()
	var inventory_is_open = false
	if player and "inventory_open" in player:
		inventory_is_open = player.inventory_open
	
	# Если инвентарь открыт - нельзя ломать/ставить блоки
	if inventory_is_open:
		return
	
	# F — переключение режима редактирования
	if Input.is_action_just_pressed("toggle_edit_mode"):
		_edit_mode = not _edit_mode
		print("🔧 Режим редактирования: ", "ВКЛ" if _edit_mode else "ВЫКЛ")
	
	# Получаем цель
	var target = _get_combined_target()
	
	if not target["has_target"]:
		return
	
	target_changed.emit(target["position"], true)
	
	# ЛКМ — сломать
	if Input.is_action_pressed("break_block") and _break_timer <= 0:
		if target["is_frame"]:
			_frame_manager.remove_frame_block(target["position"])
		else:
			_break_block(target["position"])
		_break_timer = break_cooldown
	
	# ПКМ — поставить / редактировать
	if Input.is_action_pressed("place_block") and _place_timer <= 0:
		if _edit_mode and _frame_manager:
			if target["is_frame"]:
				# Редактируем грань frame-блока
				var face = target["face"]
				_frame_manager.set_face_texture(target["position"], face, _selected_texture)
			else:
				# Создаём новый frame-блок
				var place_pos = target["place_position"]
				if _can_place_at(place_pos):
					_frame_manager.create_frame_block(place_pos)
		else:
			# Обычное размещение вокселя
			var place_pos = target["place_position"]
			if _can_place_at(place_pos):
				_place_block(place_pos)
		_place_timer = place_cooldown
	
	# Средняя кнопка — выбрать
	if Input.is_action_just_pressed("pick_block"):
		if target["is_frame"]:
			var face = target["face"]
			_selected_texture = _frame_manager.get_face_texture(target["position"], face)
			print("👆 Скопирована текстура: ", _selected_texture)
		else:
			_pick_block(target["position"])


func _get_combined_target() -> Dictionary:
	"""Комбинированный рейкаст: сначала проверяем frame-блоки, потом воксели"""
	var result = {
		"has_target": false,
		"is_frame": false,
		"position": Vector3i.ZERO,
		"place_position": Vector3i.ZERO,
		"face": "top",
		"normal": Vector3.ZERO
	}
	
	var origin = _camera.global_position
	var forward = -_camera.global_transform.basis.z.normalized()
	
	# ═══ 1. Проверяем RayCast3D (frame-блоки) ═══
	if _raycast and _raycast.is_colliding():
		var collider = _raycast.get_collider()
		
		if _frame_manager.is_frame_collider(collider):
			var frame_pos = _frame_manager.get_block_pos_from_collider(collider)
			var hit_normal = _raycast.get_collision_normal()
			
			result["has_target"] = true
			result["is_frame"] = true
			result["position"] = frame_pos
			result["place_position"] = frame_pos + _normal_to_vec3i(hit_normal)
			result["face"] = _normal_to_face(hit_normal)
			result["normal"] = hit_normal
			return result
	
	# ═══ 2. Проверяем VoxelTool raycast ═══
	var hit = _terrain_tool.raycast(origin, forward, reach_distance)
	if hit:
		result["has_target"] = true
		result["is_frame"] = false
		result["position"] = hit.position
		result["place_position"] = hit.previous_position
		
		var normal = Vector3(hit.previous_position - hit.position)
		result["face"] = _normal_to_face(normal)
		result["normal"] = normal.normalized()
	
	return result


func _normal_to_face(normal: Vector3) -> String:
	if normal.y > 0.5:
		return "top"
	elif normal.y < -0.5:
		return "bottom"
	elif normal.z < -0.5:
		return "north"
	elif normal.z > 0.5:
		return "south"
	elif normal.x > 0.5:
		return "east"
	elif normal.x < -0.5:
		return "west"
	return "top"


func _normal_to_vec3i(normal: Vector3) -> Vector3i:
	if normal.y > 0.5:
		return Vector3i(0, 1, 0)
	elif normal.y < -0.5:
		return Vector3i(0, -1, 0)
	elif normal.z < -0.5:
		return Vector3i(0, 0, -1)
	elif normal.z > 0.5:
		return Vector3i(0, 0, 1)
	elif normal.x > 0.5:
		return Vector3i(1, 0, 0)
	elif normal.x < -0.5:
		return Vector3i(-1, 0, 0)
	return Vector3i.ZERO


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
		print("⛏️ Блок сломан: ", pos)
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
		print("🧱 Блок установлен: ", pos)
		block_placed.emit(pos, _selected_block_id)


func _pick_block(pos: Vector3i):
	var block_id = _terrain_tool.get_voxel(pos)
	if block_id == 0:
		return
	print("👆 Выбран блок ID: ", block_id)


func _world_to_voxel(world_pos: Vector3) -> Vector3i:
	return Vector3i(floori(world_pos.x), floori(world_pos.y), floori(world_pos.z))


func _voxel_to_world(voxel_pos: Vector3i) -> Vector3:
	return Vector3(voxel_pos) + Vector3(0.5, 0.5, 0.5)


func _can_place_at(pos: Vector3i) -> bool:
	var player_pos = global_position
	var block_world_pos = _voxel_to_world(pos)
	return player_pos.distance_to(block_world_pos) > 1.5


# ═══ ПУБЛИЧНЫЙ API ═══

func set_selected_block(block_id: int):
	_selected_block_id = block_id
	# Обновляем текстуру для фрейм-блока
	_selected_texture = _block_to_texture.get(block_id, "stone")
	print("🧱 Блок выбран: ID=", block_id, " текстура=", _selected_texture)

func get_selected_block() -> int:
	return _selected_block_id

func set_selected_texture(texture_name: String):
	_selected_texture = texture_name

func get_selected_texture() -> String:
	return _selected_texture

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
