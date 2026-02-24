@tool
extends EditorScript

# ================= НАСТРОЙКИ =================
# Список исходных папок внутри проекта (можно несколько)
var source_paths := [
	"res://src",
]

# Инкрементальное копирование (только новые/изменённые)
var incremental := true

# Зеркалирование (удаляет в целевой папке файлы, которых нет в источнике)
var mirror_mode := false

# РАСШИРЕНИЯ ДЛЯ КОПИРОВАНИЯ: укажите с точкой, например [".tres", ".png"]
# Если оставить пустым [], копируются ВСЕ файлы.
var include_extensions := [".tres", ".png"]
# ==============================================

func _run():
	var base_dir = OS.get_executable_path().get_base_dir()
	
	print("\n=== ЭКСПОРТ ПАПОК В ДИРЕКТОРИЮ С EXE ===")
	print("Целевая базовая папка: ", base_dir)
	print("Инкрементальный режим: ", "ВКЛ" if incremental else "ВЫКЛ")
	if incremental and mirror_mode:
		print("Зеркалирование: ВКЛ (удаление лишних файлов)")
	print("Копируются только расширения: ", include_extensions if include_extensions else "ВСЕ ФАЙЛЫ")
	print("")
	
	for src_rel in source_paths:
		var source_path = src_rel
		var relative_name = src_rel.trim_prefix("res://").trim_suffix("/")
		var target_path = base_dir.path_join(relative_name)
		
		print("--- Обработка: ", source_path, " -> ", target_path)
		
		if not DirAccess.dir_exists_absolute(source_path):
			push_error("Папка не найдена: ", source_path)
			continue
		
		# Если не инкрементально — удаляем целевую папку целиком
		if not incremental:
			if DirAccess.dir_exists_absolute(target_path):
				print("Удаление существующей папки (неинкрементальный режим)...")
				if not _remove_dir_recursive(target_path):
					push_error("Не удалось удалить ", target_path)
					continue
			# Создаём папку заново
			var err = DirAccess.make_dir_recursive_absolute(target_path)
			if err != OK:
				push_error("Не удалось создать папку: ", err)
				continue
		else:
			# Инкрементальный режим: создаём целевую папку, если её нет
			if not DirAccess.dir_exists_absolute(target_path):
				var err = DirAccess.make_dir_recursive_absolute(target_path)
				if err != OK:
					push_error("Не удалось создать папку: ", err)
					continue
		
		# Запускаем копирование
		var copy_result = _copy_dir_recursive(source_path, target_path, incremental, mirror_mode)
		if copy_result:
			print("✓ Готово: ", source_path)
		else:
			push_error("✗ Ошибка при копировании ", source_path)
		
		print("")

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
				if not _remove_dir_recursive(full_path):
					return false
			else:
				var err = DirAccess.remove_absolute(full_path)
				if err != OK:
					push_error("Ошибка удаления файла " + full_path + ": " + str(err))
					return false
			file_name = dir.get_next()
		dir.list_dir_end()
	
	var err = DirAccess.remove_absolute(path)
	return err == OK

# Рекурсивное копирование с поддержкой инкрементальности и фильтрации
func _copy_dir_recursive(from: String, to: String, inc: bool, mirror: bool) -> bool:
	var dir_from = DirAccess.open(from)
	if not dir_from:
		push_error("Не удалось открыть исходную папку: " + from)
		return false
	
	# Собираем списки файлов и подпапок в источнике
	var source_files := []
	var source_dirs := []
	
	dir_from.list_dir_begin()
	var file_name = dir_from.get_next()
	while file_name != "":
		if file_name == "." or file_name == "..":
			file_name = dir_from.get_next()
			continue
		
		if dir_from.current_is_dir():
			source_dirs.append(file_name)
		else:
			# ФИЛЬТР РАСШИРЕНИЙ: добавляем только те файлы, чьё расширение разрешено
			if _is_extension_allowed(file_name):
				source_files.append(file_name)
			else:
				# Отладка: показываем, какие файлы ИГНОРИРУЮТСЯ (можно закомментировать)
				print("  [FILTER] пропущен (не то расширение): ", file_name)
		file_name = dir_from.get_next()
	dir_from.list_dir_end()
	
	# Если включено зеркалирование в инкрементальном режиме — удаляем лишние файлы в целевой папке
	if inc and mirror:
		_clean_missing_files(to, source_files + source_dirs)
	
	# Копируем поддиректории (рекурсивно)
	for subdir in source_dirs:
		var src_sub = from.path_join(subdir)
		var dst_sub = to.path_join(subdir)
		
		# Создаём целевую поддиректорию, если её нет
		if not DirAccess.dir_exists_absolute(dst_sub):
			var err = DirAccess.make_dir_recursive_absolute(dst_sub)
			if err != OK:
				push_error("Не удалось создать папку: ", dst_sub)
				return false
		
		if not _copy_dir_recursive(src_sub, dst_sub, inc, mirror):
			return false
	
	# Копируем файлы (только те, что прошли фильтр и попали в source_files)
	for fname in source_files:
		var src_file = from.path_join(fname)
		var dst_file = to.path_join(fname)
		
		# Проверка, нужно ли копировать (инкрементально)
		var need_copy = true
		if inc and FileAccess.file_exists(dst_file):
			var src_time = FileAccess.get_modified_time(src_file)
			var dst_time = FileAccess.get_modified_time(dst_file)
			need_copy = src_time > dst_time
		
		if need_copy:
			var err = DirAccess.copy_absolute(src_file, dst_file)
			if err != OK:
				push_error("Ошибка копирования файла " + src_file + ": " + str(err))
				return false
			else:
				# Показываем, что скопировано
				var marker = "[U]" if inc and FileAccess.file_exists(dst_file) else "[+]"
				print("  ", marker, " ", fname)
		else:
			# Отладка: файл уже актуален
			print("  [=] пропущен (актуален): ", fname)
	
	return true

# Проверяет, разрешено ли расширение файла
func _is_extension_allowed(fname: String) -> bool:
	# Если список расширений пуст — разрешаем всё
	if include_extensions.is_empty():
		return true
	
	for ext in include_extensions:
		if fname.ends_with(ext):
			return true
	return false

# Удаляет в целевой папке файлы и папки, которых нет в источнике (для зеркалирования)
func _clean_missing_files(dst_root: String, valid_names: Array):
	if not DirAccess.dir_exists_absolute(dst_root):
		return
	
	var dir_dst = DirAccess.open(dst_root)
	if not dir_dst:
		return
	
	dir_dst.list_dir_begin()
	var name = dir_dst.get_next()
	while name != "":
		if name == "." or name == "..":
			name = dir_dst.get_next()
			continue
		
		if not name in valid_names:
			var full_path = dst_root.path_join(name)
			if dir_dst.current_is_dir():
				_remove_dir_recursive(full_path)
				print("  [D] удалена папка ", name)
			else:
				var err = DirAccess.remove_absolute(full_path)
				if err == OK:
					print("  [D] удалён файл ", name)
				else:
					push_error("Не удалось удалить ", full_path)
		name = dir_dst.get_next()
	dir_dst.list_dir_end()
