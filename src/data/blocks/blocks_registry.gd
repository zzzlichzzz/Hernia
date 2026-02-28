@tool
extends Node

var LIBRARY_PATH = "res://src/data/blocks/voxel_blocky_library.tres"
var BLOCKS_FOLDER = "res://src/data/blocks/definitions/"
var MODELS_FOLDER = "res://src/assets/blocks/"
const MESHER_PATH = "res://src/data/blocks/voxel_mesher_blocky.tres"
const SLAB_DATA_PATH = "res://src/data/blocks/slab_data.tres"

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

var _atlas_coords: Resource = null
var _base_materials: Dictionary = {}

# ═══ РЕЕСТР ПОЛУБЛОКОВ ═══
var slab_registry: Dictionary = {}
# { "stone_slab": { "bottom_id": 4, "top_id": 5, "full_block_name": "stone" } }

var slab_id_map: Dictionary = {}
# { 4: { "name": "stone_slab", "variant": "bottom" },
#   5: { "name": "stone_slab", "variant": "top" } }


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
	
	library = VoxelBlockyLibrary.new()
	slab_registry.clear()
	slab_id_map.clear()
	block_count = 0
	
	if debug_mode:
		print("\n🎨 Загрузка атласа и материалов")
	_load_atlas_and_materials()
	
	if debug_mode:
		print("\n🔍 Поиск определений блоков")
	var block_files = _find_block_definitions()
	if debug_mode:
		print("📁 Найдено определений: ", block_files.size())
	
	if debug_mode:
		print("\n🌬️ Добавление воздуха")
	_add_air()
	
	if debug_mode:
		print("\n🧱 Добавление блоков")
	for file_path in block_files:
		_process_block_definition(file_path)
	
	# ═══ Разрешение ID полных блоков для полублоков ═══
	if debug_mode:
		print("\n🔗 Разрешение ID полных блоков для полублоков")
	_resolve_slab_full_ids()
	
	if debug_mode:
		print("\n🔥 Запекание библиотеки")
	library.bake()
	
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
	
	_update_mesher()
	
	if debug_mode:
		print("\n✅ СБОРКА ЗАВЕРШЕНА")
		print("📊 Всего блоков: ", block_count)
		if slab_registry.size() > 0:
			print("📊 Полублоков: ", slab_registry.size())
			for slab_name in slab_registry:
				var info = slab_registry[slab_name]
				print("   ", slab_name, ": bottom=", info["bottom_id"],
					  " top=", info["top_id"],
					  " full=", info.get("full_id", -1))


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
	if _atlas_coords == null:
		return {}
	var coords = _atlas_coords.coordinates.get(texture_name, null)
	if coords == null:
		print("   ❌ Текстура не найдена в атласе: ", texture_name)
		return {}
	return coords["uv"]


func _create_simple_material(material_type: String, texture_name: String) -> ShaderMaterial:
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
	var base_mat = _base_materials.get("multi_face", null)
	if base_mat == null:
		return null
	
	var mat = base_mat.duplicate() as ShaderMaterial
	
	var top_name = def.texture_top if def.texture_top != "" else def.texture_name
	var top_uv = _get_uv_for_texture(top_name)
	if not top_uv.is_empty():
		mat.set_shader_parameter("top_uv_offset", Vector2(top_uv["left"], top_uv["top"]))
		mat.set_shader_parameter("top_uv_size", Vector2(
			top_uv["right"] - top_uv["left"], top_uv["bottom"] - top_uv["top"]))
	
	var bot_name = def.texture_bottom if def.texture_bottom != "" else def.texture_name
	var bot_uv = _get_uv_for_texture(bot_name)
	if not bot_uv.is_empty():
		mat.set_shader_parameter("bottom_uv_offset", Vector2(bot_uv["left"], bot_uv["top"]))
		mat.set_shader_parameter("bottom_uv_size", Vector2(
			bot_uv["right"] - bot_uv["left"], bot_uv["bottom"] - bot_uv["top"]))
	
	var side_name = def.texture_side if def.texture_side != "" else def.texture_name
	var side_uv = _get_uv_for_texture(side_name)
	if not side_uv.is_empty():
		mat.set_shader_parameter("side_uv_offset", Vector2(side_uv["left"], side_uv["top"]))
		mat.set_shader_parameter("side_uv_size", Vector2(
			side_uv["right"] - side_uv["left"], side_uv["bottom"] - side_uv["top"]))
	
	if def.has_side_overlay():
		var over_uv = _get_uv_for_texture(def.texture_side_overlay)
		if not over_uv.is_empty():
			mat.set_shader_parameter("overlay_uv_offset", Vector2(over_uv["left"], over_uv["top"]))
			mat.set_shader_parameter("overlay_uv_size", Vector2(
				over_uv["right"] - over_uv["left"], over_uv["bottom"] - over_uv["top"]))
			mat.set_shader_parameter("overlay_enabled", true)
	
	return mat


