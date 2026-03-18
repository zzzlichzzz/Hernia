class_name BlockInteraction
extends BaseInteraction

## Взаимодействие с блоками: ломание, установка, покраска хамелеонов.

# ══════════════════════════════════════════════════
#  НОДЫ
# ══════════════════════════════════════════════════

@onready var _camera: Camera3D = get_node_or_null("../Neck/Camera3D")          # [CHANGE 4] get_node_or_null
@onready var _raycast: RayCast3D = get_node_or_null("../Neck/Camera3D/RayCast3D")
@onready var _world = get_node("/root/ClientMain/World")
# ══════════════════════════════════════════════════
#  TERRAIN
# ══════════════════════════════════════════════════

var _terrain: VoxelTerrain = null
var _terrain_tool: VoxelTool = null
var _voxel_size: float = 1.0

# ══════════════════════════════════════════════════
#  НАСТРОЙКИ
# ══════════════════════════════════════════════════

@export var reach_distance: float = 10.0
@export var break_cooldown: float = 0.2
@export var place_cooldown: float = 0.2
@export var search_terrain_on_ready: bool = true

# ══════════════════════════════════════════════════
#  ВНУТРЕННИЕ ПЕРЕМЕННЫЕ
# ══════════════════════════════════════════════════

var _break_timer: float = 0.0
var _place_timer: float = 0.0
var _selected_block_id: int = -1
var _selected_texture: String = "stone"

# [CHANGE 10] Комментарий: ключи 2 и 3 оба → "cherry_planks". Намеренно?
var _block_to_texture: Dictionary = {
	1: "grass_block_top",
	2: "cherry_planks",
	3: "cherry_planks",
	4: "dirt",
	5: "stone",
}

var _inventory: Node = null
var _chameleon_mgr: Node = null
var items: ItemArrayRegistry = null

var item_path: String = "res://src/data/items/registry/items.tres"

# ══════════════════════════════════════════════════
#  СИГНАЛЫ
# ══════════════════════════════════════════════════

signal block_broken(position: Vector3i, block_id: int)
signal block_placed(position: Vector3i, block_id: int)
signal target_changed(position: Vector3i, has_target: bool)
signal terrain_found(terrain: VoxelTerrain)
signal terrain_lost()


# ══════════════════════════════════════════════════
#  ПЕРЕОПРЕДЕЛЕНИЯ BaseInteraction
# ══════════════════════════════════════════════════

func _get_module_name() -> String:
	return "BlockInteraction"


func _on_module_ready() -> void:
	await get_tree().process_frame

	# [CHANGE 1] Проверка загрузки items
	items = load(item_path) as ItemArrayRegistry
	if items == null:
		push_error("❌ BlockInteraction: не удалось загрузить ItemArrayRegistry: " + item_path)
		set_process(false)
		return

	_find_inventory()

	if search_terrain_on_ready:
		_find_and_setup_terrain()

	# [CHANGE 6] Сохраняем ссылку для корректного отключения
	get_tree().node_added.connect(_on_node_added)

	if _raycast:
		_raycast.target_position = Vector3(0, 0, -reach_distance)

	_chameleon_mgr = ChameleonManager.get_instance()
	if _chameleon_mgr:
		print("✅ ChameleonManager подключён к BlockInteraction")
	else:
		push_warning("⚠️ ChameleonManager autoload не найден")


# [CHANGE 6] Очистка при удалении ноды — предотвращает утечку сигнала
func _exit_tree() -> void:
	var tree := get_tree()
	if tree and tree.node_added.is_connected(_on_node_added):
		tree.node_added.disconnect(_on_node_added)

	# [CHANGE 11] Отписка от terrain
	if _terrain and _terrain.is_inside_tree() and _terrain.tree_exiting.is_connected(_on_terrain_removed):
		_terrain.tree_exiting.disconnect(_on_terrain_removed)


func _register_actions() -> void:
	_register_action("block_break")
	_register_action("block_place")
	_register_action("chameleon_paint")


func _on_remote_action(action_name: String, peer_id: int, data: Dictionary) -> void:
	match action_name:
		"block_break":
			_remote_break(data)
		"block_place":
			_remote_place(data)
		"chameleon_paint":
			_remote_chameleon_paint(data)


# ══════════════════════════════════════════════════
#  УДАЛЁННОЕ ПРИМЕНЕНИЕ
# ══════════════════════════════════════════════════

func _remote_break(data: Dictionary) -> void:
	if _terrain_tool == null:
		return

	if not data.has("block_position"):
		push_warning("BlockInteraction: _remote_break — нет ключа 'block_position'")
		return

	var pos := Vector3i(data["block_position"])

	var cham := ChameleonManager.get_instance()
	if cham:
		var old_id := _terrain_tool.get_voxel(pos)
		if cham.is_chameleon_block(old_id):
			cham.remove_chameleon(pos)

	_terrain_tool.value = 0
	_terrain_tool.do_point(pos)
	block_broken.emit(pos, 0)


