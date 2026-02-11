@tool
extends EditorScript

# Настройки
@export var blocks_folder: String = "res://src/assets/textures/blocks/"
@export var output_folder: String = "res://src/assets/textures/atlas/"
@export var delete_source_textures: bool = true
@export var padding: int = 1
@export var allow_mixed_sizes: bool = true

var block_coordinates: Dictionary = {}
var used_texture_paths: Array = []
var blocks_per_row: int = 0
var atlas_width: int = 0
var atlas_height: int = 0

func _run():
	print("🚀 Запуск сборщика атласа...")
	
	# ШАГ 1: ОЧИЩАЕМ папку атласа (НЕ УДАЛЯЕМ её)
	clean_atlas_folder()
	
	# ШАГ 2: СОЗДАЁМ папку заново (ВАЖНО!)
	DirAccess.make_dir_recursive_absolute(output_folder)
	
	# ШАГ 3: Ищем текстуры
	var texture_files = get_texture_resources()
	
	if texture_files.is_empty():
		print("❌ Нет .tres текстур в папке: ", blocks_folder)
		return
	
	print("✅ Найдено текстур: ", texture_files.size())
	
	# ШАГ 4: Собираем информацию о размерах блоков
	var block_infos = collect_block_infos(texture_files)
	
	# ШАГ 5: Оптимизируем размещение
	optimize_atlas_layout(block_infos)
	
	# ШАГ 6: Создаём атлас
	create_atlas_direct(block_infos)
	save_coordinates()
	
	# ШАГ 7: Удаляем исходные .tres файлы
	if delete_source_textures:
		delete_source_texture_files()
	
	# ШАГ 8: Обновляем FileSystem
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()
	
	print("🎉 Готово! Новый атлас создан в: ", output_folder)

func clean_atlas_folder():
	"""ОЧИЩАЕТ содержимое папки, НО НЕ УДАЛЯЕТ саму папку"""
	if not DirAccess.dir_exists_absolute(output_folder):
		print("📁 Папка не существует, будет создана")
		return
	
	print("🧹 Очистка папки: ", output_folder)
	
	var dir = DirAccess.open(output_folder)
	if not dir:
		print("❌ Не удалось открыть папку")
		return
	
	var deleted = 0
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name != "." and file_name != "..":
			var full_path = output_folder.path_join(file_name)
			
			if dir.current_is_dir():
				# Удаляем вложенную папку
				var sub_dir = DirAccess.open(full_path)
				if sub_dir:
					sub_dir.list_dir_begin()
					var sub_file = sub_dir.get_next()
					while sub_file != "":
						if sub_file != "." and sub_file != "..":
							sub_dir.remove(sub_file)
						sub_file = sub_dir.get_next()
					sub_dir.list_dir_end()
				# Удаляем пустую папку
				dir.remove(file_name)
				print("  🗑️ Папка: ", file_name)
			else:
				# Удаляем файл
				var error = dir.remove(file_name)
				if error == OK:
					print("  🗑️ Файл: ", file_name)
					deleted += 1
				else:
					print("  ⚠️ Не удалось удалить: ", file_name)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	print("✅ Удалено файлов: ", deleted)

func get_texture_resources() -> Array:
	var textures = []
	var dir = DirAccess.open(blocks_folder)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if file_name.ends_with(".tres"):
				textures.append({
					"name": file_name.get_basename(),
					"path": blocks_folder.path_join(file_name)
				})
			file_name = dir.get_next()
		dir.list_dir_end()
	
	textures.sort_custom(func(a, b): return a.name < b.name)
	return textures

func collect_block_infos(texture_files: Array) -> Array:
	var block_infos = []
	
	for tex_info in texture_files:
		var texture: Texture2D = ResourceLoader.load(tex_info.path, "Texture2D")
		if texture:
			var block_image = texture.get_image()
			if block_image:
				if block_image.get_format() != Image.FORMAT_RGBA8:
					block_image.convert(Image.FORMAT_RGBA8)
				
				var size = block_image.get_size()
				
				block_infos.append({
					"name": tex_info.name,
					"path": tex_info.path,
					"image": block_image,
					"width": size.x,
					"height": size.y,
					"texture": texture
				})
				
				print("  📦 ", tex_info.name, " - ", size.x, "x", size.y)
	
	return block_infos

func optimize_atlas_layout(block_infos: Array):
	if block_infos.is_empty():
		return
	
	if not allow_mixed_sizes:
		var first_size = block_infos[0].width
		var total_blocks = block_infos.size()
		
		blocks_per_row = ceil(sqrt(total_blocks))
		atlas_width = blocks_per_row * (first_size + padding) + padding
		atlas_height = ceil(total_blocks / float(blocks_per_row)) * (first_size + padding) + padding
		
		var index = 0
		for block in block_infos:
			var x = (index % blocks_per_row) * (first_size + padding) + padding
			var y = floor(index / blocks_per_row) * (first_size + padding) + padding
			
			block["x"] = x
			block["y"] = y
			index += 1
		
		return
	
	print("  🔧 Оптимизация размещения блоков разного размера...")
	
	block_infos.sort_custom(func(a, b): return b.height - a.height)
	
	var total_area = 0
	for block in block_infos:
		total_area += block.width * block.height
	
	var initial_size = ceil(sqrt(total_area)) + 64
	atlas_width = initial_size
	atlas_height = initial_size
	
	var max_attempts = 10
	for attempt in range(max_attempts):
		if try_pack_blocks(block_infos, atlas_width, atlas_height):
			print("    ✓ Упаковано в ", atlas_width, "x", atlas_height)
			break
		else:
			atlas_width = ceil(atlas_width * 1.2)
			atlas_height = ceil(atlas_height * 1.2)
			print("    ↻ Увеличиваем атлас до ", atlas_width, "x", atlas_height)
	
	trim_atlas_size(block_infos)