# ═══════════════════════════════════════════════════════════
#  ПРИМЕНЕНИЕ МАТЕРИАЛА К МОДЕЛИ
# ═══════════════════════════════════════════════════════════

func _apply_material_to_model(model: VoxelBlockyModelMesh, def: BlockDefinition):
	var mat: ShaderMaterial = null
	
	if def.material_type == "multi_face" or def.has_per_face_textures():
		mat = _create_multi_face_material(def)
	else:
		mat = _create_simple_material(def.material_type, def.texture_name)
	
	if mat:
		model.set_material_override(0, mat)


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
	
	if debug_mode:
		print("   📦 Блок: ", def.block_name)
		print("   🎨 Материал: ", def.material_type)
	
	if def.model == null:
		if debug_mode:
			print("   ⚠️ Модель не указана, пропуск")
		return
	
	# ═══ ПОЛУБЛОКИ ═══
	if def.is_slab:
		_process_slab_definition(def)
		return
	
	# ═══ ОБЫЧНЫЙ БЛОК ═══
	var model = VoxelBlockyModelMesh.new()
	model.resource_name = def.block_name
	model.mesh = def.model
	model.culls_neighbors = def.culls_neighbors
	model.transparency_index = def.transparency_index
	model.collision_aabbs = def.collision_aabbs
	model.set("collision_enabled_0", def.collision_enabled)
	
	_apply_material_to_model(model, def)
	
	var id = library.add_model(model)
	if debug_mode:
		print("   ✅ Блок добавлен с ID: ", id)
	block_count += 1


# ═══════════════════════════════════════════════════════════
#  ОБРАБОТКА ПОЛУБЛОКОВ
# ═══════════════════════════════════════════════════════════

func _process_slab_definition(def: BlockDefinition):
	if debug_mode:
		print("   🔲 Полублок: ", def.block_name)
	
	if def.model == null:
		if debug_mode:
			print("   ❌ Модель нижнего полублока не указана")
		return
	
	if def.slab_model_top == null:
		if debug_mode:
			print("   ❌ Модель верхнего полублока не указана (slab_model_top)")
		return
	
	# ─── Нижний полублок ───
	var bottom_model = VoxelBlockyModelMesh.new()
	bottom_model.resource_name = def.block_name + "_bottom"
	bottom_model.mesh = def.model
	bottom_model.culls_neighbors = false
	bottom_model.transparency_index = 1
	bottom_model.collision_aabbs = [AABB(Vector3(0, 0, 0), Vector3(1, 0.5, 1))]
	bottom_model.set("collision_enabled_0", true)
	
	_apply_material_to_model(bottom_model, def)
	
	var bottom_id = library.add_model(bottom_model)
	block_count += 1
	
	if debug_mode:
		print("   🔽 Нижний полублок ID: ", bottom_id)
	
	# ─── Верхний полублок ───
	var top_model = VoxelBlockyModelMesh.new()
	top_model.resource_name = def.block_name + "_top"
	top_model.mesh = def.slab_model_top
	top_model.culls_neighbors = false
	top_model.transparency_index = 1
	top_model.collision_aabbs = [AABB(Vector3(0, 0.5, 0), Vector3(1, 0.5, 1))]
	top_model.set("collision_enabled_0", true)
	
	_apply_material_to_model(top_model, def)
	
	var top_id = library.add_model(top_model)
	block_count += 1
	
	if debug_mode:
		print("   🔼 Верхний полублок ID: ", top_id)
	
	# ─── Сохраняем в реестр ───
	slab_registry[def.block_name] = {
		"bottom_id": bottom_id,
		"top_id": top_id,
		"full_block_name": def.full_block_name
	}
	
	slab_id_map[bottom_id] = {"name": def.block_name, "variant": "bottom"}
	slab_id_map[top_id] = {"name": def.block_name, "variant": "top"}
	
	if debug_mode:
		print("   ✅ Полублок зарегистрирован: ", def.block_name)


