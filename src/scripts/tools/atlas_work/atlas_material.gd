@tool
extends Node
# Создает материалы из атласа для разных типов блоков

const AtlasLogger = preload("res://src/scripts/tools/atlas_work/atlas_logger.gd")
var log: AtlasLogger

@export var material_names: Dictionary = {
	"opaque": "block_material_opaque.tres",
	"transparent": "block_material_transparent.tres",
	"foliage": "block_material_foliage.tres"
}
@export var pixel_filter: bool = true  # NEAREST фильтр для пиксельных текстур
@export var auto_create: bool = true   # Создавать при запуске

# Константы для типов материалов
const MATERIAL_OPAQUE = "opaque"
const MATERIAL_TRANSPARENT = "transparent"
const MATERIAL_FOLIAGE = "foliage"

func _init():
	log = AtlasLogger.new("atlas_material_log.txt")

func _ready():
	if auto_create:
		call_deferred("create_all_materials")

func create_all_materials() -> Dictionary:
	"""Создает все три материала"""
	log.section("СОЗДАНИЕ МАТЕРИАЛОВ")
	
	var results = {}
	results[MATERIAL_OPAQUE] = create_opaque_material()
	results[MATERIAL_TRANSPARENT] = create_transparent_material()
	results[MATERIAL_FOLIAGE] = create_foliage_material()
	
	log.success("Все материалы созданы")
	return results

func create_opaque_material() -> StandardMaterial3D:
	"""Создает материал для непрозрачных блоков (камень, земля)"""
	log.section("НЕПРОЗРАЧНЫЙ МАТЕРИАЛ")
	return _create_base_material(MATERIAL_OPAQUE, {
		"transparency": BaseMaterial3D.TRANSPARENCY_DISABLED,  # 🔥 ИСПРАВЛЕНО
		"shading": BaseMaterial3D.SHADING_MODE_PER_PIXEL,
		"vertex_color": true,
		"params": {
			"albedo_color": Color(1, 1, 1, 1)
		}
	})

func create_transparent_material() -> StandardMaterial3D:
	"""Создает материал для прозрачных блоков (вода, стекло)"""
	log.section("ПРОЗРАЧНЫЙ МАТЕРИАЛ")
	return _create_base_material(MATERIAL_TRANSPARENT, {
		"transparency": BaseMaterial3D.TRANSPARENCY_ALPHA,  # 🔥 ИСПРАВЛЕНО
		"shading": BaseMaterial3D.SHADING_MODE_PER_PIXEL,
		"depth_draw": BaseMaterial3D.DEPTH_DRAW_ALWAYS,  # 🔥 ИСПРАВЛЕНО
		"params": {
			"albedo_color": Color(0.5, 0.7, 1.0, 0.8),
			"metallic": 0.0,
			"roughness": 0.1
		}
	})

func create_foliage_material() -> StandardMaterial3D:
	"""Создает материал для растительности (трава, листва)"""
	log.section("МАТЕРИАЛ РАСТИТЕЛЬНОСТИ")
	return _create_base_material(MATERIAL_FOLIAGE, {
		"transparency": BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR,  # 🔥 ИСПРАВЛЕНО (альфа-тест)
		"shading": BaseMaterial3D.SHADING_MODE_PER_PIXEL,  # Per-vertex в Godot 4 не реализован [citation:8]
		"vertex_color": true,
		"params": {
			"albedo_color": Color(0.3, 0.8, 0.3, 1),
			"roughness": 0.6,
			"metallic": 0.0
		}
	})

