@tool
extends Node
# Синхронизация с фильтрацией по расширениям файлов

@export var sync_enabled: bool = true
@export var source_in_game: String = "src/"  # Папка рядом с игрой
@export var target_in_res: String = "res://src/"  # Папка в проекте
@export var safety_check: bool = true
@export var min_files_threshold: int = 5

# 🔥 СПИСОК РАСШИРЕНИЙ ДЛЯ ИСКЛЮЧЕНИЯ (можно дополнять)
@export var excluded_extensions: Array[String] = [
	"gd",      # Скрипты Godot
	"tscn",    # Сцены Godot
	"escn",    # Сцены (instanced)
	"import",  # Файлы импорта
	"godot",
	"uid",   # Файлы проекта
]

# 🔥 СПИСОК ПАПОК ДЛЯ ОБРАБОТКИ (можно дополнять, пока пусто)
@export var included_folders: Array[String] = [
	# "assets/textures/",  # Раскомментируйте когда понадобится
	# "assets/models/",
	# "data/",
]

func _ready():
	if not sync_enabled:
		return
	
	print("🔄 СИНХРОНИЗАЦИЯ С ФИЛЬТРАЦИЕЙ РАСШИРЕНИЙ")
	
	var game_folder = _get_game_folder()
	var source_path = game_folder.path_join(source_in_game)
	var target_path = target_in_res
	
	print("📁 Папка игры: ", source_path)
	print("📁 Папка проекта: ", target_path)
	
	# Показываем текущие настройки
	print("\n🔍 Настройки фильтрации:")
	print("   🚫 Исключаемые расширения: ", ", ".join(excluded_extensions))
	if included_folders.is_empty():
		print("   📂 Обрабатываются все папки (фильтр пуст)")
	else:
		print("   📂 Обрабатываются папки: ", ", ".join(included_folders))
	
	# Запускаем синхронизацию
	var total_stats = _sync_with_filter(source_path, target_path, "")
	
	print("✅ СИНХРОНИЗАЦИЯ ЗАВЕРШЕНА")
	print("   📄 Скопировано/обновлено: ", total_stats.copied + total_stats.updated)
	print("   🆕 Новых: ", total_stats.copied)
	print("   🔄 Обновлено: ", total_stats.updated)
	print("   🚫 Пропущено (исключено): ", total_stats.skipped)
	print("   📁 Папок создано: ", total_stats.folders)
	if total_stats.errors > 0:
		print("   ❌ Ошибок: ", total_stats.errors)

func _get_game_folder() -> String:
	if Engine.is_editor_hint():
		return "user://"
	else:
		return OS.get_executable_path().get_base_dir().path_join("")

func _should_process_folder(folder_path: String) -> bool:
	"""Проверяет, нужно ли обрабатывать папку"""
	if included_folders.is_empty():
		return true  # Если список пуст - обрабатываем всё
	
	var relative_path = folder_path.trim_prefix(source_in_game).trim_prefix(target_in_res)
	
	for included in included_folders:
		if relative_path.begins_with(included):
			return true
	
	return false

func _is_excluded_file(filename: String) -> bool:
	"""Проверяет, нужно ли исключить файл по расширению"""
	var extension = filename.get_extension().to_lower()
	return extension in excluded_extensions

func _sync_with_filter(source: String, target: String, relative_path: String) -> Dictionary:
	"""Рекурсивная синхронизация с фильтрацией"""
	var stats = {
		"copied": 0,
		"updated": 0,
		"skipped": 0,
		"errors": 0,
		"folders": 0
	}
	
	# Проверяем, нужно ли обрабатывать эту папку
	if not _should_process_folder(relative_path):
		print("⏭️ Папка пропущена (не в списке): ", relative_path)
		return stats
	
	var dir = DirAccess.open(source)
	if not dir:
		return stats
	
	# Создаем целевую папку если её нет
	if not DirAccess.dir_exists_absolute(target):
		DirAccess.make_dir_absolute(target)
		stats.folders += 1
		print("📁 Создана папка: ", target)
	
	dir.list_dir_begin()
	var item = dir.get_next()
	
	while item != "":
		if item == "." or item == "..":
			item = dir.get_next()
			continue
		
		var source_item = source.path_join(item)
		var target_item = target.path_join(item)
		var new_relative = relative_path.path_join(item) if relative_path != "" else item
		
		if dir.current_is_dir():
			# Это папка - рекурсивно обрабатываем
			var sub_stats = _sync_with_filter(source_item, target_item, new_relative)
			stats.copied += sub_stats.copied
			stats.updated += sub_stats.updated
			stats.skipped += sub_stats.skipped
			stats.errors += sub_stats.errors
			stats.folders += sub_stats.folders
			
		else:
			# Это файл - проверяем расширение
			if _is_excluded_file(item):
				print("⏭️ Пропущен (исключен): ", new_relative)
				stats.skipped += 1
			else:
				# Копируем файл
				if FileAccess.file_exists(target_item):
					# Проверяем, изменился ли файл
					var source_time = FileAccess.get_modified_time(source_item)
					var target_time = FileAccess.get_modified_time(target_item)
					
					if source_time > target_time:
						if _copy_file(source_item, target_item):
							print("🔄 Обновлен: ", new_relative)
							stats.updated += 1
						else:
							print("❌ Ошибка: ", new_relative)
							stats.errors += 1
				else:
					# Новый файл
					if _copy_file(source_item, target_item):
						print("✅ Добавлен: ", new_relative)
						stats.copied += 1
					else:
						print("❌ Ошибка: ", new_relative)
						stats.errors += 1
		
		item = dir.get_next()
	
	dir.list_dir_end()
	return stats

func _copy_file(source: String, target: String) -> bool:
	var src_file = FileAccess.open(source, FileAccess.READ)
	if not src_file:
		return false
	
	var target_dir = target.get_base_dir()
	if not DirAccess.dir_exists_absolute(target_dir):
		DirAccess.make_dir_recursive_absolute(target_dir)
	
	var data = src_file.get_buffer(src_file.get_length())
	var dst_file = FileAccess.open(target, FileAccess.WRITE)
	if not dst_file:
		return false
	
	dst_file.store_buffer(data)
	return true
