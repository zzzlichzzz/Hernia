@tool
extends EditorScript
# Сборщик библиотеки блоков из отдельных .tres файлов с использованием add_model()

const LIBRARY_PATH = "res://src/data/blocks/voxel_blocky_library.tres"
const BLOCKS_FOLDER = "res://src/data/blocks/definitions/"

var library: VoxelBlockyLibrary
var id_manager: IDManager
var block_count: int = 0

func _run():
	print("🏗️ СБОРЩИК БИБЛИОТЕКИ БЛОКОВ (ЧЕРЕЗ ADD_MODEL)")
	
	# ШАГ 1: Создаем новую библиотеку
	print("\n📁 ШАГ 1: Создание новой библиотеки")
	library = VoxelBlockyLibrary.new()
	
	# ШАГ 2: Создаем ID менеджер (без загрузки существующих)
	id_manager = IDManager.new()
	
	# ШАГ 3: Находим все определения блоков
	print("\n🔍 ШАГ 2: Поиск определений блоков")
	var block_files = _find_block_definitions()
	print("📁 Найдено определений блоков: ", block_files.size())
	
	# ШАГ 4: Добавляем воздух (индекс 0)
	print("\n🌬️ ШАГ 3: Добавление воздуха")
	_add_air()
	
	# ШАГ 5: Обрабатываем каждый блок
	print("\n🧱 ШАГ 4: Добавление блоков")
	for file_path in block_files:
		_process_block_definition(file_path)
	
	# ШАГ 6: Запекаем библиотеку
	print("\n🔥 ШАГ 5: Запекание библиотеки")
	library.bake()
	
	# ШАГ 7: Сохраняем
	print("\n💾 ШАГ 6: Сохранение")
	var result = ResourceSaver.save(library, LIBRARY_PATH)
	if result == OK:
		print("✅ Библиотека сохранена в: ", LIBRARY_PATH)
	else:
		print("❌ Ошибка сохранения: ", result)
		return
	
	# ШАГ 8: Обновляем FileSystem
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()
	
	print("✅ СБОРКА ЗАВЕРШЕНА")
	print("📊 Всего блоков: ", block_count)

func _find_block_definitions() -> Array:
	"""Находит все .tres файлы с определениями блоков"""
	var files = []
	var dir = DirAccess.open(BLOCKS_FOLDER)
	if not dir:
		print("⚠️ Папка не найдена: ", BLOCKS_FOLDER)
		return files
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres") and file_name != "block_definition.gd":
			files.append(BLOCKS_FOLDER + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	
	return files

func _add_air():
	"""Добавляет воздух через add_model()"""
	var air_model = VoxelBlockyModelEmpty.new()
	air_model.resource_name = "air"
	
	var id = library.add_model(air_model)
	print("   ✅ Воздух добавлен с ID: ", id)
	block_count += 1

func _process_block_definition(file_path: String):
	"""Обрабатывает один файл определения блока"""
	print("\n🔧 Обработка: ", file_path)
	
	# Загружаем определение
	var def_resource = load(file_path)
	if not def_resource or not def_resource is BlockDefinition:
		print("❌ Неверный формат определения")
		return
	
	var def: BlockDefinition = def_resource
	print("📦 Блок: ", def.block_name)
	print("   Материал: ", def.material_type)
	
	var variant_names = def.model_paths.keys()
	print("   Моделей: ", variant_names)
	
	for variant_name in variant_names:
		var model_path = def.model_paths[variant_name]
		var full_variant_name = def.block_name
		if variant_name != "default":
			full_variant_name += "_" + variant_name
		
		# 🔥 СОЗДАЕМ МОДЕЛЬ ЧЕРЕЗ add_model()
		var model = VoxelBlockyModelMesh.new()
		model.resource_name = full_variant_name
		
		# Загружаем mesh
		if ResourceLoader.exists(model_path):
			model.mesh = load(model_path)
			print("   ✅ Mesh загружен: ", model_path)
		else:
			print("   ⚠️ Mesh не найден: ", model_path)
			# Создаем заглушку
			var box = BoxMesh.new()
			box.size = Vector3(1, 1, 1)
			model.mesh = box
		
		# Получаем материал
		var material = _get_material(def.material_type)
		if material and model.mesh and model.mesh.get_surface_count() > 0:
			for surface_idx in range(model.mesh.get_surface_count()):
				model.mesh.surface_set_material(surface_idx, material)
			print("   ✅ Материал применен: ", def.material_type)
		
		# Добавляем в библиотеку
		var id = library.add_model(model)
		print("   ✅ Вариант '", full_variant_name, "' добавлен с ID: ", id)
		block_count += 1

func _get_material(type: String) -> StandardMaterial3D:
	"""Возвращает материал нужного типа"""
	var path = ""
	match type:
		"opaque":
			path = "res://src/assets/textures/atlas/block_material_opaque.tres"
		"transparent":
			path = "res://src/assets/textures/atlas/block_material_transparent.tres"
		"foliage":
			path = "res://src/assets/textures/atlas/block_material_foliage.tres"
		_:
			path = "res://src/assets/textures/atlas/block_material_opaque.tres"
	
	if ResourceLoader.exists(path):
		return load(path)
	else:
		print("   ⚠️ Материал не найден: ", path)
		return null
