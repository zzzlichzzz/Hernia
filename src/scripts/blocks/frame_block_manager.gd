extends Node3D
class_name FrameBlockManager

const FACES = ["top", "bottom", "north", "south", "east", "west"]
const FACE_TO_SURFACE = {
	"top": 0,
	"bottom": 1,
	"north": 2,
	"south": 3,
	"east": 4,
	"west": 5
}
const DEFAULT_TEXTURE = "framed_block"

var _blocks: Dictionary = {}
var _atlas_coords: Resource = null
var _atlas_texture: Texture2D = null
var _base_shader: Shader = null
var _frame_mesh: Mesh = null
var _terrain: VoxelTerrain = null

# Collision layer для frame-блоков
const FRAME_COLLISION_LAYER = 2  # Layer 2 (бит 1)

const ATLAS_COORDS_PATH = "res://src/assets/textures/atlas/block_coordinates.tres"
const ATLAS_TEXTURE_PATH = "res://src/assets/textures/atlas/block_atlas.png"
const SHADER_PATH = "res://src/shaders/blocks/block_opaque.gdshader"
const FRAME_MESH_PATH = "res://src/assets/blocks/models/frame_cube.obj"


func _ready():
	_load_resources()
	print("✅ FrameBlockManager готов")


func set_terrain(terrain: VoxelTerrain):
	_terrain = terrain
	print("✅ FrameBlockManager привязан к terrain: ", terrain.name)


func _load_resources():
	if ResourceLoader.exists(ATLAS_COORDS_PATH):
		_atlas_coords = load(ATLAS_COORDS_PATH)
		print("   ✅ Координаты атласа загружены")
	
	if ResourceLoader.exists(ATLAS_TEXTURE_PATH):
		_atlas_texture = load(ATLAS_TEXTURE_PATH)
		print("   ✅ Текстура атласа загружена")
	
	if ResourceLoader.exists(SHADER_PATH):
		_base_shader = load(SHADER_PATH)
		print("   ✅ Шейдер загружен")
	
	if ResourceLoader.exists(FRAME_MESH_PATH):
		_frame_mesh = load(FRAME_MESH_PATH)
		print("   ✅ Frame меш загружен (surfaces: ", _frame_mesh.get_surface_count(), ")")
	else:
		push_error("   ❌ Frame меш не найден: " + FRAME_MESH_PATH)


func create_frame_block(pos: Vector3i, initial_textures: Dictionary = {}) -> bool:
	if _blocks.has(pos):
		return false
	
	if _frame_mesh == null:
		push_error("❌ Frame меш не загружен!")
		return false
	
	# Инициализируем текстуры
	var textures = {}
	for face in FACES:
		textures[face] = initial_textures.get(face, DEFAULT_TEXTURE)
	
	# Создаём MeshInstance3D
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = _frame_mesh
	mesh_instance.name = "FrameBlock_%d_%d_%d" % [pos.x, pos.y, pos.z]
	
	# Применяем материалы
	_apply_materials(mesh_instance, textures)
	
	# ═══ СОЗДАЁМ КОЛЛИЗИЮ ═══
	var static_body = StaticBody3D.new()
	static_body.name = "FrameBody_%d_%d_%d" % [pos.x, pos.y, pos.z]
	static_body.collision_layer = FRAME_COLLISION_LAYER
	static_body.collision_mask = 0  # Не реагирует на других
	
	var collision_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(1, 1, 1)
	collision_shape.shape = box_shape
	collision_shape.position = Vector3(0.5, 0.5, 0.5)  # Центр куба
	
	static_body.add_child(collision_shape)
	static_body.add_child(mesh_instance)
	
	# Позиционируем
	if _terrain:
		_terrain.add_child(static_body)
	else:
		add_child(static_body)
	
	static_body.position = Vector3(pos)
	
	# Сохраняем метаданные для идентификации
	static_body.set_meta("frame_block_pos", pos)
	
	_blocks[pos] = {
		"textures": textures,
		"mesh_instance": mesh_instance,
		"static_body": static_body
	}
	
	print("✅ Frame-блок: ", pos)
	return true


func remove_frame_block(pos: Vector3i) -> bool:
	if not _blocks.has(pos):
		return false
	
	var data = _blocks[pos]
	if data["static_body"]:
		data["static_body"].queue_free()
	
	_blocks.erase(pos)
	print("🗑️ Frame-блок удалён: ", pos)
	return true


