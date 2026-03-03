@tool
extends Node
class_name BlockRegistry

var LIBRARY_PATH = "res://src/data/blocks/voxel_blocky_library.tres"
var BLOCKS_FOLDER = "res://src/data/blocks/definitions/"
var MODELS_FOLDER = "res://src/assets/blocks/"
const MESHER_PATH = "res://src/data/blocks/voxel_mesher_blocky.tres"

const ATLAS_COORDS_PATH = "res://src/assets/textures/atlas/block_coordinates.tres"
const MATERIAL_PATHS = {
	"opaque": "res://src/assets/textures/atlas/block_material_opaque.tres",
	"transparent": "res://src/assets/textures/atlas/block_material_transparent.tres",
	"foliage": "res://src/assets/textures/atlas/block_material_foliage.tres",
	"multi_face": "res://src/assets/textures/atlas/block_material_multi_face.tres"
}

@export var auto_build: bool = true
@export var debug_mode: bool = true

var library: VoxelBlockyLibrary
var block_count: int = 0
var mesher_manager: Node
# ═══ ХАМЕЛЕОН ═══
var _block_id_to_texture: Dictionary = {}
var _chameleon_voxel_ids: Array[int] = []     # ← МАССИВ вместо одного int
var _chameleon_defs: Array = []

const CHAMELEON_SHADER_PATH = "res://src/shaders/blocks/block_chameleon.gdshader"
const CHAMELEON_DATA_PATH = "res://src/data/blocks/chameleon_data.tres"

var _atlas_coords: Resource = null
var _base_materials: Dictionary = {}

func _ready():
	if Engine.is_editor_hint():
		if auto_build:
			call_deferred("_build_library")
	else:
		if auto_build:
			await get_tree().create_timer(1.0).timeout
			call_deferred("_build_library")
	
	_init_mesher_manager()

func _init_mesher_manager():
	if ResourceLoader.exists("res://src/data/blocks/mesher_manager_path.gd"):
		var MesherManagerClass = load("res://src/data/blocks/mesher_manager_path.gd")
		if MesherManagerClass:
			mesher_manager = MesherManagerClass.new()
			add_child(mesher_manager)
			if debug_mode:
				print("✅ MesherManagerPath инициализирован")
	else:
		if debug_mode:
			print("⚠️ MesherManagerPath не найден")

func _build_library():
	if debug_mode:
		print("🏗️ АВТОСБОРЩИК БИБЛИОТЕКИ БЛОКОВ")
		if Engine.is_editor_hint():
			print("📌 Режим: РЕДАКТОР")
	
	# Очищаем данные предыдущей сборки
	_block_id_to_texture.clear()
	_chameleon_voxel_ids.clear()          # ← было _chameleon_voxel_id = -1
	_chameleon_defs.clear()
	
	if debug_mode:
		print("\n📁 ШАГ 1: Создание новой библиотеки")
	library = VoxelBlockyLibrary.new()
	
	if debug_mode:
		print("\n🎨 ШАГ 1.5: Загрузка атласа и материалов")
	_load_atlas_and_materials()
	
	if debug_mode:
		print("\n🔍 ШАГ 2: Поиск определений блоков")
	var block_files = _find_block_definitions()
	if debug_mode:
		print("📁 Найдено определений: ", block_files.size())
	
	if debug_mode:
		print("\n🌬️ ШАГ 3: Добавление воздуха")
	_add_air()
	
	if debug_mode:
		print("\n🧱 ШАГ 4: Добавление блоков")
	for file_path in block_files:
		_process_block_definition(file_path)
	
	# ══════════════════════════════════════════
	#  НОВОЕ: Регистрация хамелеонов (после всех обычных блоков!)
	# ══════════════════════════════════════════
	if debug_mode:
		print("\n🔄 ШАГ 4.5: Регистрация хамелеон-блоков")
	_register_chameleon_blocks()
	# ══════════════════════════════════════════
	
	if debug_mode:
		print("\n🔥 ШАГ 5: Запекание библиотеки")
	library.bake()
	
	# ══════════════════════════════════════════
	#  НОВОЕ: Сохранение данных хамелеона
	# ══════════════════════════════════════════
	_save_chameleon_data()
	# ══════════════════════════════════════════
	
	if debug_mode:
		print("\n💾 ШАГ 6: Сохранение")
	
	var target_dir = LIBRARY_PATH.get_base_dir()
	if not DirAccess.dir_exists_absolute(target_dir):
		DirAccess.make_dir_recursive_absolute(target_dir)
	
	var result = ResourceSaver.save(library, LIBRARY_PATH)
	if result == OK:
		if debug_mode:
			print("✅ Библиотека сохранена: ", LIBRARY_PATH)
	else:
		print("❌ Ошибка сохранения: ", result)
		return
	
	if debug_mode:
		print("\n🔄 ШАГ 7: Обновление мешера")
	_update_mesher()
	
	if debug_mode:
		print("✅ СБОРКА ЗАВЕРШЕНА")
		print("📊 Всего блоков: ", block_count)


