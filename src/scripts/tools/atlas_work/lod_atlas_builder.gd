@tool
extends Node
# Генератор LOD атласов - ОТДЕЛЬНЫЙ ЗАПУСК!

@export var blocks_folder: String = "res://src/assets/textures/blocks/"
@export var atlas_folder: String = "res://src/assets/textures/atlas/"
@export var lod_levels: Array[int] = [2, 4, 8]
@export var min_size: int = 4
@export var test_mode: bool = true  # Включаем подробный вывод

func _run():
	print("🏗️ ЗАПУСК ГЕНЕРАЦИИ LOD АТЛАСОВ")
	
	# 1. ПРОВЕРКА ПАПОК
	print("\n📁 ПРОВЕРКА ПАПОК:")
	print("   Блоки: ", blocks_folder)
	print("   Атлас: ", atlas_folder)
	
	if not DirAccess.dir_exists_absolute(blocks_folder):
		print("❌ Папка с блоками не существует!")
		return
	
	if not DirAccess.dir_exists_absolute(atlas_folder):
		print("📁 Создаю папку атласа...")
		DirAccess.make_dir_recursive_absolute(atlas_folder)
	
	# 2. ПРОВЕРКА ОРИГИНАЛЬНОГО АТЛАСА
	print("\n📦 ПРОВЕРКА ОРИГИНАЛЬНОГО АТЛАСА:")
	var original_coords_path = atlas_folder.path_join("block_coordinates.tres")
	
	if not ResourceLoader.exists(original_coords_path):
		print("❌ Оригинальный block_coordinates.tres не найден!")
		print("   Сначала запустите texture_atlas_builder.gd")
		return
	
	var original_coords = load(original_coords_path)
	print("✅ Оригинальный атлас загружен")
	print("   - Текстур: ", original_coords.atlas_texture)
	print("   - Блоков: ", original_coords.coordinates.size())
	print("   - Размер: ", original_coords.atlas_texture.get_size())
	
	# 3. ПРОВЕРКА ТЕКСТУР БЛОКОВ
	print("\n🔍 ПРОВЕРКА ТЕКСТУР БЛОКОВ:")
	var block_count = 0
	for block_name in original_coords.coordinates.keys():
		var block_path = blocks_folder.path_join(block_name + ".tres")
		if ResourceLoader.exists(block_path):
			block_count += 1
			if test_mode and block_count <= 5:  # Показываем первые 5
				print("   ✅ ", block_name, " -> ", block_path)
	
	print("   Всего найдено блоков: ", block_count, "/", original_coords.coordinates.size())
	
	if block_count == 0:
		print("❌ Нет текстур блоков! Проверьте папку: ", blocks_folder)
		return
	
	# 4. ГЕНЕРАЦИЯ LOD
	print("\n🎨 ГЕНЕРАЦИЯ LOD:")
	
	var generated = 0
	for lod_factor in lod_levels:
		print("\n   🔷 LOD x" + str(lod_factor) + ":")
		var result = generate_single_lod(lod_factor, original_coords)
		if result:
			generated += 1
		else:
			print("   ❌ Ошибка генерации LOD x" + str(lod_factor))
	
	# 5. ИТОГ
	print("✅ ГЕНЕРАЦИЯ ЗАВЕРШЕНА!")
	print("   Создано LOD: ", generated, "/", lod_levels.size())
	print("   Папка: ", atlas_folder)
	
	# 6. ПОКАЗЫВАЕМ СОЗДАННЫЕ ФАЙЛЫ
	print("\n📋 СОДЕРЖИМОЕ ПАПКИ АТЛАСА:")
	var dir = DirAccess.open(atlas_folder)
	if dir:
		dir.list_dir_begin()
		var file = dir.get_next()
		while file != "":
			if file != "." and file != "..":
				print("   📄 ", file)
			file = dir.get_next()
		dir.list_dir_end()