func set_face_texture(pos: Vector3i, face: String, texture_name: String) -> bool:
	if not _blocks.has(pos):
		return false
	if not face in FACES:
		return false
	
	_blocks[pos]["textures"][face] = texture_name
	
	var mesh_instance = _blocks[pos]["mesh_instance"]
	var surface_idx = FACE_TO_SURFACE[face]
	var material = _create_material_for_texture(texture_name)
	mesh_instance.set_surface_override_material(surface_idx, material)
	
	print("🎨 ", pos, " ", face, " → ", texture_name)
	return true


func get_face_texture(pos: Vector3i, face: String) -> String:
	if _blocks.has(pos) and _blocks[pos]["textures"].has(face):
		return _blocks[pos]["textures"][face]
	return ""


func has_frame_block(pos: Vector3i) -> bool:
	return _blocks.has(pos)


func get_block_count() -> int:
	return _blocks.size()


## Получает позицию frame-блока из коллизии
func get_block_pos_from_collider(collider: Object) -> Vector3i:
	if collider and collider.has_meta("frame_block_pos"):
		return collider.get_meta("frame_block_pos")
	return Vector3i(-99999, -99999, -99999)  # Невалидная позиция


## Проверяет, является ли коллайдер frame-блоком
func is_frame_collider(collider: Object) -> bool:
	return collider and collider.has_meta("frame_block_pos")


# ═══════════════════════════════════════════════════════════
#  МАТЕРИАЛЫ
# ═══════════════════════════════════════════════════════════

func _apply_materials(mesh_instance: MeshInstance3D, textures: Dictionary):
	for face in FACES:
		var surface_idx = FACE_TO_SURFACE[face]
		var tex_name = textures.get(face, DEFAULT_TEXTURE)
		var material = _create_material_for_texture(tex_name)
		mesh_instance.set_surface_override_material(surface_idx, material)


func _create_material_for_texture(texture_name: String) -> Material:
	if _base_shader == null or _atlas_texture == null:
		return _create_fallback_material(texture_name)
	
	var material = ShaderMaterial.new()
	material.shader = _base_shader
	material.set_shader_parameter("atlas_texture", _atlas_texture)
	
	var uv_data = _get_uv_for_texture(texture_name)
	material.set_shader_parameter("block_uv_offset", uv_data["offset"])
	material.set_shader_parameter("block_uv_size", uv_data["size"])
	
	return material


func _create_fallback_material(texture_name: String) -> Material:
	var colors = {
		"stone": Color(0.5, 0.5, 0.5),
		"dirt": Color(0.6, 0.4, 0.2),
		"grass_block_top": Color(0.2, 0.8, 0.2),
	}
	
	var color = colors.get(texture_name, Color(1, 0, 1))
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat


func _get_uv_for_texture(texture_name: String) -> Dictionary:
	var default_result = {"offset": Vector2.ZERO, "size": Vector2(1, 1)}
	
	if _atlas_coords == null:
		return default_result
	
	var coords = _atlas_coords.coordinates.get(texture_name, null)
	if coords == null:
		return default_result
	
	var uv = coords["uv"]
	return {
		"offset": Vector2(uv["left"], uv["top"]),
		"size": Vector2(uv["right"] - uv["left"], uv["bottom"] - uv["top"])
	}


# ═══════════════════════════════════════════════════════════
#  СОХРАНЕНИЕ / ЗАГРУЗКА
# ═══════════════════════════════════════════════════════════

func save_to_file(path: String) -> bool:
	var save_data = {}
	for pos in _blocks:
		var key = "%d,%d,%d" % [pos.x, pos.y, pos.z]
		save_data[key] = _blocks[pos]["textures"]
	
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data, "\t"))
		file.close()
		print("✅ Frame-блоки сохранены: ", path)
		return true
	return false


func load_from_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return false
	
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	file.close()
	
	if error != OK:
		return false
	
	for pos in _blocks.keys():
		remove_frame_block(pos)
	
	var data = json.get_data()
	for key in data:
		var parts = key.split(",")
		var pos = Vector3i(int(parts[0]), int(parts[1]), int(parts[2]))
		create_frame_block(pos, data[key])
	
	print("✅ Frame-блоки загружены: ", _blocks.size())
	return true
