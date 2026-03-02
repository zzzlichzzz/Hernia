extends Node
class_name BlockIconGenerator
## Генератор иконок блоков для инвентаря
## Создаёт текстуры на основе атласа блоков

const ATLAS_COORDS_PATH = "res://src/assets/textures/atlas/block_coordinates.tres"
const ATLAS_TEXTURE_PATH = "res://src/assets/textures/atlas/block_atlas.png"
const LIBRARY_PATH = "res://src/data/blocks/voxel_blocky_library.tres"
const ICONS_FOLDER = "res://src/assets/icons/blocks/"
#const ICON_SIZE = 64  # Убрали фиксированный размер - используем оригинальный из атласа

var _atlas_coords: AtlasCoordinates
var _atlas_texture: Texture2D
var _library: VoxelBlockyLibrary
var _icons_cache: Dictionary = {}  # block_name -> Texture2D

# Маппинг имён блоков в библиотеке к именам текстур в атласе
var _block_to_texture_map: Dictionary = {
	"block_grass": "grass_block_top",
	"grass": "grass_block_top",
	"cherry stair": "cherry_planks",
	"cherry_stair": "cherry_planks",
	"cherry-planks": "cherry_planks",
	"dirt": "dirt",
	"stone": "stone",
	"air": "",
}


func _ready():
	_load_atlas()
	_load_library()

func _load_library():
	if ResourceLoader.exists(LIBRARY_PATH):
		_library = load(LIBRARY_PATH) as VoxelBlockyLibrary
		if _library:
			print("✅ VoxelBlockyLibrary загружена для иконок")
	else:
		print("❌ Библиотека не найдена: ", LIBRARY_PATH)


func _load_atlas():
	if ResourceLoader.exists(ATLAS_COORDS_PATH):
		_atlas_coords = load(ATLAS_COORDS_PATH) as AtlasCoordinates
	
	if _atlas_coords and _atlas_coords.atlas_texture:
		_atlas_texture = _atlas_coords.atlas_texture
	else:
		# Загружаем напрямую из PNG
		if ResourceLoader.exists(ATLAS_TEXTURE_PATH):
			_atlas_texture = load(ATLAS_TEXTURE_PATH)
	
	if _atlas_texture:
		print("✅ Atlas texture загружена для иконок")
	else:
		print("❌ Не удалось загрузить атлас")


## Получить иконку блока по имени (resource_name)
func get_icon(block_name: String) -> Texture2D:
	if _icons_cache.has(block_name):
		return _icons_cache[block_name]
	
	var icon = _create_icon_from_atlas(block_name)
	if icon:
		_icons_cache[block_name] = icon
	return icon


## Получить иконку блока по ID
func get_icon_by_id(block_id: int) -> Texture2D:
	if _library == null:
		_load_library()
	if _library == null:
		return null
	
	var model = _library.get_model(block_id)
	if model == null:
		return null
	
	var resource_name = model.resource_name
	return get_icon(resource_name)


## Создать иконку из атласа по UV-координатам
func _create_icon_from_atlas(block_name: String) -> Texture2D:
	# Сначала пробуем маппинг
	var texture_name = _block_to_texture_map.get(block_name, block_name)
	
	if _atlas_coords == null or _atlas_texture == null:
		return null
	
	var uv = _atlas_coords.get_uv(texture_name)
	if uv == Rect2(0, 0, 1, 1):
		# Пробуем найти по альтернативным именам
		uv = _find_uv_by_variants(texture_name)
		if uv == Rect2(0, 0, 1, 1):
			uv = _find_uv_by_variants(block_name)
			if uv == Rect2(0, 0, 1, 1):
				print("❌ Не найдены UV для блока: ", block_name)
				return null
	
	return _extract_texture_from_atlas(uv)


## Попробовать найти UV по вариантам имени блока
func _find_uv_by_variants(block_name: String) -> Rect2:
	# Возможные варианты имен
	var variants = [
		block_name,
		block_name.replace(" ", "_"),
		block_name.replace("_", " "),
	]
	
	for variant in variants:
		if _atlas_coords.coordinates.has(variant):
			return _atlas_coords.get_uv(variant)
	
	# Пробуем добавить типичные суффиксы
	var base_names = ["block_", ""]
	for base in base_names:
		for variant in variants:
			var test_name = base + variant
			if _atlas_coords.coordinates.has(test_name):
				return _atlas_coords.get_uv(test_name)
	
	return Rect2(0, 0, 1, 1)


