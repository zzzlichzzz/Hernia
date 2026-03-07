@tool
extends Node
class_name BlockMaterialApplier

var BLOCKS_FOLDER = "res://src/data/blocks/definitions/"
var LIBRARY_PATH = "res://src/data/blocks/voxel_blocky_library.tres"

var debug_mode: bool = true

# Используем AtlasMaterialGenerator
var _atlas_material_generator: AtlasMaterialGenerator = null

func run():
	if debug_mode:
		print("🎨 BLOCK MATERIAL APPLIER: Применение материалов с текстурами из атласа")
		print("📁 LIBRARY_PATH: ", LIBRARY_PATH)
	
	_init_atlas_material_generator()
	if not _atlas_material_generator:
		if debug_mode:
			print("❌ Не удалось инициализировать AtlasMaterialGenerator")
		return
	
	var library = load(LIBRARY_PATH)
	if not library:
		if debug_mode:
			print("❌ Не удалось загрузить библиотеку: ", LIBRARY_PATH)
		return
	
	var model_count = library.models.size() if "models" in library else 0
	var definitions = _load_definitions()
	
	# Загружаем координаты атласа один раз
	var atlas_coords = _load_atlas_coords()
	if not atlas_coords:
		if debug_mode:
			print("❌ Не удалось загрузить координаты атласа")
		return
	
	var applied_count = 0
	var materials_cache = {}
	
	for i in range(model_count):
		var model = library.models[i] if "models" in library else null
		if not model or model.resource_name == "air":
			continue
		
		var block_name = model.resource_name
		if debug_mode:
			print("\n🔧 Обработка: ", block_name)
		
		if block_name in definitions:
			var def = definitions[block_name]
			var material_type = _get_material_type_from_def(def)
			
			# Получаем имя текстуры
			var texture_name = def.texture_name
			if texture_name.is_empty():
				texture_name = block_name
			
			# 🔥 ИСПРАВЛЕНО: используем ShaderMaterial
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
			if texture_name in atlas_coords.coordinates:
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
				
				# Применяем к модели
				if model is VoxelBlockyModelMesh:
					var surface_count = model.mesh.get_surface_count() if model.mesh else 1
					for surface_idx in range(surface_count):
						model.set_material_override(surface_idx, block_material)
					
					if debug_mode:
						print("   ✅ Материал с UV применен к модели")
					applied_count += 1
			else:
				if debug_mode:
					print("   ⚠️ Текстура '", texture_name, "' не найдена в атласе, применяю материал без UV")
				
				# Применяем обычный материал без UV
				if model is VoxelBlockyModelMesh:
					var surface_count = model.mesh.get_surface_count() if model.mesh else 1
					for surface_idx in range(surface_count):
						model.set_material_override(surface_idx, material)
					
					if debug_mode:
						print("   ✅ Обычный материал применен к модели")
					applied_count += 1
	
	if applied_count > 0:
		var result = ResourceSaver.save(library, LIBRARY_PATH)
		if result == OK and debug_mode:
			print("\n✅ Библиотека сохранена (", applied_count, " моделей)")
	else:
		if debug_mode:
			print("\n⚠️ Нет примененных материалов")

# Загрузка координат атласа
func _load_atlas_coords() -> Resource:
	var coords_path = "res://src/assets/textures/atlas/block/block_coordinates.tres"
	if FileAccess.file_exists(coords_path):
		if debug_mode:
			print("📁 Загрузка координат из: ", coords_path)
		return load(coords_path)
	else:
		if debug_mode:
			print("⚠️ Координаты не найдены: ", coords_path)
	return null

func _init_atlas_material_generator():
	var generator_path = "res://src/scripts/tools/atlas_work/atlas_material_generator.gd"
	if ResourceLoader.exists(generator_path):
		var generator_script = load(generator_path)
		if generator_script:
			_atlas_material_generator = generator_script.new()

# 🔥 ИСПРАВЛЕНО: возвращаем ShaderMaterial
func _load_material(material_type: String) -> ShaderMaterial:
	match material_type:
		"opaque":
			return AtlasMaterialGenerator.get_opaque()
		"transparent":
			return AtlasMaterialGenerator.get_transparent()
		"foliage":
			return AtlasMaterialGenerator.get_foliage()
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
	if "material_type" in def and def.get("material_type") != null:
		return def.material_type
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