func _resolve_slab_full_ids():
	"""После регистрации всех блоков, находим ID полных блоков для объединения"""
	for slab_name in slab_registry:
		var info = slab_registry[slab_name]
		var full_name = info["full_block_name"]
		
		if full_name == "":
			info["full_id"] = -1
			if debug_mode:
				print("   ⚠️ ", slab_name, ": полный блок не указан, объединение отключено")
			continue
		
		var full_id = library.get_model_index_from_resource_name(full_name)
		info["full_id"] = full_id
		
		if debug_mode:
			if full_id >= 0:
				print("   🔗 ", slab_name, " → ", full_name, " (ID: ", full_id, ")")
			else:
				print("   ❌ ", slab_name, " → ", full_name, " НЕ НАЙДЕН!")


# ═══════════════════════════════════════════════════════════
#  ПУБЛИЧНЫЕ МЕТОДЫ ДЛЯ ПОЛУБЛОКОВ
# ═══════════════════════════════════════════════════════════
func _save_slab_data():
	"""Сохраняет данные полублоков в ресурс для использования в игре"""
	var data = SlabData.new()
	
	# Конвертируем ключи в строки (ResourceSaver требует)
	var registry_copy = {}
	for key in slab_registry:
		registry_copy[str(key)] = slab_registry[key]
	
	var id_map_copy = {}
	for key in slab_id_map:
		id_map_copy[str(key)] = slab_id_map[key]
	
	data.slab_registry = registry_copy
	data.slab_id_map = id_map_copy
	
	var result = ResourceSaver.save(data, SLAB_DATA_PATH)
	if result == OK:
		if debug_mode:
			print("✅ Данные полублоков сохранены: ", SLAB_DATA_PATH)
			print("   Полублоков: ", slab_registry.size())
			for slab_name in slab_registry:
				var info = slab_registry[slab_name]
				print("   ", slab_name, ": bottom=", info["bottom_id"],
					  " top=", info["top_id"], " full=", info.get("full_id", -1))
	else:
		print("❌ Ошибка сохранения slab_data: ", result)

func is_slab_id(voxel_id: int) -> bool:
	"""Проверяет, является ли ID полублоком"""
	return slab_id_map.has(voxel_id)

func get_slab_info_by_id(voxel_id: int) -> Dictionary:
	"""Получает информацию о полублоке по его voxel ID"""
	if not slab_id_map.has(voxel_id):
		return {}
	var map_info = slab_id_map[voxel_id]
	var full_info = slab_registry.get(map_info["name"], {})
	return {
		"name": map_info["name"],
		"variant": map_info["variant"],
		"bottom_id": full_info.get("bottom_id", -1),
		"top_id": full_info.get("top_id", -1),
		"full_id": full_info.get("full_id", -1)
	}

func get_slab_ids(slab_name: String) -> Dictionary:
	"""Получает все ID полублока по имени"""
	return slab_registry.get(slab_name, {})


# ═══════════════════════════════════════════════════════════
#  ОСТАЛЬНОЕ (без изменений)
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
#  МЕТОДЫ ДЛЯ PLAYER_INTERACTION
# ═══════════════════════════════════════════════════════════

func get_block_id_by_name(block_name: String) -> int:
	"""Получает ID блока по имени (instance метод)"""
	if library == null:
		return -1
	return library.get_model_index_from_resource_name(block_name)

func get_block_name_by_id(block_id: int) -> String:
	"""Получает имя блока по ID"""
	if library == null:
		return ""
	
	# Проверяем полублоки
	if slab_id_map.has(block_id):
		return slab_id_map[block_id]["name"]
	
	# Перебираем все модели
	var count = library.get_model_count()
	for i in range(count):
		var model = library.get_model(i)
		if model and model.resource_name != "" and i == block_id:
			return model.resource_name
	
	return ""