func generate_single_lod(lod_factor: int, original_coords) -> bool:
	print("     1. Создание изображения...")
	
	# Получаем размер оригинального атласа
	var original_texture = original_coords.atlas_texture
	var original_size = original_texture.get_size()
	
	# Вычисляем новый размер
	var new_width = max(ceil(original_size.x / lod_factor), min_size)
	var new_height = max(ceil(original_size.y / lod_factor), min_size)
	
	print("     2. Размер: ", original_size.x, "x", original_size.y, " → ", new_width, "x", new_height)
	
	# Создаём новое изображение
	var lod_image = Image.create(new_width, new_height, false, Image.FORMAT_RGBA8)
	lod_image.fill(Color(0, 0, 0, 0))
	
	# Проходим по всем блокам
	var blocks_processed = 0
	for block_name in original_coords.coordinates.keys():
		var result = add_block_to_lod(block_name, lod_image, lod_factor, original_coords)
		if result:
			blocks_processed += 1
	
	print("     3. Обработано блоков: ", blocks_processed)
	
	# Сохраняем атлас
	var lod_texture = ImageTexture.create_from_image(lod_image)
	var lod_texture_path = atlas_folder.path_join("block_atlas_lod_" + str(lod_factor) + ".tres")
	ResourceSaver.save(lod_texture, lod_texture_path)
	print("     4. Сохранён атлас: block_atlas_lod_" + str(lod_factor) + ".tres")
	
	# Создаём координаты
	create_lod_coordinates(lod_factor, Vector2i(new_width, new_height), lod_texture, original_coords)
	
	return true

func add_block_to_lod(block_name: String, lod_image: Image, lod_factor: int, original_coords) -> bool:
	var original_data = original_coords.coordinates[block_name]
	
	# Загружаем текстуру блока
	var block_path = blocks_folder.path_join(block_name + ".tres")
	if not ResourceLoader.exists(block_path):
		if test_mode:
			print("      ⚠️ Пропущен (нет текстуры): ", block_name)
		return false
	
	var block_texture: Texture2D = load(block_path)
	var block_image = block_texture.get_image()
	
	if not block_image:
		return false
	
	# Вычисляем новый размер блока
	var new_width = max(ceil(original_data.width / lod_factor), min_size)
	var new_height = max(ceil(original_data.height / lod_factor), min_size)
	
	# Уменьшаем изображение
	block_image.resize(new_width, new_height, Image.INTERPOLATE_LANCZOS)
	
	# Вычисляем новую позицию (пропорционально)
	var new_x = ceil(original_data.x / lod_factor)
	var new_y = ceil(original_data.y / lod_factor)
	
	# Вставляем в LOD атлас
	lod_image.blit_rect(
		block_image,
		Rect2i(0, 0, new_width, new_height),
		Vector2i(new_x, new_y)
	)
	
	return true

func create_lod_coordinates(lod_factor: int, atlas_size: Vector2i, lod_texture: Texture2D, original_coords):
	var AtlasCoordinatesClass = load("res://src/scripts/resources/atlas_coordinates.gd")
	var coords = AtlasCoordinatesClass.new()
	
	coords.atlas_texture = lod_texture
	coords.coordinates = {}
	coords.block_sizes = {}
	
	for block_name in original_coords.coordinates.keys():
		var orig = original_coords.coordinates[block_name]
		
		var new_x = ceil(orig.x / lod_factor)
		var new_y = ceil(orig.y / lod_factor)
		var new_width = max(ceil(orig.width / lod_factor), min_size)
		var new_height = max(ceil(orig.height / lod_factor), min_size)
		
		coords.coordinates[block_name] = {
			"x": new_x,
			"y": new_y,
			"width": new_width,
			"height": new_height,
			"uv": {
				"left": float(new_x) / atlas_size.x,
				"top": float(new_y) / atlas_size.y,
				"right": float(new_x + new_width) / atlas_size.x,
				"bottom": float(new_y + new_height) / atlas_size.y
			}
		}
		
		coords.block_sizes[block_name] = {
			"width": new_width,
			"height": new_height
		}
	
	var path = atlas_folder.path_join("block_coordinates_lod_" + str(lod_factor) + ".tres")
	ResourceSaver.save(coords, path)
	print("     5. Сохранены координаты: block_coordinates_lod_" + str(lod_factor) + ".tres")