# ═══════════════════════════════════════════════════════════
#  ЗАГРУЗКА
# ═══════════════════════════════════════════════════════════

func _load_atlas_and_materials():
	if ResourceLoader.exists(ATLAS_COORDS_PATH):
		_atlas_coords = load(ATLAS_COORDS_PATH)
		if debug_mode:
			print("   ✅ Координаты атласа загружены")
	else:
		print("   ❌ Координаты атласа не найдены: ", ATLAS_COORDS_PATH)
	
	for type in MATERIAL_PATHS:
		var path = MATERIAL_PATHS[type]
		if ResourceLoader.exists(path):
			_base_materials[type] = load(path)
			if debug_mode:
				print("   ✅ Материал: ", type)
		else:
			if debug_mode:
				print("   ⚠️ Материал не найден: ", path)


# ═══════════════════════════════════════════════════════════
#  СОЗДАНИЕ МАТЕРИАЛОВ
# ═══════════════════════════════════════════════════════════

func _get_uv_for_texture(texture_name: String) -> Dictionary:
	"""Возвращает UV координаты текстуры из атласа"""
	if _atlas_coords == null:
		return {}
	var coords = _atlas_coords.coordinates.get(texture_name, null)
	if coords == null:
		print("   ❌ Текстура не найдена в атласе: ", texture_name)
		return {}
	return coords["uv"]


func _create_simple_material(material_type: String, texture_name: String) -> ShaderMaterial:
	"""Материал с одной текстурой на все грани"""
	var base_mat = _base_materials.get(material_type, _base_materials.get("opaque", null))
	if base_mat == null:
		return null
	
	var uv = _get_uv_for_texture(texture_name)
	if uv.is_empty():
		return null
	
	var mat = base_mat.duplicate() as ShaderMaterial
	mat.set_shader_parameter("block_uv_offset", Vector2(uv["left"], uv["top"]))
	mat.set_shader_parameter("block_uv_size", Vector2(
		uv["right"] - uv["left"],
		uv["bottom"] - uv["top"]
	))
	return mat


