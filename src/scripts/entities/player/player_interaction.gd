extends Node3D

@onready var _camera: Camera3D = get_node("../Neck/Camera3D")
@onready var _raycast: RayCast3D = get_node("../Neck/Camera3D/RayCast3D")


@export var break_cooldown: float = 0.2
@export var place_cooldown: float = 0.2
# @export var search_terrain_on_ready: bool = true

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

const FRAME_COLLISION_LAYER = 2
var _inventory: Node = null

# ══════════════════════════════════════════
#  ХАМЕЛЕОН — ссылка на менеджер
# ══════════════════════════════════════════
var _chameleon_mgr: Node = null
# ══════════════════════════════════════════

signal block_broken(position: Vector3i, block_id: int)

signal target_changed(position: Vector3i, has_target: bool)
signal terrain_lost()

var items: ItemArrayRegistry
var world_path = "res://src/script/world/world.gd"
var item_path = "res://src/data/items/items.tres"


var player: Player


func _ready():
	await get_tree().process_frame
	_find_inventory()
	#get_tree().node_added.connect(player.getWorld()._on_node_added)
	
	player = get_parent()
	# ══════════════════════════════════════════
	#  ХАМЕЛЕОН — получаем менеджер
	# ══════════════════════════════════════════
	_chameleon_mgr = ChameleonManager.get_instance()
	if _chameleon_mgr:
		print("✅ ChameleonManager подключён к PlayerInteraction")
	else:
		push_warning("⚠️ ChameleonManager autoload не найден")
	# ══════════════════════════════════════════
	
	print("✅ FrameBlockManager создан")


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



func _process(delta):
	if getPlayer() == null:
		return
	if getPlayer().getWorld()._terrain == null or getPlayer().getWorld()._terrain_tool == null:
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
	
	var players = get_tree().get_first_node_in_group("player")
	if players and players.has("inventory_open"):
		if players.inventory_open:
			return true
	
	return false


func _handle_input():
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
	
	# ПКМ — поставить / редактировать / покрасить хамелеон
	if Input.is_action_pressed("place_block") and _place_timer <= 0:

		# ══════════════════════════════════════════
		#  ХАМЕЛЕОН — проверяем перед обычным размещением
		# ══════════════════════════════════════════
		if _try_paint_chameleon(target["position"]):
			pass  # Хамелеон покрашен, ничего больше не делаем
		# ══════════════════════════════════════════
		else:
			var place_pos = target["place_position"]
			if player.getWorld()._can_place_at(global_position, place_pos):
				player.getWorld()._place_block(_selected_block_id, place_pos)
		_place_timer = place_cooldown
	
	# Средняя кнопка — выбрать
	if Input.is_action_just_pressed("pick_block"):
		if target["is_frame"]:
			var face = target["face"]
			print("👆 Скопирована текстура: ", _selected_texture)
		else:
			_pick_block(target["position"])


# ══════════════════════════════════════════════════════════
#  ХАМЕЛЕОН — основной метод покраски
# ══════════════════════════════════════════════════════════

func _try_paint_chameleon(hit_pos: Vector3i) -> bool:
	var cham = ChameleonManager.get_instance()
	if cham == null:
		return false
	
	if getPlayer().getWorld()._terrain_tool == null:
		return false
	
	var voxel_id = getPlayer().getWorld()._terrain_tool.get_voxel(hit_pos)
	if not cham.is_chameleon_block(voxel_id):
		return false
	
	if _selected_block_id == "":
		return false
	
	var success = cham.paint_chameleon_by_block_id(hit_pos, getPlayer().getWorld().getItems().getItemBlockID(_selected_block_id))
	
	if success:
		print("🎨 Хамелеон покрашен: ", hit_pos, " блоком ID: ", _selected_block_id)
	else:
		var tex = _block_to_texture.get(_selected_block_id, "")
		if tex != "":
			success = cham.paint_chameleon(hit_pos, tex)
			if success:
				print("🎨 Хамелеон покрашен: ", hit_pos, " текстурой: ", tex)
	
	return success

# ══════════════════════════════════════════════════════════


func _get_combined_target() -> Dictionary:
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
	
	if _raycast and _raycast.is_colliding():
		var collider = _raycast.get_collider()
		
	
	var hit = getPlayer().getWorld()._terrain_tool.raycast(origin, forward, getPlayer().reach_distance)
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





func _pick_block(pos: Vector3i):
	var block_id = getPlayer().getWorld()._terrain_tool.get_voxel(pos)
	if block_id == 0:
		return
	print("👆 Выбран блок ID: ", block_id)




# ═══ ПУБЛИЧНЫЙ API ═══

func set_selected_block(block_id: String):
	#_selected_block_id = block_id
	#_selected_texture = _block_to_texture.get(block_id, "stone")
	print("🧱 Блок выбран: ID=", block_id, " текстура=")
	pass

func get_selected_block() -> String:
	return _selected_block_id

func set_selected_texture(texture_name: String):
	_selected_texture = texture_name

func get_selected_texture() -> String:
	return _selected_texture

func getPlayer() -> Player:
	return player

func set_terrain(terrain: VoxelTerrain):
	if terrain == null:
		getPlayer().getWorld()._terrain = null
		getPlayer().getWorld()._terrain_tool = null
		terrain_lost.emit()
		return
	getPlayer().getWorld()._terrain = terrain
	getPlayer().getWorld()._setup_terrain_tool()

func find_terrain() -> bool:
	return getPlayer().getWorld()._find_and_setup_terrain()
