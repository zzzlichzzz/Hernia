extends Node
class_name Block3DIconGenerator
## Генератор 3D иконок блоков для инвентаря
## Рендерит изометрический вид как в Minecraft:
## видны верхняя, левая и правая грани блока

const LIBRARY_PATH = "res://src/data/blocks/voxel_blocky_library.tres"
const ICONS_FOLDER = "res://src/assets/textures/gui/icons/blocks/"
const ICON_SIZE = 128

# ===== Углы камеры в стиле Minecraft =====
# Elevation 30° + Azimuth 45° дают классический изометрический вид
const CAMERA_ELEVATION_DEG = 30.0   # Наклон сверху (видна верхняя грань)
const CAMERA_AZIMUTH_DEG = 45.0     # Поворот сбоку (видны 2 боковые грани)
const CAMERA_DISTANCE = 5.0
const CAMERA_ORTHO_SIZE = 1.5       # Чем меньше — тем крупнее блок в иконке

# ===== Освещение =====
# Minecraft использует фиксированную яркость граней:
# Верх=1.0, Юг/Север=0.8, Восток/Запад=0.6, Низ=0.5
# Приближаем это ambient + directional светом сверху-сбоку
const AMBIENT_LIGHT_ENERGY = 0.45
const DIRECTIONAL_LIGHT_ENERGY = 0.75
const LIGHT_PITCH_DEG = -55.0       # Наклон света (сверху)
const LIGHT_YAW_DEG = -25.0         # Поворот света (чуть сбоку)

var _library: VoxelBlockyLibrary
var _viewport: SubViewport
var _camera: Camera3D
var _light: DirectionalLight3D
var _mesh_instance: MeshInstance3D
var _scene: Node3D


func _ready():
	_setup_viewport()


func _setup_viewport():
	# ── SubViewport с ПРОЗРАЧНЫМ фоном ──
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(ICON_SIZE, ICON_SIZE)
	_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_viewport.transparent_bg = true                    # <── КЛЮЧЕВОЕ: прозрачный фон
	add_child(_viewport)

	_scene = Node3D.new()
	_viewport.add_child(_scene)

	# ── Environment: ambient свет + линейный тонмаппинг ──
	var env = Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.background_color = Color(0, 0, 0, 0)          # Прозрачный
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = AMBIENT_LIGHT_ENERGY    # Базовое освещение всех граней
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR  # Без искажения цветов

	var world_env = WorldEnvironment.new()
	world_env.environment = env
	_scene.add_child(world_env)

	# ── Направленный свет сверху-сбоку ──
	# Создаёт разницу яркости между гранями (как в Minecraft)
	_light = DirectionalLight3D.new()
	_light.rotation_degrees = Vector3(LIGHT_PITCH_DEG, LIGHT_YAW_DEG, 0)
	_light.light_energy = DIRECTIONAL_LIGHT_ENERGY
	_light.shadow_enabled = false                      # Тени не нужны для иконок
	_scene.add_child(_light)

	# ── ОРТОГРАФИЧЕСКАЯ камера (как в Minecraft) ──
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL  # <── КЛЮЧЕВОЕ
	_camera.size = CAMERA_ORTHO_SIZE
	_camera.near = 0.01
	_camera.far = 20.0

	# Позиционируем камеру на сферических координатах
	var elev = deg_to_rad(CAMERA_ELEVATION_DEG)
	var azim = deg_to_rad(CAMERA_AZIMUTH_DEG)
	_camera.position = Vector3(
		CAMERA_DISTANCE * cos(elev) * sin(azim),       # X: сбоку
		CAMERA_DISTANCE * sin(elev),                    # Y: сверху
		CAMERA_DISTANCE * cos(elev) * cos(azim)         # Z: спереди
	)
	_camera.look_at_from_position(_camera.position, Vector3.ZERO, Vector3.UP)
	_scene.add_child(_camera)

	# ── MeshInstance для блока ──
	_mesh_instance = MeshInstance3D.new()
	_scene.add_child(_mesh_instance)

	_load_library()


