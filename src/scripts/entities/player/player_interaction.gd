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
var _selected_block_id: String = ""
var _selected_texture: String = "stone"

var _block_to_texture: Dictionary = {
	1: "grass_block_top",
	2: "cherry_planks",
	3: "cherry_planks",
	4: "dirt",
	5: "stone"
}
var _inventory: Node = null

var _chameleon_mgr: Node = null

signal block_broken(position: Vector3i, block_id: int)
signal block_placed(position: Vector3i, block_id: int)
signal target_changed(position: Vector3i, has_target: bool)
signal terrain_found(terrain: VoxelTerrain)
signal terrain_lost()

var items: ItemArrayRegistry
var item_path = "res://src/data/items/items.tres"

# ══════════════════════════════════════════
#  МУЛЬТИПЛЕЕР
# ══════════════════════════════════════════
var _is_local: bool = true
var _network_id: int = 0
var _nam: NetworkActionManager = null
# ══════════════════════════════════════════


func _init() -> void:
	items = load(item_path)


func _ready():
	# ── Мультиплеер: определить роль ─────────
	_setup_network()

	await get_tree().process_frame
	_find_inventory()
	if search_terrain_on_ready:
		_find_and_setup_terrain()
	get_tree().node_added.connect(_on_node_added)

	if _raycast:
		_raycast.target_position = Vector3(0, 0, -reach_distance)

	_chameleon_mgr = ChameleonManager.get_instance()
	if _chameleon_mgr:
		print("✅ ChameleonManager подключён к PlayerInteraction")
	else:
		push_warning("⚠️ ChameleonManager autoload не найден")


# ══════════════════════════════════════════════════
#  МУЛЬТИПЛЕЕР: ИНИЦИАЛИЗАЦИЯ
# ══════════════════════════════════════════════════

func _setup_network() -> void:
	var parent = get_parent()

	# Определяем роль из BasePlayer
	if parent is BasePlayer:
		_is_local = (parent as BasePlayer).is_local
		_network_id = (parent as BasePlayer).network_id
	else:
		# Нет BasePlayer → одиночная игра, всё работает локально
		_is_local = true
		_network_id = 0

	# Удалённые игроки: модуль полностью выключен
	if not _is_local:
		set_process(false)
		set_physics_process(false)
		return

	# Ищем NAM для мультиплеера
	_nam = _find_nam()
	if _nam:
		_nam.on_action("block_break", _on_remote_block_break)
		_nam.on_action("block_place", _on_remote_block_place)
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


# ══════════════════════════════════════════════════
#  МУЛЬТИПЛЕЕР: ОТПРАВКА
# ══════════════════════════════════════════════════

func _send_block_break(pos: Vector3i) -> void:
	if _nam == null:
		return
	_nam.send_action("block_break", [_network_id, Vector3(pos)])


func _send_block_place(pos: Vector3i, voxel_id: int) -> void:
	if _nam == null:
		return
	_nam.send_action("block_place", [_network_id, Vector3(pos), voxel_id])


# ══════════════════════════════════════════════════
#  МУЛЬТИПЛЕЕР: ПРИЁМ ОТ ДРУГИХ ИГРОКОВ
# ══════════════════════════════════════════════════

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
	block_broken.emit(pos, 0)


func _on_remote_block_place(peer_id: int, data: Dictionary) -> void:
	if _terrain_tool == null:
		return

	var pos := Vector3i(data["block_position"])
	var voxel_id: int = data["block_id"]

	_terrain_tool.value = voxel_id
	_terrain_tool.do_point(pos)
	block_placed.emit(pos, voxel_id)


# ══════════════════════════════════════════════════
#  СУЩЕСТВУЮЩИЙ КОД (без изменений кроме отмеченных)
# ══════════════════════════════════════════════════

func _find_inventory():
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
		if not info.is_empty() and info.has("id") and info.id != "":
			_selected_block_id = info.id
			print("PlayerInteraction: выбран блок ID ", _selected_block_id)
		else:
			_selected_block_id = ""
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


func _process(delta):
	if _terrain == null or _terrain_tool == null:
		return

	if _is_chat_or_inventory_open():
		return

	if _break_timer > 0:
		_break_timer -= delta
	if _place_timer > 0:
		_place_timer -= delta

	_handle_input()


