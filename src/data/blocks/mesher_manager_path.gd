@tool
extends VoxelTerrain
# Скрипт для автоматической установки правильного пути к мешеру

@export var auto_update: bool = true
@export var debug_mode: bool = true

func _enter_tree():
	if Engine.is_editor_hint() and auto_update:
		call_deferred("_delayed_update")

func _ready():
	if Engine.is_editor_hint() and auto_update:
		call_deferred("_delayed_update")

func _delayed_update():
	# Небольшая задержка для гарантии загрузки всех автозагрузок
	await get_tree().create_timer(0.1).timeout
	_update_mesher()

func _update_mesher():
	if not is_inside_tree():
		call_deferred("_update_mesher")
		return

	if debug_mode:
		print("\n🔧 VoxelTerrainMod: Установка мешера")
	
	# 🔥 ПУТЬ К БИБЛИОТЕКЕ ЧЕРЕЗ OS (рядом с exe)
	var library_path = _get_game_path() + "/src/data/blocks/voxel_blocky_library.tres"
	
	# 🔥 ПУТЬ К МЕШЕРУ ОБЫЧНЫЙ
	var mesher_path = "res://src/data/blocks/voxel_mesher_blocky.tres"
	
	if debug_mode:
		print("📁 Путь к библиотеке (через OS): ", library_path)
		print("📁 Путь к мешеру: ", mesher_path)
	
	# Загружаем библиотеку
	var library = _load_library(library_path)
	if not library:
		# Если не нашли, пробуем загрузить из res:// как запасной вариант
		if debug_mode:
			print("⚠️ Пробую загрузить из res://...")
		library = _load_library("res://src/data/blocks/voxel_blocky_library.tres")
		if not library:
			return
	
	# Загружаем или создаем мешер
	var mesher = _load_or_create_mesher(mesher_path)
	
	# Устанавливаем библиотеку в мешер
	mesher.library = library
	if debug_mode:
		print("✅ Библиотека установлена в мешер")
	
	# Устанавливаем мешер в террейн
	self.mesher = mesher
	if debug_mode:
		print("✅ Мешер установлен в террейн")
	
	# Сохраняем мешер (опционально)
	var save_result = ResourceSaver.save(mesher, mesher_path)
	if save_result == OK:
		if debug_mode:
			print("✅ Мешер сохранен")
	else:
		if debug_mode:
			print("⚠️ Ошибка сохранения мешера: ", save_result)

# 🔥 ФУНКЦИЯ ДЛЯ ПОЛУЧЕНИЯ ПУТИ К ПАПКЕ ИГРЫ
func _get_game_path() -> String:
		# В экспортированной игре - папка с exe
		return OS.get_executable_path().get_base_dir().path_join("")

func _load_library(path: String) -> VoxelBlockyLibrary:
	if not ResourceLoader.exists(path):
		if debug_mode:
			print("❌ Библиотека не найдена: ", path)
		return null
	
	var lib = load(path)
	if not lib or not lib is VoxelBlockyLibrary:
		if debug_mode:
			print("❌ Не удалось загрузить библиотеку или неверный тип")
		return null
	
	if debug_mode:
		print("✅ Библиотека загружена: ", lib.resource_path)
	return lib

func _load_or_create_mesher(path: String) -> VoxelMesherBlocky:
	if ResourceLoader.exists(path):
		var res = load(path)
		if res and res is VoxelMesherBlocky:
			if debug_mode:
				print("✅ Мешер загружен из файла")
			return res
	
	if debug_mode:
		print("🆕 Создан новый мешер")
	return VoxelMesherBlocky.new()
