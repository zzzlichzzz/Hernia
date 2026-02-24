@tool
extends EditorScript

# Скрипт для импорта папки src из директории с исполняемым файлом в res://common/
# Запуск: Открой этот скрипт в ScriptEditor и нажми Ctrl+Shift+X (или кнопку Run)

func _run():
	var base_dir = OS.get_executable_path().get_base_dir()
	var source_path = base_dir.path_join("src")
	var target_path = "res://common/"
	
	print("=== Импорт src ===")
	print("Источник: ", source_path)
	print("Цель: ", target_path)
	
	# Проверяем существование исходной папки
	if not DirAccess.dir_exists_absolute(source_path):
		push_error("Папка 'src' не найдена в директории с исполняемым файлом: " + source_path)
		return
	
	# Создаем целевую папку если нужно
	if not DirAccess.dir_exists_absolute(target_path):
		print("Создаем папку res://common/...")
		var err = DirAccess.make_dir_recursive_absolute(target_path)
		if err != OK:
			push_error("Не удалось создать целевую папку: " + str(err))
			return
	
	# Копируем содержимое
	var copy_result = _copy_dir_recursive(source_path, target_path)
	if copy_result:
		print("✓ Импорт успешно завершен!")
		print("Обновление файловой системы редактора...")
		# Обновляем файловую систему редактора, чтобы файлы появились в FileSystem dock
		EditorInterface.get_resource_filesystem().scan()
		print("✓ Готово! Файлы доступны в редакторе в папке res://common/")
	else:
		push_error("✗ Ошибка при копировании файлов")

# Рекурсивное копирование директории
func _copy_dir_recursive(from: String, to: String) -> bool:
	var dir = DirAccess.open(from)
	if not dir:
		push_error("Не удалось открыть исходную папку: " + from)
		return false
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	var success = true
	
	while file_name != "":
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue
		
		var source_file_path = from.path_join(file_name)
		var dest_file_path = to.path_join(file_name)
		
		if dir.current_is_dir():
			var err = DirAccess.make_dir_recursive_absolute(dest_file_path)
			if err != OK:
				push_error("Ошибка создания папки " + dest_file_path + ": " + str(err))
				success = false
			else:
				var result = _copy_dir_recursive(source_file_path, dest_file_path)
				if not result:
					success = false
		else:
			var err = DirAccess.copy_absolute(source_file_path, dest_file_path)
			if err != OK:
				push_error("Ошибка копирования файла " + source_file_path + ": " + str(err))
				success = false
			else:
				print("  Скопирован: ", file_name)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	return success
