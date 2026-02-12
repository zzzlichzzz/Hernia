@tool
extends Node
# Версия для экспорта! Работает везде.

@export var target_folder: String = "res://src/assets/textures/blocks/"
@export var include_subfolders: bool = true
@export var delete_png_after_conversion: bool = false

func _run():
	print("📸 Конвертация PNG → TRES...")
	
	# Создаём выходную папку
	DirAccess.make_dir_recursive_absolute(target_folder)
	
	var png_files = find_png_files(target_folder)
	if png_files.is_empty():
		print("ℹ️ Нет PNG файлов для конвертации")
		return
	
	print("✅ Найдено PNG: ", png_files.size())
	
	for file_info in png_files:
		convert_png(file_info)

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
			if include_subfolders:
				files += find_png_files(full_path)
		else:
			if file_name.ends_with(".png") and not file_name.ends_with(".png.import"):
				files.append({
					"name": file_name,
					"base_name": file_name.get_basename(),
					"path": full_path,
					"folder": folder
				})
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	return files

func convert_png(file_info: Dictionary):
	var png_path = file_info.path
	var base_name = file_info.base_name
	
	# Используем только имя файла без префиксов пути
	var block_name = base_name
	var tres_path = target_folder.path_join(block_name + ".tres")
	
	# Загружаем PNG
	var img = Image.load_from_file(png_path)
	if not img:
		print("  ❌ Ошибка загрузки: ", file_info.name)
		return
	
	# Конвертируем в RGBA8
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	
	# Создаём и сохраняем текстуру
	var texture = ImageTexture.create_from_image(img)
	var result = ResourceSaver.save(texture, tres_path)
	
	if result == OK:
		print("  ✅ ", block_name + ".tres")
		
		if delete_png_after_conversion:
			_remove_file(png_path)
	else:
		print("  ❌ Ошибка сохранения: ", block_name)

func _remove_file(path: String) -> bool:
	var dir = DirAccess.open(path.get_base_dir())
	if dir:
		return dir.remove(path.get_file()) == OK
	return false
