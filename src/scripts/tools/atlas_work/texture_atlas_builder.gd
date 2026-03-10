@tool
extends Node
# Создает PNG атлас из PNG текстур в папке src рядом с игрой

@export var source_path: String = "src/assets/textures/blocks/" 
@export var output_path_block: String = "src/assets/textures/atlas/block" 
@export var allow_mixed_sizes: bool = true


# Глобальные переменные
var block_coordinates: Dictionary = {}
var atlas_width: int = 0
var atlas_height: int = 0

func _run():
	# Определяем базовый путь к папке игры
	
	print("ЗАПУСК СБОРЩИКА АТЛАСА")
	print("📁 Исходная папка с блоками: " + source_path)
	print("📁 Папка для атласа: " + output_path_block)
	
	# Создаем выходную папку

	
	# ШАГ 1: Поиск PNG файлов в папке рядом с игрой
	print("ШАГ 1: Поиск PNG в папке игры")
	var png_files = find_png_files(source_path)

	print("Найдено PNG: " + str(png_files.size()))
	for f in png_files:
		print("   - " + f.name + " (" + f.path + ")")
	
	# ШАГ 2: Загрузка изображений
	print("ШАГ 2: Загрузка изображений")
	var block_infos = load_images(png_files)
	if block_infos.is_empty():
		print("НЕ УДАЛОСЬ ЗАГРУЗИТЬ ИЗОБРАЖЕНИЯ")
		return
	
	print("Загружено блоков: " + str(block_infos.size()))
	
	# ШАГ 3: Оптимизация размещения
	print("ШАГ 3: Оптимизация размещения")
	optimize_layout(block_infos)
	
	# ШАГ 4: Создание атласа
	print("ШАГ 4: Создание атласа")
	create_atlas(block_infos)
	
	# ШАГ 5: Сохранение координат
	print("ШАГ 5: Сохранение координат")
	save_coordinates()
	
	# ШАГ 6: Проверка результата
	print("ШАГ 6: Проверка результата")
	check_result()
	
	print("СБОРКА ЗАВЕРШЕНА")

func get_game_folder() -> String:
	"""Возвращает путь к папке, где находится игра"""
	if Engine.is_editor_hint():
		# В редакторе используем user:// для тестов
		return "user://"
	else:
		# В экспортированной игре - папка с exe
		return OS.get_executable_path().get_base_dir().path_join("")

func find_png_files(folder: String) -> Array:
	"""Ищет все PNG файлы в папке и подпапках"""
	var files = []
	_find_png_files_recursive(folder, files)
	files.sort_custom(func(a, b): return a.name < b.name)
	return files

func _find_png_files_recursive(folder: String, files: Array):
	var dir = DirAccess.open(folder)
	if not dir:
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue
		
		var full_path = folder.path_join(file_name)
		
		if dir.current_is_dir():
			_find_png_files_recursive(full_path, files)
		else:
			if file_name.ends_with(".png") and not file_name.ends_with(".png.import"):
				var block_name = file_name.get_basename()
				files.append({
					"name": block_name,
					"path": full_path
				})
				print("    Найден PNG: " + block_name)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()

func load_images(png_files: Array) -> Array:
	"""Загружает изображения из PNG файлов"""
	var infos = []
	var failed = 0
	
	for file_info in png_files:
		print("  Загрузка: " + file_info.path)
		var img = Image.load_from_file(file_info.path)
		if img:
			if img.get_format() != Image.FORMAT_RGBA8:
				img.convert(Image.FORMAT_RGBA8)
			
			infos.append({
				"name": file_info.name,
				"image": img,
				"width": img.get_width(),
				"height": img.get_height()
			})
			print("Загружен: " + file_info.name + " " + str(img.get_width()) + "x" + str(img.get_height()))
		else:
			print("Не удалось загрузить: " + file_info.path)
			failed += 1
	
	if failed > 0:
		print("Не удалось загрузить " + str(failed) + " файлов")
	
	return infos

func optimize_layout(block_infos: Array):
	if block_infos.is_empty():
		return
	
	if not allow_mixed_sizes:
		var size = block_infos[0].width
		var total = block_infos.size()
		var per_row = ceil(sqrt(total))
		
		atlas_width = per_row * size
		atlas_height = ceil(total / float(per_row)) * size
		
		var i = 0
		for block in block_infos:
			block.x = (i % per_row) * size
			block.y = floor(i / per_row) * size
			i += 1
		
		atlas_width = ceil_to_power_of_two(atlas_width)
		atlas_height = ceil_to_power_of_two(atlas_height)
		print("  Размер атласа: " + str(atlas_width) + "x" + str(atlas_height))
		return
	
	block_infos.sort_custom(func(a, b): return b.height - a.height)
	
	var total_area = 0
	for b in block_infos:
		total_area += b.width * b.height
	
	atlas_width = ceil(sqrt(total_area))
	atlas_height = atlas_width
	
	for attempt in range(10):
		if try_pack(block_infos, atlas_width, atlas_height):
			break
		atlas_width = ceil(atlas_width * 1.2)
		atlas_height = ceil(atlas_height * 1.2)
	
	trim_atlas(block_infos)
	
	atlas_width = ceil_to_power_of_two(atlas_width)
	atlas_height = ceil_to_power_of_two(atlas_height)
	print("  Размер атласа: " + str(atlas_width) + "x" + str(atlas_height))