func _is_chat_or_inventory_open() -> bool:
	var chat = get_tree().get_first_node_in_group("chat")
	if chat and chat.has_method("is_chat_open"):
		if chat.is_chat_open():
			return true

	var player = get_parent()
	if player and "inventory_open" in player:
		if player.inventory_open:
			return true

	return false


func _handle_input():
	var player = get_parent()
	var inventory_is_open = false
	if player and "inventory_open" in player:
		inventory_is_open = player.inventory_open

	if inventory_is_open:
		return

	var target = _get_combined_target()

	if not target["has_target"]:
		return

	target_changed.emit(target["position"], true)

	# ЛКМ — сломать
	if Input.is_action_pressed("break_block") and _break_timer <= 0:
		_break_block(target["position"])
		_break_timer = break_cooldown

	# ПКМ — поставить / покрасить хамелеон
	if Input.is_action_pressed("place_block") and _place_timer <= 0:
		if _try_paint_chameleon(target["position"]):
			pass
		else:
			var place_pos = target["place_position"]
			if _can_place_at(place_pos):
				_place_block(place_pos)
		_place_timer = place_cooldown

	# Средняя кнопка — выбрать
	if Input.is_action_just_pressed("pick_block"):
		_pick_block(target["position"])


func _try_paint_chameleon(hit_pos: Vector3i) -> bool:
	var cham = ChameleonManager.get_instance()
	if cham == null:
		return false

	if _terrain_tool == null:
		return false

	var voxel_id = _terrain_tool.get_voxel(hit_pos)
	if not cham.is_chameleon_block(voxel_id):
		return false

	if _selected_block_id == "":
		return false

	var success = cham.paint_chameleon_by_block_id(hit_pos, items.getItemBlockID(_selected_block_id))

	if success:
		print("🎨 Хамелеон покрашен: ", hit_pos, " блоком ID: ", _selected_block_id)
	else:
		var tex = _block_to_texture.get(_selected_block_id, "")
		if tex != "":
			success = cham.paint_chameleon(hit_pos, tex)
			if success:
				print("🎨 Хамелеон покрашен: ", hit_pos, " текстурой: ", tex)

	return success


func _get_combined_target() -> Dictionary:
	var result = {
		"has_target": false,
		"position": Vector3i.ZERO,
		"place_position": Vector3i.ZERO,
		"face": "top",
		"normal": Vector3.ZERO
	}

	var origin = _camera.global_position
	var forward = -_camera.global_transform.basis.z.normalized()

	var hit = _terrain_tool.raycast(origin, forward, reach_distance)
	if hit:
		result["has_target"] = true
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


# ══════════════════════════════════════════════════
#  ЛОМАНИЕ БЛОКА (+ сеть)
# ══════════════════════════════════════════════════

func _break_block(pos: Vector3i):
	if _terrain_tool == null:
		return
	var old_id = _terrain_tool.get_voxel(pos)
	if old_id == 0:
		return

	# Хамелеон: очистка при разрушении
	var cham = ChameleonManager.get_instance()
	if cham and cham.is_chameleon_block(old_id):
		cham.remove_chameleon(pos)

	_terrain_tool.value = 0
	_terrain_tool.do_point(pos)
	var new_id = _terrain_tool.get_voxel(pos)
	if new_id == 0:
		print("⛏️ Блок сломан: ", pos)
		block_broken.emit(pos, old_id)
		# ── Мультиплеер: отправить другим ────
		_send_block_break(pos)
	else:
		print("❌ Не удалось сломать блок: ", pos)


# ══════════════════════════════════════════════════
#  УСТАНОВКА БЛОКА (+ сеть)
# ══════════════════════════════════════════════════

func _place_block(pos: Vector3i):
	if _terrain_tool == null:
		return
	var current = _terrain_tool.get_voxel(pos)
	if current != 0:
		return

	if not items.isItemBlock(_selected_block_id):
		return

	var voxel_id: int = items.getItemBlockID(_selected_block_id)
	_terrain_tool.value = voxel_id
	_terrain_tool.do_point(pos)
	var new_id = _terrain_tool.get_voxel(pos)
	if new_id == voxel_id:
		print("🧱 Блок установлен: ", pos)
		block_placed.emit(pos, _selected_block_id)
		# ── Мультиплеер: отправить другим ────
		_send_block_place(pos, voxel_id)


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

func set_selected_block(block_id: String):
	print("🧱 Блок выбран: ID=", block_id)
	pass

func get_selected_block() -> String:
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
