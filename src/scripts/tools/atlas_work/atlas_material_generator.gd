@tool
extends Node
class_name AtlasMaterialGenerator
# Создает шейдерные материалы из атласа для разных типов блоков (стиль демо)

const AtlasCoordinates = preload("res://src/scripts/resources/atlas_coordinates.gd")
const AtlasLogger = preload("res://src/scripts/tools/atlas_work/atlas_logger.gd")
var log: AtlasLogger

@export var material_names: Dictionary = {
	"opaque": "block_material_opaque.tres",
	"transparent": "block_material_transparent.tres",
	"foliage": "block_material_foliage.tres"
}

const MATERIAL_OPAQUE = "opaque"
const MATERIAL_TRANSPARENT = "transparent"
const MATERIAL_FOLIAGE = "foliage"

# Загружаем шейдеры для разных типов
var _opaque_shader: Shader = preload("res://src/shaders/blocks/block_opaque.gdshader")
var _transparent_shader: Shader = preload("res://src/shaders/blocks/block_transparent.gdshader")
var _foliage_shader: Shader = preload("res://src/shaders/blocks/block_foliage.gdshader")

var _atlas_coords: AtlasCoordinates = null

func _init():
	log = AtlasLogger.new("atlas_material_log.txt")
	_load_atlas_coords()

func _load_atlas_coords():
	var coords_path = PathManager.game("res://src/assets/textures/atlas/block_coordinates.tres")
	if ResourceLoader.exists(coords_path):
		_atlas_coords = load(coords_path)
		log.success("Координаты атласа загружены")

func create_all_materials() -> Dictionary:
	log.section("СОЗДАНИЕ МАТЕРИАЛОВ (СТИЛЬ ДЕМО - ШЕЙДЕРНАЯ ВЕРСИЯ)")
	
	var results = {}
	
	# Загружаем текстуру
	var atlas_texture = _load_atlas_texture()
	if not atlas_texture:
		log.error("Не удалось загрузить текстуру атласа")
		return results
	
	# Создаем все три типа материалов
	results[MATERIAL_OPAQUE] = _create_opaque_material(atlas_texture)
	results[MATERIAL_TRANSPARENT] = _create_transparent_material(atlas_texture)
	results[MATERIAL_FOLIAGE] = _create_foliage_material(atlas_texture)
	
	# Проверяем результат
	var created_count = 0
	for type in results:
		if results[type] != null:
			created_count += 1
	
	log.success("Создано материалов: " + str(created_count) + "/3")
	return results

func _load_atlas_texture() -> Texture2D:
	var atlas_png = PathManager.game("res://src/assets/textures/atlas/block_atlas.png")
	
	if not FileAccess.file_exists(atlas_png):
		log.error("PNG атлас не найден: " + atlas_png)
		return null
	
	var img = Image.load_from_file(atlas_png)
	if not img:
		log.error("Не удалось загрузить изображение")
		return null
	
	var texture = ImageTexture.create_from_image(img)
	log.success("Текстура атласа загружена: " + str(texture.get_width()) + "x" + str(texture.get_height()))
	return texture

func _create_opaque_material(atlas_texture: Texture2D) -> ShaderMaterial:
	var material = ShaderMaterial.new()
	material.shader = _opaque_shader
	
	# 🔥 УБРАНО: material.texture_filter - не работает с ShaderMaterial
	# Фильтрация задается в шейдере через filter_nearest
	
	material.set_shader_parameter("atlas_texture", atlas_texture)
	material.set_shader_parameter("block_uv_offset", Vector2(0, 0))
	material.set_shader_parameter("block_uv_size", Vector2(1, 1))
	
	var path = PathManager.game("res://src/assets/textures/atlas/" + material_names[MATERIAL_OPAQUE])
	var result = ResourceSaver.save(material, path)
	
	if result == OK:
		log.success("Непрозрачный материал сохранен: " + path)
		return material
	return null

func _create_transparent_material(atlas_texture: Texture2D) -> ShaderMaterial:
	var material = ShaderMaterial.new()
	material.shader = _transparent_shader
	
	material.set_shader_parameter("atlas_texture", atlas_texture)
	material.set_shader_parameter("block_uv_offset", Vector2(0, 0))
	material.set_shader_parameter("block_uv_size", Vector2(1, 1))
	
	var path = PathManager.game("res://src/assets/textures/atlas/" + material_names[MATERIAL_TRANSPARENT])
	var result = ResourceSaver.save(material, path)
	
	if result == OK:
		log.success("Прозрачный материал сохранен: " + path)
		return material
	return null

func _create_foliage_material(atlas_texture: Texture2D) -> ShaderMaterial:
	var material = ShaderMaterial.new()
	material.shader = _foliage_shader
	
	material.set_shader_parameter("atlas_texture", atlas_texture)
	material.set_shader_parameter("block_uv_offset", Vector2(0, 0))
	material.set_shader_parameter("block_uv_size", Vector2(1, 1))
	material.set_shader_parameter("alpha_scissor_threshold", 0.6)
	
	var path = PathManager.game("res://src/assets/textures/atlas/" + material_names[MATERIAL_FOLIAGE])
	var result = ResourceSaver.save(material, path)
	
	if result == OK:
		log.success("Материал для растительности сохранен: " + path)
		return material
	return null

# Статические методы для получения материалов
static func get_opaque() -> ShaderMaterial:
	var path = PathManager.game("res://src/assets/textures/atlas/block_material_opaque.tres")
	if ResourceLoader.exists(path):
		return load(path)
	return null
	
static func get_transparent() -> ShaderMaterial:
	var path = PathManager.game("res://src/assets/textures/atlas/block_material_transparent.tres")
	if ResourceLoader.exists(path):
		return load(path)
	return null
	
static func get_foliage() -> ShaderMaterial:
	var path = PathManager.game("res://src/assets/textures/atlas/block_material_foliage.tres")
	if ResourceLoader.exists(path):
		return load(path)
	return null
