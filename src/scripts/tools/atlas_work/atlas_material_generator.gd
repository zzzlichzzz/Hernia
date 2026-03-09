@tool
extends Node
class_name AtlasMaterialGenerator

const AtlasCoordinates = preload("res://src/scripts/resources/atlas_coordinates.gd")

@export var material_names: Dictionary = {
	"opaque": "block_material_opaque.tres",
	"transparent": "block_material_transparent.tres",
	"foliage": "block_material_foliage.tres",
	"multi_face": "block_material_multi_face.tres"
}

const MATERIAL_OPAQUE = "opaque"
const MATERIAL_TRANSPARENT = "transparent"
const MATERIAL_FOLIAGE = "foliage"
const MATERIAL_MULTI_FACE = "multi_face"

var _opaque_shader: Shader = preload("res://src/shaders/blocks/block_opaque.gdshader")
var _transparent_shader: Shader = preload("res://src/shaders/blocks/block_transparent.gdshader")
var _foliage_shader: Shader = preload("res://src/shaders/blocks/block_foliage.gdshader")
var _multi_face_shader: Shader = preload("res://src/shaders/blocks/block_multi_face.gdshader")

var _atlas_coords: AtlasCoordinates = null

func _init():
	_load_atlas_coords()

func _load_atlas_coords():
	var coords_path = "res://src/assets/textures/atlas/block/block_coordinates.tres"
	if ResourceLoader.exists(coords_path):
		_atlas_coords = load(coords_path)
		print("Координаты атласа загружены")

func create_all_materials() -> Dictionary:
	print("СОЗДАНИЕ МАТЕРИАЛОВ")
	
	var results = {}
	
	var atlas_texture = _load_atlas_texture()
	if not atlas_texture:
		print("Не удалось загрузить текстуру атласа")
		return results
	
	results[MATERIAL_OPAQUE] = _create_shader_material(atlas_texture, _opaque_shader, MATERIAL_OPAQUE)
	results[MATERIAL_TRANSPARENT] = _create_shader_material(atlas_texture, _transparent_shader, MATERIAL_TRANSPARENT)
	results[MATERIAL_FOLIAGE] = _create_foliage_material(atlas_texture)
	results[MATERIAL_MULTI_FACE] = _create_multi_face_material(atlas_texture)
	
	var created_count = 0
	for type in results:
		if results[type] != null:
			created_count += 1
	
	print("Создано материалов: " + str(created_count) + "/4")
	return results

func _load_atlas_texture() -> Texture2D:
	var atlas_path = "res://src/assets/textures/atlas/block/block_atlas.png"
	if not ResourceLoader.exists(atlas_path):
		print("Атлас не найден: " + atlas_path)
		return null
	
	var texture = load(atlas_path) as Texture2D
	if texture == null:
		print("Не удалось загрузить текстуру атласа")
		return null
	
	print("Текстура атласа загружена: " + str(texture.get_width()) + "x" + str(texture.get_height()))
	return texture

func _create_shader_material(atlas_texture: Texture2D, shader: Shader, type_name: String) -> ShaderMaterial:
	var material = ShaderMaterial.new()
	material.shader = shader
	
	material.set_shader_parameter("atlas_texture", atlas_texture)
	material.set_shader_parameter("block_uv_offset", Vector2(0, 0))
	material.set_shader_parameter("block_uv_size", Vector2(1, 1))
	
	var path = "res://src/assets/textures/atlas/block/" + material_names[type_name]
	var result = ResourceSaver.save(material, path)
	
	if result == OK:
		print("Материал сохранен: " + path)
		return material
	return null

func _create_foliage_material(atlas_texture: Texture2D) -> ShaderMaterial:
	var material = ShaderMaterial.new()
	material.shader = _foliage_shader
	
	material.set_shader_parameter("atlas_texture", atlas_texture)
	material.set_shader_parameter("block_uv_offset", Vector2(0, 0))
	material.set_shader_parameter("block_uv_size", Vector2(1, 1))
	material.set_shader_parameter("alpha_scissor_threshold", 0.5)
	
	var path = "res://src/assets/textures/atlas/block/" + material_names[MATERIAL_FOLIAGE]
	var result = ResourceSaver.save(material, path)
	
	if result == OK:
		print("Материал для растительности сохранен: " + path)
		return material
	return null

func _create_multi_face_material(atlas_texture: Texture2D) -> ShaderMaterial:
	var material = ShaderMaterial.new()
	material.shader = _multi_face_shader
	
	material.set_shader_parameter("atlas_texture", atlas_texture)
	material.set_shader_parameter("top_uv_offset", Vector2(0, 0))
	material.set_shader_parameter("top_uv_size", Vector2(1, 1))
	material.set_shader_parameter("bottom_uv_offset", Vector2(0, 0))
	material.set_shader_parameter("bottom_uv_size", Vector2(1, 1))
	material.set_shader_parameter("side_uv_offset", Vector2(0, 0))
	material.set_shader_parameter("side_uv_size", Vector2(1, 1))
	material.set_shader_parameter("overlay_uv_offset", Vector2(0, 0))
	material.set_shader_parameter("overlay_uv_size", Vector2(0, 0))
	material.set_shader_parameter("overlay_enabled", false)
	
	var path = "res://src/assets/textures/atlas/block/" + material_names[MATERIAL_MULTI_FACE]
	var result = ResourceSaver.save(material, path)
	
	if result == OK:
		print("Многоликий материал сохранен: " + path)
		return material
	return null

static func get_opaque() -> ShaderMaterial:
	var path = "res://src/assets/textures/atlas/block/block_material_opaque.tres"
	if ResourceLoader.exists(path):
		return load(path)
	return null

static func get_transparent() -> ShaderMaterial:
	var path = "res://src/assets/textures/atlas/block/block_material_transparent.tres"
	if ResourceLoader.exists(path):
		return load(path)
	return null

static func get_foliage() -> ShaderMaterial:
	var path = "res://src/assets/textures/atlas/block/block_material_foliage.tres"
	if ResourceLoader.exists(path):
		return load(path)
	return null

static func get_multi_face() -> ShaderMaterial:
	var path = "res://src/assets/textures/atlas/block/block_material_multi_face.tres"
	if ResourceLoader.exists(path):
		return load(path)
	return null
