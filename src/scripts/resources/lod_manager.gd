@tool
extends Node
class_name LODManager

# Синглтон для автоматического выбора LOD

var lod_levels: Array[Dictionary] = []
var camera: Camera3D = null
var update_interval: float = 0.1  # Обновление 10 раз в секунду
var time_since_update: float = 0.0

# Кэш для быстрого доступа
var lod_atlases: Dictionary = {}  # { factor: AtlasCoordinates }
var current_lod: AtlasCoordinates = null

func _ready():
	# Загружаем все LOD атласы
	load_lod_atlases()
	
	# Находим камеру
	await get_tree().process_frame
	find_camera()
	
	# Запускаем таймер обновления
	set_process(true)

func load_lod_atlases():
	var atlas_folder = "res://src/assets/textures/atlas/"
	
	# Загружаем оригинал
	var original = load(atlas_folder.path_join("block_coordinates.tres"))
	if original:
		lod_atlases[1] = original
		current_lod = original
	
	# Загружаем все LOD
	for factor in [2, 4, 8]:
		var path = atlas_folder.path_join("block_coordinates_lod_" + str(factor) + ".tres")
		if ResourceLoader.exists(path):
			lod_atlases[factor] = load(path)
			print("✅ Загружен LOD x" + str(factor))

func find_camera():
	camera = get_viewport().get_camera_3d()
	if not camera:
		# Если не нашли, ищем позже
		await get_tree().create_timer(0.5).timeout
		find_camera()

func _process(delta):
	time_since_update += delta
	
	# Обновляем LOD с заданной частотой
	if time_since_update >= update_interval:
		time_since_update = 0.0
		update_lod()

func update_lod():
	if not camera:
		find_camera()
		return
	
	# Определяем оптимальный LOD на основе расстояния
	var target_lod = calculate_optimal_lod()
	
	# Меняем LOD если нужно
	if current_lod != lod_atlases.get(target_lod, current_lod):
		current_lod = lod_atlases[target_lod]
		print("🔄 LOD изменён на x" + str(target_lod))

func calculate_optimal_lod() -> int:
	if not camera:
		return 1
	
	# Простая формула: чем дальше камера, тем выше LOD
	var distance = camera.global_position.length()
	
	if distance > 100:
		return 8
	elif distance > 50:
		return 4
	elif distance > 20:
		return 2
	else:
		return 1

# ПУБЛИЧНЫЕ МЕТОДЫ ДЛЯ БЛОКОВ

static func get_lod() -> AtlasCoordinates:
	var manager = Engine.get_main_loop().root.get_node_or_null("/root/LODManager")
	return manager.current_lod if manager else null

static func get_block_uv(block_name: String) -> Rect2:
	var lod = get_lod()
	if lod and lod.coordinates.has(block_name):
		var data = lod.coordinates[block_name]
		return Rect2(data.uv.left, data.uv.top,
					data.uv.right - data.uv.left,
					data.uv.bottom - data.uv.top)
	return Rect2(0, 0, 1, 1)

static func get_block_texture(block_name: String) -> AtlasTexture:
	var lod = get_lod()
	if lod and lod.coordinates.has(block_name):
		var data = lod.coordinates[block_name]
		var tex = AtlasTexture.new()
		tex.atlas = lod.atlas_texture
		tex.region = Rect2(data.x, data.y, data.width, data.height)
		return tex
	return null