func _create_multi_face_material(def: BlockDefinition) -> ShaderMaterial:
	"""Материал с разными текстурами на гранях (шейдер определяет грань по нормали)"""
	var base_mat = _base_materials.get("multi_face", null)
	if base_mat == null:
		print("   ❌ Базовый материал multi_face не найден")
		return null
	
	var mat = base_mat.duplicate() as ShaderMaterial
	
	# Верхняя грань
	var top_name = def.texture_top if def.texture_top != "" else def.texture_name
	var top_uv = _get_uv_for_texture(top_name)
	if not top_uv.is_empty():
		mat.set_shader_parameter("top_uv_offset", Vector2(top_uv["left"], top_uv["top"]))
		mat.set_shader_parameter("top_uv_size", Vector2(
			top_uv["right"] - top_uv["left"],
			top_uv["bottom"] - top_uv["top"]
		))
	
	# Нижняя грань
	var bot_name = def.texture_bottom if def.texture_bottom != "" else def.texture_name
	var bot_uv = _get_uv_for_texture(bot_name)
	if not bot_uv.is_empty():
		mat.set_shader_parameter("bottom_uv_offset", Vector2(bot_uv["left"], bot_uv["top"]))
		mat.set_shader_parameter("bottom_uv_size", Vector2(
			bot_uv["right"] - bot_uv["left"],
			bot_uv["bottom"] - bot_uv["top"]
		))
	
	# Боковые грани (база)
	var side_name = def.texture_side if def.texture_side != "" else def.texture_name
	var side_uv = _get_uv_for_texture(side_name)
	if not side_uv.is_empty():
		mat.set_shader_parameter("side_uv_offset", Vector2(side_uv["left"], side_uv["top"]))
		mat.set_shader_parameter("side_uv_size", Vector2(
			side_uv["right"] - side_uv["left"],
			side_uv["bottom"] - side_uv["top"]
		))
	
	# Оверлей на боках (опционально)
	if def.has_side_overlay():
		var over_uv = _get_uv_for_texture(def.texture_side_overlay)
		if not over_uv.is_empty():
			mat.set_shader_parameter("overlay_uv_offset", Vector2(over_uv["left"], over_uv["top"]))
			mat.set_shader_parameter("overlay_uv_size", Vector2(
				over_uv["right"] - over_uv["left"],
				over_uv["bottom"] - over_uv["top"]
			))
			mat.set_shader_parameter("overlay_enabled", true)
			if debug_mode:
				print("   🌿 Оверлей включён: ", def.texture_side_overlay)
	
	if debug_mode:
		print("   🔝 Верх: ", top_name)
		print("   🔽 Низ: ", bot_name)
		print("   ◻️ Бока: ", side_name)
	
	return mat


# ═══════════════════════════════════════════════════════════
#  ОБРАБОТКА БЛОКА
# ═══════════════════════════════════════════════════════════

func _process_block_definition(file_path: String):
	if debug_mode:
		print("\n🔧 Обработка: ", file_path.get_file())
	
	if not FileAccess.file_exists(file_path):
		return
	
	var def_resource = load(file_path)
	if not def_resource or not def_resource is BlockDefinition:
		if debug_mode:
			print("   ❌ Неверный формат: ", file_path)
		return
	
	var def: BlockDefinition = def_resource
	
		# Синхронизация material_type
	match def.material_type_enum:
		BlockDefinition.MaterialType.OPAQUE:
			def.material_type = "opaque"
		BlockDefinition.MaterialType.TRANSPARENT:
			def.material_type = "transparent"
		BlockDefinition.MaterialType.FOLIAGE:
			def.material_type = "foliage"
		BlockDefinition.MaterialType.MULTI_FACE:
			def.material_type = "multi_face"
		BlockDefinition.MaterialType.CHAMELEON:
			def.material_type = "chameleon"
			def.is_chameleon = true
	
	# Хамелеон — откладываем
	if def.is_chameleon:
		_chameleon_defs.append(def)
		if debug_mode:
			print("   🔄 Хамелеон отложен: ", def.block_name)
		return
	# ══════════════════════════════════════════
	
	if debug_mode:
		print("   📦 Блок: ", def.block_name)
		print("   🎨 Материал: ", def.material_type)
	
	if def.model == null:
		if debug_mode:
			print("   ⚠️ Модель не указана, пропуск")
		return
	
	if debug_mode:
		print("   📐 Меш (surfaces: ", def.model.get_surface_count(), ")")
	
	var model = VoxelBlockyModelMesh.new()
	model.resource_name = def.block_name
	model.mesh = def.model
	model.culls_neighbors = def.culls_neighbors
	model.transparency_index = def.transparency_index
	model.collision_aabbs = def.collision_aabbs
	model.set("collision_enabled_0", def.collision_enabled)
	
	var mat: ShaderMaterial = null
	if def.material_type == "multi_face" or def.has_per_face_textures():
		mat = _create_multi_face_material(def)
	else:
		mat = _create_simple_material(def.material_type, def.texture_name)
	
	if mat:
		model.set_material_override(0, mat)
		if debug_mode:
			print("   ✅ Материал применён к surface 0")
	
	var id = library.add_model(model)
	if debug_mode:
		print("   ✅ Блок добавлен с ID: ", id)
	block_count += 1
	
	# ══════════════════════════════════════════
	#  Запоминаем текстуру для маппинга
	# ══════════════════════════════════════════
	var primary_tex = def.texture_name
	if primary_tex == "":
		if def.texture_side != "":
			primary_tex = def.texture_side
		elif def.texture_top != "":
			primary_tex = def.texture_top
	if primary_tex != "":
		_block_id_to_texture[id] = primary_tex
	# ══════════════════════════════════════════