func _remote_place(data: Dictionary) -> void:
	if _terrain_tool == null:
		return

	if not data.has("block_position") or not data.has("block_id"):
		push_warning("BlockInteraction: _remote_place — отсутствуют ключи")
		return

	var pos := Vector3i(data["block_position"])
	var voxel_id: int = data["block_id"]

	_terrain_tool.value = voxel_id
	_terrain_tool.do_point(pos)
	block_placed.emit(pos, voxel_id)


func _remote_chameleon_paint(data: Dictionary) -> void:
	var cham := ChameleonManager.get_instance()
	if cham == null:
		return

	if not data.has("block_position") or not data.has("source_block_id"):
		push_warning("BlockInteraction: _remote_chameleon_paint — отсутствуют ключи")
		return

	var pos := Vector3i(data["block_position"])
	var block_id: int = data["source_block_id"]
	cham.paint_chameleon_by_block_id(pos, block_id)


# ══════════════════════════════════════════════════
#  ВВОД И ЛОГИКА
# ══════════════════════════════════════════════════

func _process(delta: float) -> void:
	if _terrain == null or _terrain_tool == null:
		return
	# [CHANGE 4] Проверка камеры
	if _camera == null:
		return
	if _is_ui_blocking():
		return

	if _break_timer > 0.0:
		_break_timer -= delta
	if _place_timer > 0.0:
		_place_timer -= delta

	_handle_input()


func _handle_input() -> void:
	var target := _get_combined_target()
	if not target["has_target"]:
		return

	target_changed.emit(target["position"], true)

	if Input.is_action_pressed("break_block") and _break_timer <= 0.0:
		_break_block(target["position"])
		_break_timer = break_cooldown

	if Input.is_action_pressed("place_block") and _place_timer <= 0.0:
		if not _try_paint_chameleon(target["position"]):
			var place_pos: Vector3i = target["place_position"]
			if _can_place_at(place_pos):
				_place_block(place_pos)
		_place_timer = place_cooldown

	if Input.is_action_just_pressed("pick_block"):
		_pick_block(target["position"])


# ══════════════════════════════════════════════════
#  ДЕЙСТВИЯ (локальные + отправка)
# ══════════════════════════════════════════════════

func _break_block(pos: Vector3i) -> void:
	if _terrain_tool == null:
		return

	var old_id := _terrain_tool.get_voxel(pos)
	if old_id == 0:
		return
	elif is_position_free(pos):
		#var scene_block: Resource = items.get_item_int(_selected_block_id).get_scene()
		#var entity = scene_block.instantiate()
		#entity.position = Vector3(pos)
		##global_position.
		var r = 4
		#_world.remove_child()
	var cham := ChameleonManager.get_instance()
	if cham and cham.is_chameleon_block(old_id):
		cham.remove_chameleon(pos)

	_terrain_tool.value = 0
	_terrain_tool.do_point(pos)

	var new_id := _terrain_tool.get_voxel(pos)
	if new_id == 0:
		print("⛏️ Блок сломан: ", pos)
		block_broken.emit(pos, old_id)
		_send("block_break", [Vector3(pos)])
	else:
		push_warning("❌ Не удалось сломать блок: %s" % str(pos))

func is_position_free(position: Vector3) -> bool:
	var space = get_world_3d().direct_space_state
	var query = PhysicsPointQueryParameters3D.new()
	query.position = position
	return space.intersect_point(query).is_empty()

func _place_block(pos: Vector3i) -> void:
	if _terrain_tool == null:
		return

	var current := _terrain_tool.get_voxel(pos)
	if current != 0:
		return

	_update_selected_block_from_inventory()

	# [CHANGE 2] Проверка на невалидный id ДО обращения к массиву
	if _selected_block_id < 0:
		return
	# [CHANGE 1] Проверка items
	if items == null:
		return
	if not items.isItemBlock(_selected_block_id):
		return
	elif items.get_item_int(_selected_block_id) is ItemBlockLogic:
		var scene_block: Resource = items.get_item_int(_selected_block_id).get_scene()
		var entity = scene_block.instantiate()
		entity.position = Vector3(pos)
		_world.add_child(entity)
		#return
		

	var voxel_id: int = _selected_block_id
	_terrain_tool.value = voxel_id
	_terrain_tool.do_point(pos)

	var new_id := _terrain_tool.get_voxel(pos)
	if new_id == voxel_id:
		print("🧱 Блок установлен: ", pos)
		block_placed.emit(pos, _selected_block_id)
		_send("block_place", [Vector3(pos), voxel_id])


