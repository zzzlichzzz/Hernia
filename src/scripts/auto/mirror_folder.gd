@tool
extends Node
# Зеркальное копирование с фильтрацией расширений
# ПЕРЕД КОПИРОВАНИЕМ УДАЛЯЕТ ЦЕЛЕВУЮ ПАПКУ

@export var auto_copy: bool = true
@export var source_base: String = "res://src/"
@export var target_base: String = ""  # Будет установлено автоматически

# 🔥 СПИСОК РАСШИРЕНИЙ ДЛЯ ИСКЛЮЧЕНИЯ (можно дополнять)
@export var excluded_extensions: Array[String] = [
	"gd",      # Скрипты Godot
	"tscn",    # Сцены Godot
	"escn",    # Сцены (instanced)
	"import",  # Файлы импорта
	"godot",   # Файлы проекта
	"uid",
]

# 🔥 СПИСОК ПАПОК ДЛЯ ОБРАБОТКИ (можно дополнять, пока пусто)
@export var included_folders: Array[String] = [
	# "assets/textures/",  # Раскомментируйте когда понадобится
	# "assets/models/",
	# "data/",
]

func _ready():
	if auto_copy:
		call_deferred("_start_mirror")

func _start_mirror():
	print("🪞 ЗЕРКАЛЬНОЕ КОПИРОВАНИЕ С ФИЛЬТРАЦИЕЙ")
	
	var target = _get_target_path()
	
	print("📁 Исходная папка: ", source_base)
	print("📁 Целевая папка: ", target)
	
	# Показываем текущие настройки
	print("\n🔍 Настройки фильтрации:")
	print("   🚫 Исключаемые расширения: ", ", ".join(excluded_extensions))
	if included_folders.is_empty():
		print("   📂 Копируются все папки (фильтр пуст)")
	else:
		print("   📂 Копируются папки: ", ", ".join(included_folders))
	
	if not DirAccess.dir_exists_absolute(source_base):
		print("❌ Исходная папка не существует")
		return
	
	# 🔥 ШАГ 1: УДАЛЕНИЕ СТАРОЙ ПАПКИ
	print("\n🗑️ ШАГ 1: Удаление старой целевой папки")
	if DirAccess.dir_exists_absolute(target):
		var delete_result = _delete_folder(target)
		print("   ✅ Папка удалена (", delete_result, " элементов)")
	else:
		print("   📁 Целевая папка не существует, удаление не требуется")
	
	# 🔥 ШАГ 2: СОЗДАНИЕ НОВОЙ ПАПКИ
	print("\n📁 ШАГ 2: Создание новой целевой папки")
	var create_result = DirAccess.make_dir_recursive_absolute(target)
	if create_result == OK:
		print("   ✅ Папка создана")
	else:
		print("   ❌ Ошибка создания папки")
		return
	
	# 🔥 ШАГ 3: КОПИРОВАНИЕ
	print("\n📋 ШАГ 3: Копирование файлов")
	var total_stats = _mirror_with_filter(source_base, target, "")
	
	print("📊 ИТОГОВЫЙ РЕЗУЛЬТАТ:")
	print("   📄 Скопировано: ", total_stats.copied)
	print("   🚫 Пропущено (исключено): ", total_stats.skipped)
	print("   📁 Папок создано: ", total_stats.folders)
	if total_stats.errors > 0:
		print("   ❌ Ошибок: ", total_stats.errors)

func _get_target_path() -> String:
	if Engine.is_editor_hint():
		return "user://src/"
	else:
		return OS.get_executable_path().get_base_dir().path_join("src").path_join("")

func _delete_folder(path: String) -> int:
	"""Рекурсивно удаляет папку и возвращает количество удаленных элементов"""
	var deleted_count = 0
	var dir = DirAccess.open(path)
	if not dir:
		return deleted_count
	
	dir.list_dir_begin()
	var item = dir.get_next()
	
	while item != "":
		if item == "." or item == "..":
			item = dir.get_next()
			continue
		
		var full_path = path.path_join(item)
		
		if dir.current_is_dir():
			# Рекурсивно удаляем вложенную папку
			deleted_count += _delete_folder(full_path)
			# Удаляем саму папку
			DirAccess.remove_absolute(full_path)
			deleted_count += 1
			print("   🗑️ Удалена папка: ", item)
		else:
			# Удаляем файл
			DirAccess.remove_absolute(full_path)
			deleted_count += 1
			print("   🗑️ Удален файл: ", item)
		
		item = dir.get_next()
	
	dir.list_dir_end()
	return deleted_count

func _should_process_folder(folder_path: String) -> bool:
	"""Проверяет, нужно ли обрабатывать папку"""
	if included_folders.is_empty():
		return true  # Если список пуст - обрабатываем всё
	
	var relative_path = folder_path.trim_prefix(source_base)
	
	for included in included_folders:
		if relative_path.begins_with(included):
			return true
	
	return false

func _is_excluded_file(filename: String) -> bool:
	"""Проверяет, нужно ли исключить файл по расширению"""
	var extension = filename.get_extension().to_lower()
	return extension in excluded_extensions

func _mirror_with_filter(source: String, target: String, relative_path: String) -> Dictionary:
	"""Рекурсивное копирование с фильтрацией"""
	var stats = {
		"copied": 0,
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
			# Это папка - создаем и рекурсивно обрабатываем
			if not DirAccess.dir_exists_absolute(target_item):
				DirAccess.make_dir_absolute(target_item)
				stats.folders += 1
				print("📁 Создана папка: ", target_item)
			
			var sub_stats = _mirror_with_filter(source_item, target_item, new_relative)
			stats.copied += sub_stats.copied
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
				if _copy_file(source_item, target_item):
					print("✅ Скопирован: ", new_relative)
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