func _create_base_material(type: String, config: Dictionary) -> StandardMaterial3D:
	"""Базовое создание материала с общей логикой"""
	
	# Получаем путь к атласу
	var atlas_png = PathManager.game("res://src/assets/textures/atlas/block_atlas.png")
	
	log.write_line("📁 PNG атлас: " + atlas_png)
	
	# Проверяем существование файла
	if not FileAccess.file_exists(atlas_png):
		log.error("PNG атлас не найден! Путь: " + atlas_png)
		log.write_line("   Сначала запустите AtlasManager.build_atlas()")
		return null
	
	# Загружаем PNG как текстуру
	var img = Image.load_from_file(atlas_png)
	if not img:
		log.error("Не удалось загрузить PNG: " + atlas_png)
		return null
	
	var atlas_texture = ImageTexture.create_from_image(img)
	
	# Создаем материал
	var material = StandardMaterial3D.new()
	
	# Настройка фильтра
	if pixel_filter:
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		log.write_line("✅ Фильтр: NEAREST (пиксельный)")
	else:
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
		log.write_line("✅ Фильтр: LINEAR (сглаженный)")
	
	# Устанавливаем текстуру
	material.albedo_texture = atlas_texture
	
	# Настройки из конфига
	material.shading_mode = config.get("shading", BaseMaterial3D.SHADING_MODE_PER_PIXEL)
	material.vertex_color_use_as_albedo = config.get("vertex_color", false)
	
	# Настройка прозрачности
	if config.has("transparency"):
		material.transparency = config["transparency"]
	
	# Настройка depth draw mode
	if config.has("depth_draw"):
		material.depth_draw_mode = config["depth_draw"]
	
	# Устанавливаем дополнительные параметры
	for param in config.get("params", {}):
		var value = config["params"][param]
		match param:
			"albedo_color":
				material.albedo_color = value
			"metallic":
				material.metallic = value
			"roughness":
				material.roughness = value
			"emission":
				material.emission = value
	
	log.success("Материал создан")
	log.write_line("   Размер текстуры: " + str(atlas_texture.get_width()) + "x" + str(atlas_texture.get_height()))
	
	# Сохраняем материал
	var material_path = PathManager.game("src/assets/textures/atlas/" + material_names[type])
	var result = ResourceSaver.save(material, material_path)
	
	if result == OK:
		log.success("Материал сохранен: " + material_path)
	else:
		log.error("Ошибка сохранения материала! Код: " + str(result))
	
	return material

func get_material(type: String = MATERIAL_OPAQUE) -> StandardMaterial3D:
	"""Возвращает материал указанного типа"""
	if not material_names.has(type):
		log.error("Неизвестный тип материала: " + type)
		return null
	
	var material_path = PathManager.game("src/assets/textures/atlas/" + material_names[type])
	
	if ResourceLoader.exists(material_path):
		log.write_line("✅ Материал загружен из: " + material_path)
		return load(material_path)
	
	log.warning("Материал не найден, создаю новый...")
	return _create_base_material(type, _get_default_config(type))

func _get_default_config(type: String) -> Dictionary:
	"""Возвращает конфигурацию по умолчанию для типа материала"""
	match type:
		MATERIAL_OPAQUE:
			return {
				"transparency": BaseMaterial3D.TRANSPARENCY_DISABLED,
				"shading": BaseMaterial3D.SHADING_MODE_PER_PIXEL,
				"vertex_color": true,
				"params": {
					"albedo_color": Color(1, 1, 1, 1)
				}
			}
		MATERIAL_TRANSPARENT:
			return {
				"transparency": BaseMaterial3D.TRANSPARENCY_ALPHA,
				"shading": BaseMaterial3D.SHADING_MODE_PER_PIXEL,
				"depth_draw": BaseMaterial3D.DEPTH_DRAW_ALWAYS,  # 🔥 ИСПРАВЛЕНО
				"params": {
					"albedo_color": Color(0.5, 0.7, 1.0, 0.8),
					"metallic": 0.0,
					"roughness": 0.1
				}
			}
		MATERIAL_FOLIAGE:
			return {
				"transparency": BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR,
				"shading": BaseMaterial3D.SHADING_MODE_PER_PIXEL,
				"vertex_color": true,
				"params": {
					"albedo_color": Color(0.3, 0.8, 0.3, 1),
					"roughness": 0.6,
					"metallic": 0.0
				}
			}
		_:
			return {}

func update_all_materials() -> bool:
	"""Принудительно обновляет все материалы"""
	var success = true
	for type in material_names.keys():
		var new_material = _create_base_material(type, _get_default_config(type))
		if not new_material:
			success = false
	return success

# Статические методы для удобства

static func get_opaque() -> StandardMaterial3D:
	"""Возвращает непрозрачный материал"""
	var inst = Engine.get_main_loop().root.get_node_or_null("/root/AtlasMaterial")
	if inst:
		return inst.get_material(inst.MATERIAL_OPAQUE)
	return null

static func get_transparent() -> StandardMaterial3D:
	"""Возвращает прозрачный материал"""
	var inst = Engine.get_main_loop().root.get_node_or_null("/root/AtlasMaterial")
	if inst:
		return inst.get_material(inst.MATERIAL_TRANSPARENT)
	return null

static func get_foliage() -> StandardMaterial3D:
	"""Возвращает материал для растительности"""
	var inst = Engine.get_main_loop().root.get_node_or_null("/root/AtlasMaterial")
	if inst:
		return inst.get_material(inst.MATERIAL_FOLIAGE)
	return null

static func create_all() -> Dictionary:
	"""Статический метод для создания всех материалов"""
	var inst = Engine.get_main_loop().root.get_node_or_null("/root/AtlasMaterial")
	if inst:
		return inst.create_all_materials()
	return {}