# ═══════════════════════════════════════════════════════════
#  ОСТАЛЬНОЕ
# ═══════════════════════════════════════════════════════════

func _find_block_definitions() -> Array:
	var files = []
	var dir = DirAccess.open(BLOCKS_FOLDER)
	if not dir:
		return files
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres") and file_name != "block_definition.gd":
			files.append(BLOCKS_FOLDER + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	return files

func _add_air():
	var air_model = VoxelBlockyModelEmpty.new()
	air_model.resource_name = "air"
	var id = library.add_model(air_model)
	if debug_mode:
		print("   ✅ Воздух добавлен с ID: ", id)
	block_count += 1

func _update_mesher():
	if mesher_manager and mesher_manager.has_method("_update_mesher"):
		mesher_manager._update_mesher()
		if debug_mode:
			print("✅ Мешер обновлен")
	else:
		if debug_mode:
			print("⚠️ Не удалось обновить мешер")

static func build():
	var instance = Engine.get_main_loop().root.get_node_or_null("/root/BlockRegistry")
	if instance:
		instance._build_library()
	else:
		print("❌ BlockRegistry не найден")

static func get_library() -> VoxelBlockyLibrary:
	var instance = Engine.get_main_loop().root.get_node_or_null("/root/BlockRegistry")
	if instance:
		return instance.library
	return null

static func get_block_id(block_name: String) -> int:
	var instance = Engine.get_main_loop().root.get_node_or_null("/root/BlockRegistry")
	if instance and instance.library:
		return instance.library.get_model_index_from_resource_name(block_name)
	return -1

# ═══════════════════════════════════════════════════════════
#  ХАМЕЛЕОН — СБОРКА (без ChameleonManager!)
# ═══════════════════════════════════════════════════════════

func _register_chameleon_blocks():
	if _chameleon_defs.is_empty():
		if debug_mode:
			print("   ℹ️ Хамелеон-блоки не найдены")
		return
	
	var chameleon_shader: Shader = null
	if ResourceLoader.exists(CHAMELEON_SHADER_PATH):
		chameleon_shader = load(CHAMELEON_SHADER_PATH)
	else:
		print("   ❌ Шейдер хамелеона не найден: ", CHAMELEON_SHADER_PATH)
		return
	
	var atlas_texture: Texture2D = null
	if _atlas_coords and _atlas_coords.atlas_texture:
		atlas_texture = _atlas_coords.atlas_texture
	else:
		var atlas_path = "res://src/assets/textures/atlas/block_atlas.png"
		if ResourceLoader.exists(atlas_path):
			atlas_texture = load(atlas_path)
	
	if atlas_texture == null:
		print("   ❌ Текстура атласа не найдена")
		return
	
	# ═══ ОБЩИЙ материал для ВСЕХ хамелеонов ═══
	# Все хамелеоны используют один и тот же ShaderMaterial,
	# чтобы data-текстуры были общими
	var shared_material: ShaderMaterial = null
	
	for cham_def in _chameleon_defs:
		if debug_mode:
			print("\n   🔄 Регистрация хамелеона: ", cham_def.block_name)
		
		if cham_def.model == null:
			print("   ❌ У хамелеона нет модели!")
			continue
		
		var model = VoxelBlockyModelMesh.new()
		model.resource_name = cham_def.block_name
		model.mesh = cham_def.model
		model.culls_neighbors = cham_def.culls_neighbors
		model.transparency_index = cham_def.transparency_index
		model.collision_aabbs = cham_def.collision_aabbs
		model.set("collision_enabled_0", cham_def.collision_enabled)
		
		# Создаём материал только один раз, потом переиспользуем
		if shared_material == null:
			shared_material = _create_chameleon_material(
				chameleon_shader, atlas_texture, cham_def.texture_name)
		
		if shared_material:
			model.set_material_override(0, shared_material)
			if debug_mode:
				print("   ✅ Шейдер хамелеона применён")
		
		var id = library.add_model(model)
		_chameleon_voxel_ids.append(id)       # ← добавляем в массив
		block_count += 1
		
		if debug_mode:
			print("   ✅ Хамелеон добавлен с ID: ", id)
	
	if debug_mode:
		print("\n   📊 Всего хамелеонов: ", _chameleon_voxel_ids.size())
		print("   📋 ID хамелеонов: ", _chameleon_voxel_ids)


func _create_chameleon_material(shader: Shader, atlas: Texture2D, default_texture: String) -> ShaderMaterial:
	"""Создаёт ShaderMaterial для хамелеона с пустыми data-текстурами"""
	var mat = ShaderMaterial.new()
	mat.shader = shader
	
	# Атлас
	mat.set_shader_parameter("atlas_texture", atlas)
	
	# Пустые data-текстуры (ChameleonManager заполнит их в рантайме)
	var empty_keys = Image.create(4096, 1, false, Image.FORMAT_RGBAF)
	var empty_data = Image.create(4096, 1, false, Image.FORMAT_RGBAF)
	mat.set_shader_parameter("chameleon_keys", ImageTexture.create_from_image(empty_keys))
	mat.set_shader_parameter("chameleon_data", ImageTexture.create_from_image(empty_data))
	mat.set_shader_parameter("chameleon_map_size", 4096)
	
	# Дефолтные UV
	var uv = _get_uv_for_texture(default_texture)
	if not uv.is_empty():
		mat.set_shader_parameter("default_uv_offset", Vector2(uv["left"], uv["top"]))
		mat.set_shader_parameter("default_uv_size", Vector2(
			uv["right"] - uv["left"],
			uv["bottom"] - uv["top"]
		))
		if debug_mode:
			print("   🎨 Дефолт текстура: ", default_texture)
	else:
		mat.set_shader_parameter("default_uv_offset", Vector2(0, 0))
		mat.set_shader_parameter("default_uv_size", Vector2(1, 1))
	
	return mat


func _save_chameleon_data():
	var json_path = "res://src/data/blocks/chameleon_data.json"
	var dir = json_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	
	var file = FileAccess.open(json_path, FileAccess.WRITE)
	if file:
		var save_mapping = {}
		for id in _block_id_to_texture:
			save_mapping[str(id)] = _block_id_to_texture[id]
		
		# ═══ Сохраняем массив ID ═══
		var save_data = {
			"chameleon_voxel_ids": _chameleon_voxel_ids,    # ← массив
			"block_id_to_texture": save_mapping
		}
		file.store_string(JSON.stringify(save_data, "\t"))
		file.close()
		if debug_mode:
			print("   💾 Данные хамелеона сохранены: ", json_path)
			print("   📋 Блоков в маппинге: ", _block_id_to_texture.size())
			print("   🔄 ID хамелеонов: ", _chameleon_voxel_ids)
	else:
		print("   ❌ Не удалось сохранить данные хамелеона")