func _load_library():
	if ResourceLoader.exists(LIBRARY_PATH):
		_library = load(LIBRARY_PATH) as VoxelBlockyLibrary
		if _library:
			print("✅ VoxelBlockyLibrary загружена для 3D иконок")
	else:
		print("❌ Библиотека не найдена: ", LIBRARY_PATH)


## Сгенерировать 3D иконку для блока по ID
func generate_3d_icon(block_id: int) -> Texture2D:
	if _library == null:
		_load_library()
	if _library == null:
		return null

	var model = _library.get_model(block_id)
	if model == null:
		return null

	return await _render_block(model)


## Сгенерировать 3D иконку для блока по имени
func generate_3d_icon_by_name(block_name: String) -> Texture2D:
	if _library == null:
		_load_library()
	if _library == null:
		return null

	var block_id = _library.get_model_index_from_resource_name(block_name)
	if block_id < 0:
		return null

	return await generate_3d_icon(block_id)


## Рендер блока в текстуру (изометрический вид Minecraft)
func _render_block(model: VoxelBlockyModel) -> Texture2D:
	# Устанавливаем меш
	if model.mesh:
		_mesh_instance.mesh = model.mesh
	else:
		_mesh_instance.mesh = BoxMesh.new()

	# Применяем материал (или сбрасываем если нет)
	var material = model.get_material_override(0)
	_mesh_instance.material_override = material        # null если нет — это нормально

	# Центрируем меш по AABB (блок может иметь смещённый origin)
	var aabb = _mesh_instance.mesh.get_aabb()
	_mesh_instance.position = -aabb.get_center()

	# Блок НЕ вращается — камера уже расположена под правильным углом
	_mesh_instance.rotation = Vector3.ZERO

	# Рендерим (2 кадра для надёжности)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame

	# Получаем изображение
	var img = _viewport.get_texture().get_image()
	if img:
		return ImageTexture.create_from_image(img)

	return null


## Сгенерировать все 3D иконки и сохранить на диск
func generate_all_3d_icons() -> Dictionary:
	var result = {}

	if _library == null:
		_load_library()
	if _library == null:
		print("❌ Библиотека не найдена")
		return result

	var models: Array = _library.models

	if not DirAccess.dir_exists_absolute(ICONS_FOLDER):
		DirAccess.make_dir_recursive_absolute(ICONS_FOLDER)

	for i in range(models.size()):
		var model = models[i]
		if model and model.resource_name != "air":
			var texture = await _render_block(model)
			if texture:
				result[model.resource_name] = texture
				var file_name = model.resource_name.replace(" ", "_") + ".png"
				_save_texture(texture, ICONS_FOLDER + file_name)

	print("✅ Сгенерировано 3D иконок: ", result.size())
	return result


## Сохранить текстуру в PNG
func _save_texture(texture: Texture2D, path: String):
	var img = texture.get_image()
	if img:
		var dir_path = path.get_base_dir()
		if not DirAccess.dir_exists_absolute(dir_path):
			DirAccess.make_dir_recursive_absolute(dir_path)

		var error = img.save_png(path)
		if error == OK:
			print("✅ Сохранена 3D иконка: ", path)


## Статические методы для быстрого доступа
static func get_3d_icon(block_id: int) -> Texture2D:
	var instance = Engine.get_main_loop().root.get_node_or_null("/root/Block3DIconGenerator")
	if instance:
		return await instance.generate_3d_icon(block_id)

	var generator = Block3DIconGenerator.new()
	var icon = await generator.generate_3d_icon(block_id)
	generator.queue_free()
	return icon


static func get_3d_icon_by_name(block_name: String) -> Texture2D:
	var instance = Engine.get_main_loop().root.get_node_or_null("/root/Block3DIconGenerator")
	if instance:
		return await instance.generate_3d_icon_by_name(block_name)

	var generator = Block3DIconGenerator.new()
	var icon = await generator.generate_3d_icon_by_name(block_name)
	generator.queue_free()
	return icon
