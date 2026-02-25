@tool
extends Node
# Автоматический сборщик библиотеки блоков (реестр блоков)

# 🔥 ИСПРАВЛЕНО: теперь всё сохраняется внутри проекта
var LIBRARY_PATH = "res://src/data/blocks/voxel_blocky_library.tres"
var BLOCKS_FOLDER = "res://src/data/blocks/definitions/"
var MODELS_FOLDER = "res://src/assets/blocks/"
const MESHER_PATH = "res://src/data/blocks/voxel_mesher_blocky.tres"

@export var auto_build: bool = true
@export var debug_mode: bool = true

var library: VoxelBlockyLibrary
var block_count: int = 0
var mesher_manager: Node

func _ready():
	if Engine.is_editor_hint():
		if auto_build:
			call_deferred("_build_library")
	else:
		if auto_build:
			await get_tree().create_timer(1.0).timeout
			call_deferred("_build_library")
	
	_init_mesher_manager()

func _init_mesher_manager():
	if ResourceLoader.exists("res://src/data/blocks/mesher_manager_path.gd"):
		var MesherManagerClass = load("res://src/data/blocks/mesher_manager_path.gd")
		if MesherManagerClass:
			mesher_manager = MesherManagerClass.new()
			add_child(mesher_manager)
			if debug_mode:
				print("✅ MesherManagerPath инициализирован")
	else:
		if debug_mode:
			print("⚠️ MesherManagerPath не найден")

func _build_library():
	if debug_mode:
		print("🏗️ АВТОСБОРЩИК БИБЛИОТЕКИ БЛОКОВ")
		
		if Engine.is_editor_hint():
			print("📌 Режим: РЕДАКТОР")
	
	if debug_mode:
		print("\n📁 ШАГ 1: Создание новой библиотеки")
		print("   📍 LIBRARY_PATH (проект): ", LIBRARY_PATH)
		print("   📍 BLOCKS_FOLDER (проект): ", BLOCKS_FOLDER)
		print("   📍 MODELS_FOLDER (проект): ", MODELS_FOLDER)
		print("   📍 MESHER_PATH (проект): ", MESHER_PATH)
	
	library = VoxelBlockyLibrary.new()
	
	if debug_mode:
		print("\n🔍 ШАГ 2: Поиск определений блоков")
	var block_files = _find_block_definitions()
	if debug_mode:
		print("📁 Найдено определений блоков: ", block_files.size())
	
	if debug_mode:
		print("\n🌬️ ШАГ 3: Добавление воздуха")
	_add_air()
	
	if debug_mode:
		print("\n🧱 ШАГ 4: Добавление блоков")
	for file_path in block_files:
		_process_block_definition(file_path)
	
	if debug_mode:
		print("\n🔥 ШАГ 5: Запекание библиотеки")
	library.bake()
	
	if debug_mode:
		print("\n💾 ШАГ 6: Сохранение")
	
	# Создаём папку внутри проекта, если нужно
	var target_dir = LIBRARY_PATH.get_base_dir()
	if not DirAccess.dir_exists_absolute(target_dir):
		var dir_result = DirAccess.make_dir_recursive_absolute(target_dir)
		if dir_result == OK and debug_mode:
			print("   📁 Создана папка: ", target_dir)
	
	var result = ResourceSaver.save(library, LIBRARY_PATH)
	if result == OK:
		if debug_mode:
			print("✅ Библиотека сохранена в: ", LIBRARY_PATH)
	else:
		print("❌ Ошибка сохранения: ", result)
		return
	
	# 🔥 ШАГ 7: Запускаем MaterialApplier для применения материалов
	if debug_mode:
		print("\n🎨 ШАГ 7: Применение материалов к библиотеке")
	_run_material_applier()
	
	if debug_mode:
		print("✅ СБОРКА ЗАВЕРШЕНА")
		print("📊 Всего блоков: ", block_count)

