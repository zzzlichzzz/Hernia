@tool
extends Node
class_name BlockMaterialApplier

# 🔥 ИСПРАВЛЕНО: теперь используем пути внутри проекта
var BLOCKS_FOLDER = "res://src/data/blocks/definitions/"
var LIBRARY_PATH = "res://src/data/blocks/voxel_blocky_library.tres"
var ATLAS_COORDS_PATH = "res://src/assets/textures/atlas/block_coordinates.tres"

var debug_mode: bool = true

# Используем AtlasMaterialGenerator
var _atlas_material_generator: AtlasMaterialGenerator = null
var _logger = null

func run():
	if debug_mode:
		print("🎨 BLOCK MATERIAL APPLIER: Применение материалов с текстурами из атласа")
		print("📁 LIBRARY_PATH: ", LIBRARY_PATH)
		print("📁 ATLAS_COORDS_PATH: ", ATLAS_COORDS_PATH)
	
	_init_logger()
	_init_atlas_material_generator()
	
	var library = load(LIBRARY_PATH)
	if not library:
		if debug_mode:
			print("❌ Не удалось загрузить библиотеку: ", LIBRARY_PATH)
		return
	
	# Загружаем координаты атласа один раз
	var atlas_coords = _load_atlas_coords()
	if not atlas_coords:
		if debug_mode:
			print("❌ Не удалось загрузить координаты атласа")
			print("   Путь: ", ATLAS_COORDS_PATH)
		return
	
	if debug_mode:
		print("✅ Координаты атласа загружены")
		print("   Блоков в атласе: ", atlas_coords.coordinates.size())
	
	var definitions = _load_definitions()
	if definitions.is_empty():
		if debug_mode:
			print("⚠️ Нет определений блоков")
		return
	
	var applied_count = 0
	var materials_cache = {}
	
	for block_name in definitions:
		var def = definitions[block_name]
		
		if debug_mode:
			print("\n🔧 Обработка: ", block_name)
		
		var material_type = _get_material_type_from_def(def)
		var texture_name = def.texture_name
		if texture_name.is_empty():
			texture_name = block_name
		
		# Получаем материал по типу
		var material: ShaderMaterial
		if material_type in materials_cache:
			material = materials_cache[material_type]
		else:
			material = _load_material(material_type)
			if material:
				materials_cache[material_type] = material
			else:
				if debug_mode:
					print("   ⚠️ Не удалось загрузить материал типа: ", material_type)
				continue
		
		# Проверяем наличие текстуры в атласе
		if atlas_coords.coordinates and texture_name in atlas_coords.coordinates:
			var data = atlas_coords.coordinates[texture_name]
			var offset = Vector2(data.uv.left, data.uv.top)
			var size = Vector2(
				data.uv.right - data.uv.left,
				data.uv.bottom - data.uv.top
			)
			
			if debug_mode:
				print("   ✅ Текстура '", texture_name, "' найдена:")
				print("      offset: (", offset.x, ", ", offset.y, ")")
				print("      size: (", size.x, ", ", size.y, ")")
			
			# Создаем копию материала с уникальными UV
			var block_material = material.duplicate()
			block_material.set_shader_parameter("block_uv_offset", offset)
			block_material.set_shader_parameter("block_uv_size", size)
			
			# Применяем к модели в библиотеке
			applied_count += _apply_material_to_library(library, block_name, block_material)
		else:
			if debug_mode:
				print("   ⚠️ Текстура '", texture_name, "' не найдена в атласе")
				print("      Доступные текстуры: ", atlas_coords.coordinates.keys())
	
	if applied_count > 0:
		var result = ResourceSaver.save(library, LIBRARY_PATH)
		if result == OK:
			if debug_mode:
				print("\n✅ Библиотека сохранена (", applied_count, " материалов применено)")
		else:
			if debug_mode:
				print("\n⚠️ Ошибка сохранения библиотеки: ", result)
	else:
		if debug_mode:
			print("\n⚠️ Нет примененных материалов")

