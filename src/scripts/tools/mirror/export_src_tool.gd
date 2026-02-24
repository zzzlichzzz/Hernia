@tool
extends EditorScript

# Скрипт для экспорта папки res://src/ в директорию с исполняемым файлом
# Запуск: Открой этот скрипт в ScriptEditor и нажми Ctrl+Shift+X (или кнопку Run)

func _run():
	var base_dir = OS.get_executable_path().get_base_dir()
	var target_path = base_dir.path_join("src")
	var source_path = "res://src/"
	
	print("=== Экспорт src ===")
	print("Источник: ", source_path)
	print("Цель: ", target_path)
	
	# Проверяем существование исходной папки в проекте
	if not DirAccess.dir_exists_absolute(source_path):
		push_error("Папка res://src/ не найдена в проекте!")
		return
	
	# Проверяем существование целевой папки и удаляем если есть
	if DirAccess.dir_exists_absolute(target_path):
		print("Папка 'src' существует в директории exe, удаляем...")
		var remove_result = _remove_dir_recursive(target_path)
		if not remove_result:
			push_error("Не удалось удалить существующую папку!")
			return
		print("Старая папка удалена")
	
	# Создаем новую папку
	var err = DirAccess.make_dir_recursive_absolute(target_path)
	if err != OK:
		push_error("Не удалось создать папку: " + str(err))
		return
	print("Создана новая папка: ", target_path)
	
	# Копируем содержимое
	var copy_result = _copy_dir_recursive(source_path, target_path)
	if copy_result:
		print("✓ Экспорт успешно завершен!")
	else:
		push_error("✗ Ошибка при копировании файлов")

# Рекурсивное удаление директории
func _remove_dir_recursive(path: String) -> bool:
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name == "." or file_name == "..":
				file_name = dir.get_next()
				continue
			
			var full_path = path.path_join(file_name)
			if dir.current_is_dir():
				var result = _remove_dir_recursive(full_path)
				if not result:
					return false
			else:
				var err = DirAccess.remove_absolute(full_path)
				if err != OK:
					push_error("Ошибка удаления файла " + full_path + ": " + str(err))
					return false
			file_name = dir.get_next()
		dir.list_dir_end()
	
	# Удаляем саму папку
	var err = DirAccess.remove_absolute(path)
	return err == OK

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
		
		var source_path = from.path_join(file_name)
		var dest_path = to.path_join(file_name)
		
		if dir.current_is_dir():
			var err = DirAccess.make_dir_recursive_absolute(dest_path)
			if err != OK:
				push_error("Ошибка создания папки " + dest_path + ": " + str(err))
				success = false
			else:
				var result = _copy_dir_recursive(source_path, dest_path)
				if not result:
					success = false
		else:
			var err = DirAccess.copy_absolute(source_path, dest_path)
			if err != OK:
				push_error("Ошибка копирования файла " + source_path + ": " + str(err))
				success = false
			else:
				print("  Скопирован: ", file_name)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	return success