func _try_paint_chameleon(hit_pos: Vector3i) -> bool:
	var cham := ChameleonManager.get_instance()
	if cham == null:
		return false
	if _terrain_tool == null:
		return false
	# [CHANGE 1] items null-check
	if items == null:
		return false

	_update_selected_block_from_inventory()

	var voxel_id := _terrain_tool.get_voxel(hit_pos)
	if not cham.is_chameleon_block(voxel_id):
		return false

	# [CHANGE 2] Ранний выход при невалидном id
	if _selected_block_id < 0:
		return false

	var numeric_block_id: int = _selected_block_id

	# [CHANGE 3] Безопасное получение item
	var item: ItemData = items.get_item_int(_selected_block_id)
	if item == null:
		push_warning("BlockInteraction: предмет с id %d не найден в реестре" % _selected_block_id)
		return false

	var success := cham.paint_chameleon_by_block_id(hit_pos, numeric_block_id)

	if success:
		print("🎨 Хамелеон покрашен: ", hit_pos, " блоком ID: ", item.id)
		_send("chameleon_paint", [Vector3(hit_pos), numeric_block_id])
	else:
		# Фолбэк: ищем текстуру по словарю _block_to_texture
		var tex: String = _block_to_texture.get(item.id, "")
		if tex != "":
			success = cham.paint_chameleon(hit_pos, tex)
			if success:
				print("🎨 Хамелеон покрашен: ", hit_pos, " текстурой: ", tex)
				_send("chameleon_paint", [Vector3(hit_pos), numeric_block_id])

	return success


func _pick_block(pos: Vector3i) -> void:
	if _terrain_tool == null:
		return
	var block_id := _terrain_tool.get_voxel(pos)
	if block_id == 0:
		return
	print("👆 Выбран блок ID: ", block_id)
	# TODO: реализовать выбор блока в инвентарь


# ══════════════════════════════════════════════════
#  ИНВЕНТАРЬ
# ══════════════════════════════════════════════════

func _find_inventory() -> void:
	var parent := get_parent()
	if parent == null:
		push_warning("BlockInteraction: нет родительской ноды")
		return

	for child in parent.get_children():
		if child.has_method("get_selected_block_info"):
			_inventory = child
			if _inventory.has_signal("selected_slot_changed"):
				_inventory.selected_slot_changed.connect(_on_selected_slot_changed)
			_update_selected_block_from_inventory()
			return

	push_warning("BlockInteraction: CreativeInventory не найден")


func _on_selected_slot_changed(_index: int) -> void:
	_update_selected_block_from_inventory()


func _update_selected_block_from_inventory() -> void:
	if _inventory == null or items == null:
		_selected_block_id = -1
		return

	var info = _inventory.get_selected_block_info()

	# [CHANGE 8] Безопасная цепочка: info → info.id → info.id.id
	if info == null or info.is_empty():
		_selected_block_id = -1
		return

	if not ("id" in info) or info.id == null:
		_selected_block_id = -1
		return

	var item_name = info.id.id  # String — имя предмета
	var resolved_id: int = items.getItemId(item_name)

	# [CHANGE 8] getItemId может вернуть null для несуществующего ключа
	if resolved_id == null:
		push_warning("BlockInteraction: предмет '%s' не найден в реестре" % item_name)
		_selected_block_id = -1
		return

	_selected_block_id = resolved_id


# ══════════════════════════════════════════════════
#  TERRAIN — поиск и настройка
# ══════════════════════════════════════════════════

func _find_and_setup_terrain() -> bool:
	# 1. Рекурсивный поиск от текущей сцены
	var current_scene := get_tree().current_scene
	if current_scene:
		_terrain = _find_terrain_recursive(current_scene)
		if _terrain:
			_setup_terrain_tool()
			return true

	# 2. Группа "voxel_terrain"
	_terrain = _find_terrain_in_tree()
	if _terrain:
		_setup_terrain_tool()
		return true

	# 3. Поднимаемся по дереву
	var parent := get_parent()
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
		var found := _find_terrain_recursive(child)
		if found:
			return found
	return null


func _find_terrain_in_tree() -> VoxelTerrain:
	var nodes := get_tree().get_nodes_in_group("voxel_terrain")
	if nodes.size() > 0 and nodes[0] is VoxelTerrain:
		return nodes[0]

	for node in get_tree().get_root().get_children():
		var terrain := _find_terrain_recursive(node)
		if terrain:
			return terrain
	return null


