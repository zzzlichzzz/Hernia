@tool
extends Node
# Версия для экспорта! Работает везде.

@export var blocks_folder: String = "res://src/assets/textures/blocks/"
@export var output_folder: String = "res://src/assets/textures/atlas/"
@export var delete_source_textures: bool = true
@export var allow_mixed_sizes: bool = true

var create_lods = load("res://src/scripts/tools/atlas_work/lod_atlas_builder.gd").new()

var block_coordinates: Dictionary = {}
var used_texture_paths: Array = []
var atlas_width: int = 0
var atlas_height: int = 0

func _run():
	print("🎨 Создание атласа...")
	
	clean_output_folder()
	
	var texture_files = get_texture_resources()
	if texture_files.is_empty():
		print("❌ Нет .tres текстур в: ", blocks_folder)
		return
	
	print("✅ Найдено текстур: ", texture_files.size())
	
	var block_infos = collect_block_infos(texture_files)
	optimize_layout(block_infos)
	create_atlas(block_infos)
	save_coordinates()
	create_lods._run()
	
	if delete_source_textures:
		delete_source_files()

func clean_output_folder():
	if DirAccess.dir_exists_absolute(output_folder):
		var dir = DirAccess.open(output_folder)
		if dir:
			dir.list_dir_begin()
			var f = dir.get_next()
			while f != "":
				if f != "." and f != "..":
					dir.remove(f)
				f = dir.get_next()
			dir.list_dir_end()
	else:
		DirAccess.make_dir_recursive_absolute(output_folder)

func get_texture_resources() -> Array:
	var textures = []
	var dir = DirAccess.open(blocks_folder)
	
	if dir:
		dir.list_dir_begin()
		var f = dir.get_next()
		while f != "":
			if f.ends_with(".tres"):
				textures.append({
					"name": f.get_basename(),
					"path": blocks_folder.path_join(f)
				})
			f = dir.get_next()
		dir.list_dir_end()
	
	textures.sort_custom(func(a, b): return a.name < b.name)
	return textures

func collect_block_infos(texture_files: Array) -> Array:
	var infos = []
	
	for tex in texture_files:
		var texture: Texture2D = ResourceLoader.load(tex.path, "Texture2D")
		if texture:
			var img = texture.get_image()
			if img:
				if img.get_format() != Image.FORMAT_RGBA8:
					img.convert(Image.FORMAT_RGBA8)
				
				infos.append({
					"name": tex.name,
					"path": tex.path,
					"image": img,
					"width": img.get_width(),
					"height": img.get_height()
				})
				print("  📦 ", tex.name, " ", img.get_width(), "x", img.get_height())
	
	return infos

func optimize_layout(block_infos: Array):
	if block_infos.is_empty():
		return
	
	if not allow_mixed_sizes:
		var size = block_infos[0].width
		var total = block_infos.size()
		var per_row = ceil(sqrt(total))
		
		# Убираем padding из расчета!
		atlas_width = per_row * size
		atlas_height = ceil(total / float(per_row)) * size
		
		var i = 0
		for block in block_infos:
			# Без padding!
			block.x = (i % per_row) * size
			block.y = floor(i / per_row) * size
			i += 1
		
		# Выравниваем размеры под степени двойки
		atlas_width = ceil_to_power_of_two(atlas_width)
		atlas_height = ceil_to_power_of_two(atlas_height)
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
	
	# Финальное выравнивание под степени двойки
	atlas_width = ceil_to_power_of_two(atlas_width)
	atlas_height = ceil_to_power_of_two(atlas_height)

func try_pack(blocks: Array, max_w: int, max_h: int) -> bool:
	var shelves = []
	
	for block in blocks:
		var placed = false
		# Убираем padding!
		var bw = block.width
		var bh = block.height
		
		for shelf in shelves:
			if shelf.height >= bh and shelf.width_used + bw <= max_w:
				# Без padding!
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
				# Без padding!
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
		# Убираем padding из расчета!
		max_x = max(max_x, b.x + b.width)
		max_y = max(max_y, b.y + b.height)
	
	atlas_width = max_x
	atlas_height = max_y
	print("  ✂️ Атлас (обрезано): ", atlas_width, "x", atlas_height)

# НОВАЯ ФУНКЦИЯ: округление до степени двойки
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
		
		used_texture_paths.append(block.path)
		print("  ✓ ", block.name, " @ (", block.x, ", ", block.y, ")")
	
	var atlas_texture = ImageTexture.create_from_image(atlas_image)
	ResourceSaver.save(atlas_texture, output_folder.path_join("block_atlas.tres"))

func save_coordinates():
	# Загружаем класс AtlasCoordinates из отдельного файла
	var AtlasCoordinatesClass = load("res://src/scripts/resources/atlas_coordinates.gd")
	var coords = AtlasCoordinatesClass.new()
	
	coords.coordinates = block_coordinates
	coords.atlas_texture = load(output_folder.path_join("block_atlas.tres"))
	coords.block_sizes = {}
	
	for name in block_coordinates:
		coords.block_sizes[name] = {
			"width": block_coordinates[name].width,
			"height": block_coordinates[name].height
		}
	
	ResourceSaver.save(coords, output_folder.path_join("block_coordinates.tres"))
	print("📊 Координаты сохранены")

func delete_source_files():
	for path in used_texture_paths:
		var dir = DirAccess.open(path.get_base_dir())
		if dir:
			dir.remove(path.get_file())
	print("🗑️ Исходники удалены")
