@tool
extends EditorScript

# НАСТРОЙКИ
@export var target_folder: String = "res://src/assets/textures/blocks/"
@export var output_folder: String = "res://src/assets/textures/blocks/"  # Все .tres будут здесь
@export var include_subfolders: bool = true             # Ищет текстуры по папкам
@export var delete_png_after_conversion: bool = false   # Удаляет исходники
@export var prefix_block_names_with_path: bool = false  # Добавлять путь к имени блока

func _run():
	print("🚀 Запуск конвертации PNG → TRES...")
	print("📁 Исходная папка (PNG): ", target_folder)
	print("📁 Папка назначения (TRES): ", output_folder)
	print("🔍 Сканировать подпапки: ", include_subfolders)
	print("🏷️ Префикс пути в имени: ", prefix_block_names_with_path)
	print("🗑️ Удалять PNG: ", delete_png_after_conversion)
	print("")
	
	# Создаём выходную папку, если её нет
	DirAccess.make_dir_recursive_absolute(output_folder)
	
	var dir = DirAccess.open(target_folder)
	if not dir:
		print("❌ Не удалось открыть папку: ", target_folder)
		return
	
	# ШАГ 1: Поиск всех PNG файлов
	var png_files = find_png_files(target_folder)
	
	if png_files.is_empty():
		print("ℹ️ PNG файлы не найдены в: ", target_folder)
		return
	
	print("📸 Найдено PNG файлов: ", png_files.size())
	print("")
	
	# ШАГ 2: Конвертация
	convert_all_png(png_files)

func find_png_files(folder: String) -> Array:
	var files = []
	var dir = DirAccess.open(folder)
	
	if not dir:
		return files
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		var full_path = folder.path_join(file_name)
		
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue
		
		if dir.current_is_dir():
			# Рекурсивно сканируем подпапки
			if include_subfolders:
				var subfolder_files = find_png_files(full_path)
				files += subfolder_files
		else:
			# Берём только .png без .import
			if file_name.ends_with(".png") and not file_name.ends_with(".png.import"):
				# Вычисляем относительный путь от target_folder
				var relative_path = ""
				if folder.length() > target_folder.length():
					relative_path = folder.trim_prefix(target_folder).trim_prefix("/").trim_prefix("\\")
				
				files.append({
					"name": file_name,
					"base_name": file_name.get_basename(),
					"path": full_path,
					"folder": folder,
					"relative_path": relative_path  # Сохраняем относительный путь
				})
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	return files

func convert_all_png(png_files: Array):
	var converted = 0
	var skipped = 0
	var failed = []
	
	# Словарь для отслеживания уникальных имён
	var used_names = {}
	
	for file_info in png_files:
		var png_path = file_info.path
		var base_name = file_info.base_name
		var relative_path = file_info.relative_path
		
		# Формируем имя блока
		var block_name = base_name
		if prefix_block_names_with_path and relative_path != "":
			# Заменяем разделители на подчёркивания
			var path_prefix = relative_path.replace("/", "_").replace("\\", "_")
			block_name = path_prefix + "_" + base_name
			# Очищаем от лишних символов
			block_name = block_name.replace("__", "_").replace(" ", "_").to_lower()
		
		# Проверяем уникальность имени
		if used_names.has(block_name):
			print("⚠️ Конфликт имён: ", block_name)
			print("   Первый файл: ", used_names[block_name])
			print("   Второй файл: ", relative_path + "/" + base_name if relative_path != "" else base_name)
			print("   Добавляем суффикс...")
			
			var counter = 1
			var new_name = block_name + "_" + str(counter)
			while used_names.has(new_name):
				counter += 1
				new_name = block_name + "_" + str(counter)
			block_name = new_name
		
		var tres_path = output_folder.path_join(block_name + ".tres")
		used_names[block_name] = relative_path + "/" + base_name if relative_path != "" else base_name
		
		print("🔄 [", converted + skipped + 1, "/", png_files.size(), "] ", 
			  file_info.name, " → ", block_name + ".tres")
		
		# Проверяем, существует ли уже .tres
		if ResourceLoader.exists(tres_path) and not should_overwrite():
			print("  ⏭️ Пропущен (уже существует): ", block_name + ".tres")
			skipped += 1
			continue
		
		# Загружаем PNG
		var img = Image.load_from_file(png_path)
		if not img:
			print("  ❌ Ошибка загрузки PNG: ", file_info.name)
			failed.append(file_info.name)
			continue
		
		# Конвертируем в RGBA8
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
		
		# Создаём и сохраняем текстуру
		var texture = ImageTexture.create_from_image(img)
		var result = ResourceSaver.save(texture, tres_path)
		
		if result == OK:
			print("  ✅ Создан: ", block_name + ".tres")
			converted += 1
			
			# Удаляем PNG ТОЛЬКО если включена опция
			if delete_png_after_conversion:
				var remove_result = delete_file_safely(png_path)
				if remove_result:
					print("  🗑️ Удалён PNG: ", file_info.name)
				else:
					print("  ⚠️ Не удалось удалить PNG: ", file_info.name)
		else:
			print("  ❌ Ошибка сохранения .tres: ", block_name)
			failed.append(file_info.name)
	
	print("✅ Конвертировано: ", converted)
	print("⏭️ Пропущено: ", skipped)
	print("📁 Все .tres файлы сохранены в: ", output_folder)
	
	if delete_png_after_conversion:
		print("🗑️ PNG удалены: ДА")
	else:
		print("💾 PNG сохранены: ДА (исходники в подпапках)")
	
	if not failed.is_empty():
		print("⚠️ Ошибки (", failed.size(), "):")
		for f in failed:
			print("   - ", f)
	else:
		print("🎉 Конвертация завершена успешно!")
	
	# Обновляем FileSystem
	if Engine.is_editor_hint():
		print("")
		print("🔄 Обновление FileSystem...")
		EditorInterface.get_resource_filesystem().scan()
		print("✅ FileSystem обновлён")
	
	print("")
	print("💡 Теперь можете запускать сборщик атласа!")
	print("📁 Все текстуры собраны в одной папке: ", output_folder)

func should_overwrite() -> bool:
	return true

func delete_file_safely(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	
	var dir = DirAccess.open(path.get_base_dir())
	if dir:
		return dir.remove(path.get_file()) == OK
	return false