## Извлечь текстуру из атласа по UV
func _extract_texture_from_atlas(uv: Rect2) -> Texture2D:
	var atlas_size = _atlas_texture.get_size()
	
	# Вычисляем пиксельные координаты
	var pixel_x = int(uv.position.x * atlas_size.x)
	var pixel_y = int(uv.position.y * atlas_size.y)
	var pixel_w = int(uv.size.x * atlas_size.x)
	var pixel_h = int(uv.size.y * atlas_size.y)
	
	# Создаём изображение
	var atlas_img = _atlas_texture.get_image()
	if atlas_img == null:
		# Пробуем загрузить
		var path = ATLAS_TEXTURE_PATH
		if FileAccess.file_exists(path):
			atlas_img = Image.load_from_file(path)
		else:
			return null
	
	# Вырезаем нужный фрагмент
	var icon_img = atlas_img.get_region(Rect2i(pixel_x, pixel_y, pixel_w, pixel_h))
	
	# НЕ масштабируем - сохраняем оригинальный размер из атласа
	
	# Создаём текстуру
	var texture = ImageTexture.create_from_image(icon_img)
	# Включаем фильтр Nearest для сохранения пикселей
	# (можно также настроить при импорте изображения)
	
	return texture


## Сгенерировать иконку из 3D-модели блока (альтернативный метод)
func generate_icon_from_model(block_id: int, viewport: SubViewport) -> Texture2D:
	if _library == null:
		_load_library()
	if _library == null:
		return null
	
	var model = _library.get_model(block_id)
	if model == null or model.mesh == null:
		return null
	
	# Здесь можно реализовать рендеринг 3D-модели во viewport
	# Но проще использовать атласный метод
	
	return get_icon_by_id(block_id)


## Сгенерировать все иконки блоков
func generate_all_icons() -> Dictionary:
	var result = {}
	
	# Пробуем загрузить библиотеку
	if _library == null:
		_load_library()
	
	if _library == null:
		print("❌ Библиотека не найдена")
		return result
	
	# Получаем все модели
	var models: Array = _library.models
	
	# Создаём папку для иконок, если её нет
	var folder_path = ICONS_FOLDER
	if not folder_path.begins_with("res://"):
		folder_path = "res://" + folder_path
	if not DirAccess.dir_exists_absolute(folder_path):
		DirAccess.make_dir_recursive_absolute(folder_path)
	
	for i in range(models.size()):
		var model = models[i]
		if model and model.resource_name != "air":
			var icon = get_icon(model.resource_name)
			if icon:
				result[model.resource_name] = icon
				# Сохраняем иконку в файл
				var file_name = model.resource_name.replace(" ", "_") + ".png"
				var file_path = ICONS_FOLDER + file_name
				save_icon(model.resource_name, file_path)
	
	print("✅ Сгенерировано иконок: ", result.size())
	return result


## Сохранить иконку в файл
func save_icon(block_name: String, path: String) -> bool:
	var icon = get_icon(block_name)
	if icon == null:
		return false
	
	var img = icon.get_image()
	if img:
		# Убедимся, что директория существует
		var dir_path = path.get_base_dir()
		if not dir_path.begins_with("res://"):
			dir_path = "res://" + dir_path
		if not DirAccess.dir_exists_absolute(dir_path):
			DirAccess.make_dir_recursive_absolute(dir_path)
		
		var error = img.save_png(path)
		if error == OK:
			print("✅ Сохранена иконка: ", path)
			return true
		else:
			print("❌ Ошибка сохранения иконки: ", error)
	return false


## Статический метод для быстрого доступа
static func get_block_icon(block_name: String) -> Texture2D:
	var instance = Engine.get_main_loop().root.get_node_or_null("/root/BlockIconGenerator")
	if instance:
		return instance.get_icon(block_name)
	
	# Создаём временный экземпляр
	var generator = BlockIconGenerator.new()
	generator._load_atlas()
	generator._load_library()
	var icon = generator.get_icon(block_name)
	generator.queue_free()
	return icon


static func get_block_icon_by_id(block_id: int) -> Texture2D:
	var instance = Engine.get_main_loop().root.get_node_or_null("/root/BlockIconGenerator")
	if instance:
		return instance.get_icon_by_id(block_id)
	
	var generator = BlockIconGenerator.new()
	generator._load_atlas()
	generator._load_library()
	var icon = generator.get_icon_by_id(block_id)
	generator.queue_free()
	return icon
