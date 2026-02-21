@tool
extends Node
# Зеркало - копирует папку src из проекта в папку РЯДОМ С EXE

@export var enabled: bool = true
@export var source_folder: String = "res://src/"
@export var target_folder_name: String = "src"  # Имя папки рядом с exe

# 🔥 Какие расширения копировать
@export var allowed_extensions: Array[String] = [
	"png", "jpg", "jpeg", "tres", "obj", "gltf", "ogg", "mp3"
]

func _ready():
	if enabled:
		call_deferred("_run_mirror")

func _run_mirror():
	print("🪞 ЗЕРКАЛО: Копирование в папку РЯДОМ С EXE")
	
	# 🔥 ПОЛУЧАЕМ ПУТЬ К ПАПКЕ РЯДОМ С EXE
	var target_path = _get_exe_folder_path()
	
	print("📁 Исходная папка: ", source_folder)
	print("📁 Целевая папка: ", target_path)
	print("📁 Реальный путь: ", target_path)  # Уже реальный путь
	
	# Проверяем исходную папку
	if not DirAccess.dir_exists_absolute(source_folder):
		print("❌ Исходная папка не существует: ", source_folder)
		return
	
	# Проверяем/создаем целевую папку
	if not DirAccess.dir_exists_absolute(target_path):
		print("📁 Целевая папка не существует, создаю...")
		DirAccess.make_dir_recursive_absolute(target_path)
	else:
		print("📁 Целевая папка уже существует")
	
	# Копируем файлы
	print("\n📋 Начинаю копирование...")
	var stats = _copy_folder(source_folder, target_path, "")
	
	print("📊 РЕЗУЛЬТАТ:")
	print("   ✅ Скопировано файлов: ", stats.copied)
	print("   📁 Создано папок: ", stats.folders)
	print("   ⏭️ Пропущено (не по расширению): ", stats.skipped)
	
	# Финальная проверка
	if DirAccess.dir_exists_absolute(target_path):
		print("✅ Папка успешно создана: ", target_path)
	else:
		print("❌ Папка НЕ создана!")

# 🔥 ФУНКЦИЯ ВОЗВРАЩАЕТ ПУТЬ ТОЛЬКО К ПАПКЕ РЯДОМ С EXE
func _get_exe_folder_path() -> String:
	# В ЭКСПОРТИРОВАННОЙ ИГРЕ - папка с exe
	if not Engine.is_editor_hint():
		var exe_path = OS.get_executable_path()
		var exe_folder = exe_path.get_base_dir()
		var result = exe_folder.path_join(target_folder_name).path_join("")
		print("📌 Экспорт: exe в ", exe_path)
		print("📌 Целевая папка: ", result)
		return result
	
	# В РЕДАКТОРЕ - для теста используем папку рядом с проектом
	var project_path = ProjectSettings.globalize_path("res://")
	var project_folder = project_path.get_base_dir()
	var test_path = project_folder.path_join(target_folder_name).path_join("")
	print("📌 Редактор: проект в ", project_path)
	print("📌 Тестовая папка: ", test_path)
	print("⚠️ ВНИМАНИЕ: Это тестовая папка, в игре будет рядом с exe")
	return test_path

func _should_copy_file(filename: String) -> bool:
	"""Проверяет, нужно ли копировать файл по расширению"""
	if allowed_extensions.is_empty():
		return true
	
	var ext = filename.get_extension().to_lower()
	return ext in allowed_extensions

func _copy_folder(source: String, target: String, relative_path: String) -> Dictionary:
	"""Рекурсивно копирует папку"""
	var stats = {
		"copied": 0,
		"skipped": 0,
		"folders": 0
	}
	
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
			# Это папка
			if not DirAccess.dir_exists_absolute(target_item):
				DirAccess.make_dir_absolute(target_item)
				stats.folders += 1
				print("   📁 Создана папка: ", new_relative)
			
			var sub_stats = _copy_folder(source_item, target_item, new_relative)
			stats.copied += sub_stats.copied
			stats.skipped += sub_stats.skipped
			stats.folders += sub_stats.folders
		else:
			# Это файл
			if _should_copy_file(item):
				if _copy_file(source_item, target_item):
					print("   ✅ Скопирован: ", new_relative)
					stats.copied += 1
				else:
					print("   ❌ Ошибка: ", new_relative)
			else:
				print("   ⏭️ Пропущен (расширение): ", new_relative)
				stats.skipped += 1
		
		item = dir.get_next()
	
	dir.list_dir_end()
	return stats

func _copy_file(source: String, target: String) -> bool:
	var src_file = FileAccess.open(source, FileAccess.READ)
	if not src_file:
		return false
	
	var data = src_file.get_buffer(src_file.get_length())
	var dst_file = FileAccess.open(target, FileAccess.WRITE)
	if not dst_file:
		return false
	
	dst_file.store_buffer(data)
	return true
