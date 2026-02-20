@tool
extends Node
# Автоматический сборщик библиотеки блоков (реестр блоков)

# 🔥 ПОДКЛЮЧАЕМ МЕНЕДЖЕР МЕШЕРА
var MesherManagerPath = preload("res://src/data/blocks/mesher_manager_path.gd")

var LIBRARY_PATH = PathManager.smart("res://src/data/blocks/voxel_blocky_library.tres")
var BLOCKS_FOLDER = PathManager.smart("res://src/data/blocks/definitions/")
var MODELS_FOLDER = PathManager.smart("res://src/assets/blocks/")

@export var auto_build: bool = true
@export var debug_mode: bool = true
@export var run_creator_before_build: bool = true

var library: VoxelBlockyLibrary
var block_count: int = 0
var mesher_manager: Node  # 🔥 Ссылка на менеджер мешера

func _ready():
	if auto_build:
		call_deferred("_build_library")
	
	# 🔥 Инициализируем менеджер мешера
	_init_mesher_manager()

func _init_mesher_manager():
	"""Инициализирует менеджер мешера"""
	mesher_manager = MesherManagerPath.new()
	add_child(mesher_manager)
	if debug_mode:
		print("✅ MesherManagerPath инициализирован")

func _build_library():
	if debug_mode:
		print("🏗️ АВТОСБОРЩИК БИБЛИОТЕКИ БЛОКОВ")
	
	# ШАГ 0: Запускаем block_creator для обновления моделей
	if run_creator_before_build:
		_run_block_creator()
	
	# ШАГ 1: Создаем новую библиотеку
	if debug_mode:
		print("\n📁 ШАГ 1: Создание новой библиотеки")
		print("   📍 LIBRARY_PATH: ", LIBRARY_PATH)
		print("   📍 BLOCKS_FOLDER: ", BLOCKS_FOLDER)
		print("   📍 MODELS_FOLDER: ", MODELS_FOLDER)
	
	library = VoxelBlockyLibrary.new()
	
	# ШАГ 2: Находим все определения блоков
	if debug_mode:
		print("\n🔍 ШАГ 2: Поиск определений блоков")
	var block_files = _find_block_definitions()
	if debug_mode:
		print("📁 Найдено определений блоков: ", block_files.size())
	
	# ШАГ 3: Добавляем воздух
	if debug_mode:
		print("\n🌬️ ШАГ 3: Добавление воздуха")
	_add_air()
	
	# ШАГ 4: Обрабатываем каждый блок
	if debug_mode:
		print("\n🧱 ШАГ 4: Добавление блоков")
	for file_path in block_files:
		_process_block_definition(file_path)
	
	# ШАГ 5: Запускаем material_applier для применения материалов к библиотеке
	if debug_mode:
		print("\n🎨 ШАГ 5: Применение материалов к библиотеке")
	_run_material_applier()
	
	# ШАГ 6: Запекаем библиотеку
	if debug_mode:
		print("\n🔥 ШАГ 6: Запекание библиотеки")
	library.bake()
	
	# ШАГ 7: Сохраняем
	if debug_mode:
		print("\n💾 ШАГ 7: Сохранение")
	var result = ResourceSaver.save(library, LIBRARY_PATH)
	if result == OK:
		if debug_mode:
			print("✅ Библиотека сохранена в: ", LIBRARY_PATH)
	else:
		print("❌ Ошибка сохранения: ", result)
		return
	
	# ШАГ 8: Обновляем FileSystem
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()
	
	# ШАГ 9: 🔥 Обновляем мешер через менеджер
	if debug_mode:
		print("\n🔄 ШАГ 9: Обновление мешера")
	_update_mesher()
	
	if debug_mode:
		print("✅ СБОРКА ЗАВЕРШЕНА")
		print("📊 Всего блоков: ", block_count)

# 🔥 ФУНКЦИЯ ОБНОВЛЕНИЯ МЕШЕРА
func _update_mesher():
	"""Обновляет мешер через менеджер"""
	if mesher_manager and mesher_manager.has_method("_update_mesher"):
		mesher_manager._update_mesher()
		if debug_mode:
			print("✅ Мешер обновлен через менеджер")
	else:
		if debug_mode:
			print("⚠️ Не удалось обновить мешер")

func _run_block_creator():
	if debug_mode:
		print("\n🔄 ШАГ 0: Запуск BlockCreator для подготовки моделей")
	
	var creator_path = "res://src/data/blocks/block_creator.gd"
	
	if not ResourceLoader.exists(creator_path):
		if debug_mode:
			print("⚠️ BlockCreator не найден по пути: ", creator_path)
		return
	
	var creator_script = load(creator_path)
	if not creator_script:
		if debug_mode:
			print("⚠️ Не удалось загрузить BlockCreator")
		return
	
	var creator = creator_script.new()
	creator.debug_mode = debug_mode
	creator.run()

func _run_material_applier():
	if debug_mode:
		print("\n🎨 Запуск MaterialApplier для применения материалов")
	
	var applier_path = "res://src/data/blocks/block_material_applier.gd"
	
	if not ResourceLoader.exists(applier_path):
		if debug_mode:
			print("⚠️ MaterialApplier не найден по пути: ", applier_path)
		return
	
	var applier_script = load(applier_path)
	if not applier_script:
		if debug_mode:
			print("⚠️ Не удалось загрузить MaterialApplier")
		return
	
	var applier = applier_script.new()
	applier.debug_mode = debug_mode
	applier.run()

func _find_block_definitions() -> Array:
	"""Находит все .tres файлы определений блоков"""
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
	"""Добавляет воздух через add_model()"""
	var air_model = VoxelBlockyModelEmpty.new()
	air_model.resource_name = "air"
	
	var id = library.add_model(air_model)
	if debug_mode:
		print("   ✅ Воздух добавлен с ID: ", id)
	block_count += 1

func _process_block_definition(file_path: String):
	"""Обрабатывает один файл определения блока"""
	if debug_mode:
		print("\n🔧 Обработка: ", file_path.get_file())
	
	# Загружаем определение
	var def_resource = load(file_path)
	if not def_resource or not def_resource is BlockDefinition:
		if debug_mode:
			print("   ❌ Неверный формат определения")
		return
	
	var def: BlockDefinition = def_resource
	if debug_mode:
		print("   📦 Блок: ", def.block_name)
		print("   🎨 Материал: ", def.material_type)
	
	# Формируем путь к модели по имени блока
	var model_path = MODELS_FOLDER + def.block_name + ".obj"
	if debug_mode:
		print("   🔍 Поиск модели: ", model_path)
	
	# Проверяем существование модели
	if not ResourceLoader.exists(model_path):
		if debug_mode:
			print("   ⚠️ Модель не найдена: ", model_path)
			print("      Блок будет пропущен")
		return
	
	# Загружаем модель из папки blocks
	var mesh_resource = load(model_path)
	if not mesh_resource:
		if debug_mode:
			print("   ⚠️ Не удалось загрузить модель")
		return
	
	# Создаем модель через add_model()
	var model = VoxelBlockyModelMesh.new()
	model.resource_name = def.block_name
	
	# Загружаем mesh
	model.mesh = mesh_resource
	if debug_mode:
		print("   ✅ Mesh загружен: ", model_path)
	
	# Добавляем в библиотеку (материал будет применен позже через material_applier)
	var id = library.add_model(model)
	if debug_mode:
		print("   ✅ Блок добавлен с ID: ", id)
	block_count += 1

# Статический метод для ручного запуска
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