func _run_material_applier():
	if debug_mode:
		print("\n🎨 Запуск MaterialApplier для применения материалов")
	
	var applier_path = "res://src/scripts/tools/block_library/block_material_applier.gd"
	if ResourceLoader.exists(applier_path):
		if debug_mode:
			print("📁 Файл найден: ", applier_path)
		
		var resource = load(applier_path)
		if debug_mode:
			print("📦 Тип загруженного ресурса: ", typeof(resource))
			print("📦 Класс ресурса: ", resource.get_class())
			print("📦 Это GDScript? ", resource is GDScript)
		
		# 🔥 ИСПРАВЛЕНО: проверяем, что это действительно GDScript
		if resource is GDScript:
			# Вместо вызова статического метода, создаём экземпляр
			var instance = resource.new()
			if instance.has_method("run"):
				instance.debug_mode = debug_mode
				instance.run()
				if debug_mode:
					print("✅ BlockMaterialApplier.run() завершил работу")
			elif instance.has_method("apply"):
				instance.debug_mode = debug_mode
				instance.apply()
				if debug_mode:
					print("✅ BlockMaterialApplier.apply() завершил работу")
			else:
				if debug_mode:
					print("❌ Нет подходящих методов в экземпляре")
		else:
			if debug_mode:
				print("❌ Загруженный ресурс не является GDScript!")
	else:
		if debug_mode:
			print("⚠️ BlockMaterialApplier не найден по пути: ", applier_path)

func _find_block_definitions() -> Array:
	"""Находит все .tres файлы определений блоков в проекте"""
	var files = []
	var dir = DirAccess.open(BLOCKS_FOLDER)
	if not dir:
		if debug_mode:
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
	var air_model = VoxelBlockyModelEmpty.new()
	air_model.resource_name = "air"
	
	var id = library.add_model(air_model)
	if debug_mode:
		print("   ✅ Воздух добавлен с ID: ", id)
	block_count += 1

func _process_block_definition(file_path: String):
	if debug_mode:
		print("\n🔧 Обработка: ", file_path.get_file())
	
	if not FileAccess.file_exists(file_path):
		if debug_mode:
			print("   ❌ Файл не найден: ", file_path)
		return
	
	var def_resource = load(file_path)
	if not def_resource or not def_resource is BlockDefinition:
		if debug_mode:
			print("   ❌ Неверный формат определения: ", file_path)
		return
	
	var def: BlockDefinition = def_resource
	if debug_mode:
		print("   📦 Блок: ", def.block_name)
		# 🔥 ИСПРАВЛЕНО: используем material_type_enum вместо material_type
		print("   🎨 Материал: ", def.material_type_enum)
		print("   🔲 Коллизия: ", "включена" if def.collision_enabled else "отключена")
		print("   📏 AABB: ", def.collision_aabbs)
	
	# Получаем путь к модели
	var model_path = ""
	if def.model != null:
		if def.model.has_method("get_resource_path"):
			model_path = def.model.get_resource_path()
		elif def.model is ArrayMesh and def.model.resource_path != "":
			model_path = def.model.resource_path
	
	if model_path.is_empty():
		if debug_mode:
			print("   ⚠️ В определении не указана модель")
			print("      Блок будет пропущен")
		return
	
	if debug_mode:
		print("   🔍 Модель из определения: ", model_path)
	
	if not ResourceLoader.exists(model_path):
		if debug_mode:
			print("   ⚠️ Модель не найдена: ", model_path)
			print("      Блок будет пропущен")
		return
	
	var mesh_resource = load(model_path)
	if not mesh_resource:
		if debug_mode:
			print("   ⚠️ Не удалось загрузить модель")
		return
	
	var model = VoxelBlockyModelMesh.new()
	model.resource_name = def.block_name
	model.mesh = mesh_resource
	model.culls_neighbors = def.culls_neighbors
	model.transparency_index = def.transparency_index
	
	# Устанавливаем массив AABB
	model.collision_aabbs = def.collision_aabbs
	
	# Устанавливаем флаг коллизии для первого AABB (индекс 0)
	model.set("collision_enabled_0", def.collision_enabled)
	
	if debug_mode:
		print("   ✅ Mesh загружен: ", model_path)
		print("   ✅ Коллизия настроена")
	
	var id = library.add_model(model)
	if debug_mode:
		print("   ✅ Блок добавлен с ID: ", id)
	block_count += 1

static func build():
	var instance = Engine.get_main_loop().root.get_node_or_null("/root/BlockRegistry")
	if instance:
		instance._build_library()
	else:
		print("❌ BlockRegistry не найден")

static func get_library() -> VoxelBlockyLibrary:
	var instance = Engine.get_main_loop().root.get_node_or_null("/root/BlockRegistry")
	if instance:
		return instance.library
	return null

static func get_block_id(block_name: String) -> int:
	var instance = Engine.get_main_loop().root.get_node_or_null("/root/BlockRegistry")
	if instance and instance.library:
		return instance.library.get_model_index_from_resource_name(block_name)
	return -1
