extends Node

@export var auto_start: bool = true
@export var debug_mode: bool = true

const ATLAS_MANAGER_PATH = "res://src/scripts/build/atlas/atlas_manager.gd"
const ATLAS_ICON_MANAGER_PATH = "res://src/scripts/build/atlas/atlas_icon_manager.gd"
const ITEMS_REGISTRY_PATH = "res://src/data/items/items_registry.gd"
const BLOCK_3D_ICON_GENERATOR_PATH = "res://src/scripts/build/icon/block_3d_icon_generator.gd"

# ─── Логирование ───

func _log(message: String):
	if debug_mode:
		print(message)

func _log_error(message: String):
	# Ошибки выводим всегда
	printerr(message)

# ─── Точка входа ───

func _ready():
	if auto_start:
		start()

func start():
	_log("🚀 АВТОГЕНЕРАТОР: Запуск последовательной сборки ресурсов")
	if debug_mode:
		_log("🔧 Debug mode: ВКЛ (все проверки активны)")
	
	var start_time = Time.get_ticks_msec()
	
	# ШАГ 1
	if not _run_atlas_manager():
		_log_error("❌ АВТОГЕНЕРАТОР: Остановлено из-за ошибки в AtlasManager")
		return
	
	await get_tree().create_timer(0.3).timeout
	
	# ШАГ 2
	if not _run_items_registry():
		_log_error("❌ АВТОГЕНЕРАТОР: Остановлено из-за ошибки в BlockRegistry")
		return
	
	await get_tree().create_timer(0.3).timeout
	
	# ШАГ 3
	if not await _run_block_3d_icon_generator():
		_log("⚠️ АВТОГЕНЕРАТОР: Ошибка генерации 3D иконок (не критично)")
	
	# ШАГ 4
	if not _run_atlas_icon_manager():
		_log_error("❌ АВТОГЕНЕРАТОР: Остановлено из-за ошибки в AtlasManagerIcon")
		return
	
	var elapsed = (Time.get_ticks_msec() - start_time) / 1000.0
	_log("✅ АВТОГЕНЕРАТОР: Все ресурсы обновлены за %.2f секунд" % elapsed)

# ─── Atlas Manager ───

func _run_atlas_manager() -> bool:
	_log("\n📦 ШАГ 1: Запуск AtlasManager...")
	
	if debug_mode:
		if not ResourceLoader.exists(ATLAS_MANAGER_PATH):
			_log_error("❌ AtlasManager не найден: " + ATLAS_MANAGER_PATH)
			return false
	
	var atlas_script = load(ATLAS_MANAGER_PATH)
	
	if debug_mode:
		if not atlas_script:
			_log_error("❌ Не удалось загрузить AtlasManager")
			return false
	
	var atlas_manager = atlas_script.new()
	
	if debug_mode:
		if not atlas_manager.has_method("build_atlas"):
			_log_error("❌ AtlasManager: метод build_atlas() не найден")
			return false
	
	var result = atlas_manager.build_atlas()
	
	if debug_mode and not result:
		_log_error("❌ AtlasManager вернул ошибку")
		return false
	
	_log("✅ AtlasManager успешно выполнен")
	return true

# ─── Atlas Icon Manager ───

func _run_atlas_icon_manager() -> bool:
	_log("\n📦 ШАГ 4: Запуск AtlasIconManager...")
	
	if debug_mode:
		if not ResourceLoader.exists(ATLAS_ICON_MANAGER_PATH):
			_log_error("❌ AtlasIconManager не найден: " + ATLAS_ICON_MANAGER_PATH)
			return false
	
	var atlas_script = load(ATLAS_ICON_MANAGER_PATH)
	
	if debug_mode:
		if not atlas_script:
			_log_error("❌ Не удалось загрузить AtlasIconManager")
			return false
	
	var atlas_manager = atlas_script.new()
	
	if debug_mode:
		if not atlas_manager.has_method("build_atlas"):
			_log_error("❌ AtlasIconManager: метод build_atlas() не найден")
			return false
	
	var result = atlas_manager.build_atlas()
	
	if debug_mode and not result:
		_log_error("❌ AtlasIconManager вернул ошибку")
		return false
	
	_log("✅ AtlasIconManager успешно выполнен")
	return true

# ─── Items Registry ───

func _run_items_registry() -> bool:
	_log("\n📦 ШАГ 2: Запуск ItemRegistry...")
	
	var registry_script = load(ITEMS_REGISTRY_PATH)
	var registry = registry_script.new()
	
	if debug_mode:
		if not registry.has_method("_build_library"):
			_log_error("❌ BlockRegistry: метод _build_library не найден")
			return false
	
	registry._build_library()
	_log("✅ BlockRegistry._build_library() выполнен")
	return true

# ─── 3D Icon Generator ───

func _run_block_3d_icon_generator() -> bool:
	_log("\n📦 ШАГ 3: Генерация 3D иконок блоков...")
	
	if debug_mode:
		if not ResourceLoader.exists(BLOCK_3D_ICON_GENERATOR_PATH):
			_log_error("❌ Block3DIconGenerator не найден: " + BLOCK_3D_ICON_GENERATOR_PATH)
			return false
	
	var icon_script = load(BLOCK_3D_ICON_GENERATOR_PATH)
	
	if debug_mode:
		if not icon_script:
			_log_error("❌ Не удалось загрузить Block3DIconGenerator")
			return false
	
	var generator = icon_script.new()
	add_child(generator)
	
	await get_tree().process_frame
	
	var icons = await generator.generate_all_3d_icons()
	
	if debug_mode and icons.size() == 0:
		_log("⚠️ Block3DIconGenerator: иконки не созданы")
		generator.queue_free()
		return false
	
	_log("✅ Block3DIconGenerator: создано %d 3D иконок" % icons.size())
	generator.queue_free()
	return true