func try_pack_blocks(block_infos: Array, max_width: int, max_height: int) -> bool:
	var shelves = []
	
	for block in block_infos:
		var placed = false
		var block_width = block.width + padding * 2
		var block_height = block.height + padding * 2
		
		for shelf in shelves:
			if shelf.height >= block_height and shelf.width_used + block_width <= max_width:
				block["x"] = shelf.width_used + padding
				block["y"] = shelf.y + padding
				shelf.width_used += block_width
				placed = true
				break
		
		if not placed:
			var new_y = 0
			if shelves.size() > 0:
				new_y = shelves[-1].y + shelves[-1].height
			
			if new_y + block_height <= max_height:
				shelves.append({
					"y": new_y,
					"height": block_height,
					"width_used": block_width
				})
				block["x"] = padding
				block["y"] = new_y + padding
				placed = true
		
		if not placed:
			return false
	
	return true

func trim_atlas_size(block_infos: Array):
	var max_x = 0
	var max_y = 0
	
	for block in block_infos:
		max_x = max(max_x, block.x + block.width + padding)
		max_y = max(max_y, block.y + block.height + padding)
	
	atlas_width = max_x
	atlas_height = max_y
	
	print("  ✂️ Обрезан до: ", atlas_width, "x", atlas_height)

func create_atlas_direct(block_infos: Array):
	var atlas_image = Image.create(atlas_width, atlas_height, false, Image.FORMAT_RGBA8)
	atlas_image.fill(Color(0, 0, 0, 0))
	
	for block in block_infos:
		var x = block.x
		var y = block.y
		var block_image = block.image
		
		atlas_image.blit_rect(
			block_image,
			Rect2i(0, 0, block.width, block.height),
			Vector2i(x, y)
		)
		
		block_coordinates[block.name] = {
			"x": x, "y": y,
			"width": block.width,
			"height": block.height,
			"uv": {
				"left": float(x) / atlas_width,
				"top": float(y) / atlas_height,
				"right": float(x + block.width) / atlas_width,
				"bottom": float(y + block.height) / atlas_height
			}
		}
		
		used_texture_paths.append(block.path)
		
		print("  ✓ ", block.name, " @ (", x, ", ", y, ") [", block.width, "x", block.height, "]")
	
	var atlas_texture = ImageTexture.create_from_image(atlas_image)
	var atlas_tres_path = output_folder.path_join("block_atlas.tres")
	ResourceSaver.save(atlas_texture, atlas_tres_path)
	print("  📦 Создан атлас: block_atlas.tres (", atlas_width, "x", atlas_height, ")")

func save_coordinates():
	var coords = AtlasCoordinates.new()
	coords.coordinates = block_coordinates
	coords.atlas_texture = load(output_folder.path_join("block_atlas.tres"))
	coords.block_sizes = {}
	
	for block_name in block_coordinates:
		coords.block_sizes[block_name] = {
			"width": block_coordinates[block_name].width,
			"height": block_coordinates[block_name].height
		}
	
	var coord_path = output_folder.path_join("block_coordinates.tres")
	ResourceSaver.save(coords, coord_path)
	print("📊 Координаты сохранены: block_coordinates.tres")

func delete_source_texture_files():
	if used_texture_paths.is_empty():
		print("⚠️ Нет файлов для удаления")
		return
	
	print("🗑️ Удаление исходных текстур...")
	var deleted = 0
	var failed = []
	
	for texture_path in used_texture_paths:
		if FileAccess.file_exists(texture_path):
			var dir = DirAccess.open(texture_path.get_base_dir())
			if dir:
				var error = dir.remove(texture_path.get_file())
				if error == OK:
					print("  ✅ Удалён: ", texture_path.get_file())
					deleted += 1
				else:
					failed.append(texture_path.get_file())
			else:
				failed.append(texture_path.get_file())
		else:
			failed.append(texture_path.get_file())
	
	print("  📊 Итого удалено: ", deleted, " из ", used_texture_paths.size())

class AtlasCoordinates extends Resource:
	@export var coordinates: Dictionary = {}
	@export var atlas_texture: Texture2D
	@export var block_sizes: Dictionary = {}
	
	func get_uv(block_name: String) -> Rect2:
		if coordinates.has(block_name):
			var coord = coordinates[block_name]
			return Rect2(coord.uv.left, coord.uv.top, 
						coord.uv.right - coord.uv.left, 
						coord.uv.bottom - coord.uv.top)
		return Rect2(0, 0, 1, 1)
	
	func get_atlas_texture_for_block(block_name: String) -> AtlasTexture:
		if not coordinates.has(block_name):
			return null
		
		var coord = coordinates[block_name]
		var atlas_tex = AtlasTexture.new()
		atlas_tex.atlas = atlas_texture
		atlas_tex.region = Rect2(coord.x, coord.y, coord.width, coord.height)
		return atlas_tex