func try_pack(blocks: Array, max_w: int, max_h: int) -> bool:
	var shelves = []
	
	for block in blocks:
		var placed = false
		var bw = block.width
		var bh = block.height
		
		for shelf in shelves:
			if shelf.height >= bh and shelf.width_used + bw <= max_w:
				block.x = shelf.width_used
				block.y = shelf.y
				shelf.width_used += bw
				placed = true
				break
		
		if not placed:
			var new_y = 0
			if shelves.size() > 0:
				new_y = shelves[-1].y + shelves[-1].height
			
			if new_y + bh <= max_h:
				shelves.append({
					"y": new_y,
					"height": bh,
					"width_used": bw
				})
				block.x = 0
				block.y = new_y
				placed = true
		
		if not placed:
			return false
	
	return true

func trim_atlas(blocks: Array):
	var max_x = 0
	var max_y = 0
	
	for b in blocks:
		max_x = max(max_x, b.x + b.width)
		max_y = max(max_y, b.y + b.height)
	
	atlas_width = max_x
	atlas_height = max_y
	print("  ✂️ Атлас (обрезано): " + str(atlas_width) + "x" + str(atlas_height))

func ceil_to_power_of_two(value: int) -> int:
	var power = 1
	while power < value:
		power *= 2
	return power

func create_atlas(block_infos: Array):
	var atlas_image = Image.create(atlas_width, atlas_height, false, Image.FORMAT_RGBA8)
	atlas_image.fill(Color(0, 0, 0, 0))
	
	for block in block_infos:
		atlas_image.blit_rect(
			block.image,
			Rect2i(0, 0, block.width, block.height),
			Vector2i(block.x, block.y)
		)
		
		block_coordinates[block.name] = {
			"x": block.x, "y": block.y,
			"width": block.width, "height": block.height,
			"uv": {
				"left": float(block.x) / atlas_width,
				"top": float(block.y) / atlas_height,
				"right": float(block.x + block.width) / atlas_width,
				"bottom": float(block.y + block.height) / atlas_height
			}
		}
		
		print("    ✓ " + block.name + " @ (" + str(block.x) + ", " + str(block.y) + ")")
	
	var atlas_png_path = output_path_block.path_join("block_atlas.png")
	var save_result = atlas_image.save_png(atlas_png_path)
	
	if save_result == OK:
		print("PNG атлас сохранен: " + atlas_png_path)
	else:
		print("Ошибка сохранения PNG! Код: " + str(save_result))

func save_coordinates():
	var AtlasCoordinatesClass = load("res://src/scripts/resources/atlas_coordinates.gd")
	if not AtlasCoordinatesClass:
		print("Не удалось загрузить класс AtlasCoordinates")
		return
	
	var coords = AtlasCoordinatesClass.new()
	
	coords.coordinates = block_coordinates
	coords.block_sizes = {}
	
	for name in block_coordinates:
		coords.block_sizes[name] = {
			"width": block_coordinates[name].width,
			"height": block_coordinates[name].height
		}
	
	coords.png_filename = "block_atlas.png"
	coords.png_path = output_path_block.path_join("block_atlas.png")
	
	# Загружаем PNG как текстуру
	var png_path = output_path_block.path_join("block_atlas.png")
	if FileAccess.file_exists(png_path):
		var img = Image.load_from_file(png_path)
		coords.atlas_texture = ImageTexture.create_from_image(img)
		print("PNG загружен как текстура")
	else:
		print("PNG не найден, создаю пустую текстуру")
		var empty_img = Image.create(1, 1, false, Image.FORMAT_RGBA8)
		coords.atlas_texture = ImageTexture.create_from_image(empty_img)
	
	var coords_path = output_path_block.path_join("block_coordinates.tres")
	var save_result = ResourceSaver.save(coords, coords_path)
	
	if save_result == OK:
		print("Координаты сохранены: " + coords_path)
	else:
		print("Ошибка сохранения координат! Код: " + str(save_result))

func check_result():
	var png_path = output_path_block.path_join("block_atlas.png")
	var coords_path = output_path_block.path_join("block_coordinates.tres")
	
	if FileAccess.file_exists(png_path):
		var file = FileAccess.open(png_path, FileAccess.READ)
		if file:
			var size = file.get_length()
			file.close()
			print("PNG создан: " + png_path + " (" + str(size) + " байт)")
		else:
			print("PNG создан: " + png_path)
	else:
		print("PNG НЕ СОЗДАН: " + png_path)
	
	if ResourceLoader.exists(coords_path):
		print("Координаты созданы: " + coords_path)
	else:
		print("Координаты НЕ СОЗДАНЫ: " + coords_path)