func _setup_terrain_tool() -> void:
	if _terrain == null:
		return

	_terrain_tool = _terrain.get_voxel_tool()
	_terrain_tool.channel = VoxelBuffer.CHANNEL_TYPE
	_terrain_tool.mode = VoxelTool.MODE_SET
	_voxel_size = 1.0

	if _raycast:
		_raycast.target_position = Vector3(0, 0, -reach_distance)

	var cham := ChameleonManager.get_instance()
	if cham:
		cham.connect_to_terrain(_terrain)

	# [CHANGE 11] Подписка на удаление terrain
	if not _terrain.tree_exiting.is_connected(_on_terrain_removed):
		_terrain.tree_exiting.connect(_on_terrain_removed)

	print("✅ Terrain найден: ", _terrain.name)
	terrain_found.emit(_terrain)


# [CHANGE 11] Реакция на удаление terrain из дерева
func _on_terrain_removed() -> void:
	print("⚠️ VoxelTerrain удалён из дерева")
	_terrain = null
	_terrain_tool = null
	terrain_lost.emit()


# [CHANGE 7] Гонка: после await проверяем повторно
func _on_node_added(node: Node) -> void:
	if _terrain != null:
		return
	if not (node is VoxelTerrain):
		return

	await get_tree().process_frame

	# После await terrain мог уже быть найден другим путём
	if _terrain != null:
		return
	if not is_instance_valid(node):
		return

	_terrain = node
	_setup_terrain_tool()


# ══════════════════════════════════════════════════
#  RAYCAST / ГЕОМЕТРИЯ
# ══════════════════════════════════════════════════

func _get_combined_target() -> Dictionary:
	var result := {
		"has_target": false,
		"position": Vector3i.ZERO,
		"place_position": Vector3i.ZERO,
		"face": "top",
		"normal": Vector3.ZERO,
	}

	# [CHANGE 4,5] Ранний выход при отсутствии камеры или terrain_tool
	if _camera == null or _terrain_tool == null:
		return result

	var origin := _camera.global_position
	var forward := -_camera.global_transform.basis.z.normalized()

	var hit_scene = _raycast.get_collider()
	#if hit_scene is BlockLogic:
		#result["has_target"] = true
		#result["position"] = hit_scene.position
		#result["place_position"] = hit_scene.previous_position
		#var normal := Vector3(hit_scene.previous_position - hit_scene.position)
		#result["face"] = _normal_to_face(normal)
		#result["normal"] = normal.normalized()
		#return result

	var hit = _terrain_tool.raycast(origin, forward, reach_distance)
	if hit:
		result["has_target"] = true
		result["position"] = hit.position
		result["place_position"] = hit.previous_position
		var normal := Vector3(hit.previous_position - hit.position)
		result["face"] = _normal_to_face(normal)
		result["normal"] = normal.normalized()

	return result


func _normal_to_face(normal: Vector3) -> String:
	if normal.y > 0.5:    return "top"
	elif normal.y < -0.5: return "bottom"
	elif normal.z < -0.5: return "north"
	elif normal.z > 0.5:  return "south"
	elif normal.x > 0.5:  return "east"
	elif normal.x < -0.5: return "west"
	return "top"


func _world_to_voxel(world_pos: Vector3) -> Vector3i:
	return Vector3i(floori(world_pos.x), floori(world_pos.y), floori(world_pos.z))


func _voxel_to_world(voxel_pos: Vector3i) -> Vector3:
	return Vector3(voxel_pos) + Vector3(0.5, 0.5, 0.5)


func _can_place_at(pos: Vector3i) -> bool:
	var block_world_pos := _voxel_to_world(pos)
	return global_position.distance_to(block_world_pos) > 1.5


# ══════════════════════════════════════════════════
#  ПУБЛИЧНЫЙ API
# ══════════════════════════════════════════════════

# [CHANGE 9] Была пустая функция — добавлен TODO
func set_selected_block(_block_id: String) -> void:
	# TODO: реализовать выбор блока по строковому id
	push_warning("BlockInteraction.set_selected_block() не реализован")


func get_selected_block() -> int:
	return _selected_block_id


func set_selected_texture(texture_name: String) -> void:
	_selected_texture = texture_name


func get_selected_texture() -> String:
	return _selected_texture


func get_terrain() -> VoxelTerrain:
	return _terrain


func has_terrain() -> bool:
	return _terrain != null and _terrain_tool != null


func set_terrain(terrain: VoxelTerrain) -> void:
	# Отписка от старого terrain
	if _terrain and is_instance_valid(_terrain) \
			and _terrain.tree_exiting.is_connected(_on_terrain_removed):
		_terrain.tree_exiting.disconnect(_on_terrain_removed)

	if terrain == null:
		_terrain = null
		_terrain_tool = null
		terrain_lost.emit()
		return

	_terrain = terrain
	_setup_terrain_tool()


func find_terrain() -> bool:
	return _find_and_setup_terrain()
