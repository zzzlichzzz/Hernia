@tool
extends Node

signal atlas_build_started
signal atlas_build_completed(success: bool)
signal atlas_build_failed(error: String)

var is_building: bool = false
var last_build_time: Dictionary = {}

func _enter_tree():
	print("🚀 AtlasManager: Запуск сборки атласа...")
	call_deferred("_auto_build")

func _auto_build():
	await get_tree().process_frame
	build_atlas()

func build_atlas() -> bool:
	if is_building:
		return false
	
	is_building = true
	atlas_build_started.emit()
	print("\n=== СБОРКА АТЛАСА ===")
	
	# ШАГ 1: Сборка атласа из PNG
	print("\n📸 ШАГ 1/3: Сборка атласа...")
	var builder = load(PathManager.smart("res://src/scripts/tools/atlas_work/texture_atlas_builder.gd")).new()
	builder._run()
	
	# ШАГ 2: Создание материалов из атласа
	print("\n🎨 ШАГ 2/3: Создание материалов...")
	var material_creator = load(PathManager.smart("res://src/scripts/tools/atlas_work/atlas_material.gd")).new()
	material_creator.create_all_materials()
	
	last_build_time = Time.get_datetime_dict_from_system()
	is_building = false
	
	print("\n=== СБОРКА ЗАВЕРШЕНА ===\n")
	atlas_build_completed.emit(true)
	return true

func get_atlas_coords_path() -> String:
	"""Возвращает путь к файлу координат атласа"""
	return PathManager.smart("res://src/assets/textures/atlas/block_coordinates.tres")

func get_atlas_png_path() -> String:
	"""Возвращает путь к PNG атласа"""
	return PathManager.smart("res://src/assets/textures/atlas/block_atlas.png")

func get_material_path() -> String:
	"""Возвращает путь к материалу"""
	return PathManager.smart("res://src/assets/textures/atlas/block_material.tres")

func is_atlas_valid() -> bool:
	"""Проверяет существование файлов атласа"""
	return ResourceLoader.exists(get_atlas_coords_path()) \
		and FileAccess.file_exists(get_atlas_png_path())

func is_material_valid() -> bool:
	"""Проверяет существование материала"""
	return ResourceLoader.exists(get_material_path())

func get_last_build_time() -> String:
	if last_build_time.is_empty():
		return "Никогда"
	return "%04d-%02d-%02d %02d:%02d:%02d" % [
		last_build_time.year, last_build_time.month, last_build_time.day,
		last_build_time.hour, last_build_time.minute, last_build_time.second
	]

# Статический метод для быстрого вызова
static func build():
	var instance = Engine.get_main_loop().root.get_node_or_null("/root/AtlasManager")
	if instance:
		instance.build_atlas()
	else:
		print("❌ AtlasManager не найден")

# Статический метод для получения материала
static func get_material():
	var instance = Engine.get_main_loop().root.get_node_or_null("/root/AtlasManager")
	if instance and instance.is_material_valid():
		return load(instance.get_material_path())
	return null