func _apply_material_to_library(library, block_name: String, material: ShaderMaterial) -> int:
	"""Ищет модель в библиотеке по имени и применяет материал"""
	var applied = 0
	
	for i in range(library.models.size()):
		var model = library.models[i]
		if model and model.resource_name == block_name:
			if model is VoxelBlockyModelMesh:
				var surface_count = model.mesh.get_surface_count() if model.mesh else 1
				for surface_idx in range(surface_count):
					model.set_material_override(surface_idx, material)
				if debug_mode:
					print("   ✅ Материал применен к модели '", block_name, "' (ID: ", i, ")")
				applied += 1
			break
	
	return applied

func _init_logger():
	# 🔥 ИСПРАВЛЕНО: убираем дублирование user://
	var log_path = "user://atlas_material_log.txt"
	var LoggerClass = load("res://src/scripts/tools/atlas_work/atlas_logger.gd")
	if LoggerClass:
		_logger = LoggerClass.new(log_path)
	else:
		if debug_mode:
			print("⚠️ Не удалось загрузить AtlasLogger")

# Загрузка координат атласа
func _load_atlas_coords() -> Resource:
	if ResourceLoader.exists(ATLAS_COORDS_PATH):
		if debug_mode:
			print("📁 Загрузка координат из: ", ATLAS_COORDS_PATH)
		var coords = load(ATLAS_COORDS_PATH)
		if coords and coords.has_method("get_uv"):
			return coords
		return coords
	else:
		if debug_mode:
			print("⚠️ Координаты не найдены: ", ATLAS_COORDS_PATH)
	return null

func _init_atlas_material_generator():
	var generator_path = "res://src/scripts/tools/atlas_work/atlas_material_generator.gd"
	if ResourceLoader.exists(generator_path):
		var generator_script = load(generator_path)
		if generator_script:
			_atlas_material_generator = generator_script.new()

# 🔥 ИСПРАВЛЕНО: правильные методы из AtlasMaterialGenerator
func _load_material(material_type: String) -> ShaderMaterial:
	# Создаём экземпляр AtlasMaterialGenerator для доступа к методам
	var material_gen = AtlasMaterialGenerator.new()
	
	match material_type:
		"opaque":
			return material_gen._create_opaque_material(null)
		"transparent":
			return material_gen._create_transparent_material(null)
		"foliage":
			return material_gen._create_foliage_material(null)
	return null

func _load_definitions() -> Dictionary:
	var definitions = {}
	var def_files = _find_definition_files()
	
	for file_path in def_files:
		var def_resource = load(file_path)
		if def_resource and def_resource is BlockDefinition:
			definitions[def_resource.block_name] = def_resource
			if debug_mode:
				print("   📦 Загружено определение: ", def_resource.block_name, 
					  " (текстура: ", def_resource.texture_name, ")")
	
	return definitions

func _find_definition_files() -> Array:
	var files = []
	var dir = DirAccess.open(BLOCKS_FOLDER)
	if not dir:
		return files
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres") and file_name != "block_definition.gd":
			files.append(BLOCKS_FOLDER + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	
	return files

func _get_material_type_from_def(def: BlockDefinition) -> String:
	if def.has_method("get_material_type"):
		return def.get_material_type()
	
	# Пробуем получить из свойства
	if "material_type" in def and def.get("material_type") != null:
		return def.material_type
	
	# Используем enum
	if "material_type_enum" in def:
		match def.material_type_enum:
			def.MaterialType.OPAQUE:
				return "opaque"
			def.MaterialType.TRANSPARENT:
				return "transparent"
			def.MaterialType.FOLIAGE:
				return "foliage"
	
	return "opaque"

static func apply(debug: bool = true):
	var instance = BlockMaterialApplier.new()
	instance.debug_mode = debug
	instance.run()
