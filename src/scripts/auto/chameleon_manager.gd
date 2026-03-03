extends Node

# ═══════════════════════════════════════════════════════════
#  CHAMELEON MANAGER (RUNTIME)
#  Загружает данные от BlockRegistry и управляет покраской
# ═══════════════════════════════════════════════════════════

const CHAMELEON_JSON_PATH = "res://src/data/blocks/chameleon_data.json"
const LIBRARY_PATH = "res://src/data/blocks/voxel_blocky_library.tres"
const ATLAS_COORDS_PATH = "res://src/assets/textures/atlas/block_coordinates.tres"

@export var map_size: int = 4096
@export var max_probe: int = 8
@export var debug_mode: bool = true

# ─── Данные ───
var _keys_image: Image
var _data_image: Image
var _keys_texture: ImageTexture
var _data_texture: ImageTexture

# {Vector3i: Vector4(uv_offset.x, uv_offset.y, uv_size.x, uv_size.y)}
var _chameleon_positions: Dictionary = {}

var _atlas_coords: Resource = null

# Из JSON файла
var chameleon_voxel_ids: Array[int] = []      # ← массив
var block_id_to_texture: Dictionary = {}

# Ссылка на материал хамелеона из библиотеки
var _chameleon_material: ShaderMaterial = null

var _initialized: bool = false


func _ready():
	# Откладываем инициализацию — ждём пока всё загрузится
	call_deferred("_deferred_init")


func _deferred_init():
	_load_atlas_coords()
	_load_chameleon_json()
	_init_data_textures()
	_find_chameleon_material()
	_initialized = true
	if debug_mode:
		print("🔄 ChameleonManager инициализирован")
		print("   🔄 ID хамелеонов: ", chameleon_voxel_ids)
		print("   📋 Блоков в маппинге: ", block_id_to_texture.size())


# ═══════════════════════════════════════════════════════════
#  ЗАГРУЗКА
# ═══════════════════════════════════════════════════════════

func _load_atlas_coords():
	if ResourceLoader.exists(ATLAS_COORDS_PATH):
		_atlas_coords = load(ATLAS_COORDS_PATH)
		if debug_mode:
			print("   ✅ Координаты атласа загружены")
	else:
		push_error("ChameleonManager: Координаты атласа не найдены")


func _load_chameleon_json():
	if not FileAccess.file_exists(CHAMELEON_JSON_PATH):
		if debug_mode:
			print("   ⚠️ Файл chameleon_data.json не найден")
		return
	
	var file = FileAccess.open(CHAMELEON_JSON_PATH, FileAccess.READ)
	if file == null:
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_error("ChameleonManager: Ошибка парсинга JSON: " + json.get_error_message())
		return
	
	var data = json.data
	if data is Dictionary:
		# ═══ Поддержка и старого и нового формата ═══
		chameleon_voxel_ids.clear()
		
		if data.has("chameleon_voxel_ids"):
			# Новый формат — массив
			var ids = data["chameleon_voxel_ids"]
			if ids is Array:
				for id in ids:
					chameleon_voxel_ids.append(int(id))
		elif data.has("chameleon_voxel_id"):
			# Старый формат — одно значение (обратная совместимость)
			var old_id = int(data["chameleon_voxel_id"])
			if old_id >= 0:
				chameleon_voxel_ids.append(old_id)
		
		var mapping = data.get("block_id_to_texture", {})
		block_id_to_texture.clear()
		for key in mapping:
			block_id_to_texture[int(key)] = mapping[key]
		
		if debug_mode:
			print("   ✅ JSON загружен: chameleon_ids=", chameleon_voxel_ids,
				", блоков=", block_id_to_texture.size())


func _init_data_textures():
	_keys_image = Image.create(map_size, 1, false, Image.FORMAT_RGBAF)
	_data_image = Image.create(map_size, 1, false, Image.FORMAT_RGBAF)
	_keys_texture = ImageTexture.create_from_image(_keys_image)
	_data_texture = ImageTexture.create_from_image(_data_image)


func _find_chameleon_material():
	if chameleon_voxel_ids.is_empty():
		if debug_mode:
			print("   ⚠️ ID хамелеонов неизвестны, пропуск поиска материала")
		return
	
	if not ResourceLoader.exists(LIBRARY_PATH):
		if debug_mode:
			print("   ⚠️ Библиотека не найдена")
		return
	
	var lib = load(LIBRARY_PATH) as VoxelBlockyLibrary
	if lib == null:
		return
	
	var models = lib.get_models()
	
	# Ищем материал по первому хамелеону
	# (все хамелеоны используют один shared материал)
	for cham_id in chameleon_voxel_ids:
		if cham_id >= 0 and cham_id < models.size():
			var model = models[cham_id]
			if model is VoxelBlockyModelMesh:
				var mat = model.get_material_override(0)
				if mat is ShaderMaterial:
					_chameleon_material = mat
					_chameleon_material.set_shader_parameter("chameleon_keys", _keys_texture)
					_chameleon_material.set_shader_parameter("chameleon_data", _data_texture)
					if debug_mode:
						print("   ✅ Материал хамелеона найден (из ID: ", cham_id, ")")
					return
	
	if debug_mode:
		print("   ⚠️ Материал хамелеона не найден в библиотеке")


func connect_to_terrain(terrain: VoxelTerrain):
	if _chameleon_material != null:
		if debug_mode:
			print("   ✅ ChameleonManager: материал уже подключён")
		return
	
	var mesher = terrain.mesher
	if mesher is VoxelMesherBlocky:
		var lib = mesher.library
		if lib and not chameleon_voxel_ids.is_empty():
			var models = lib.get_models()
			for cham_id in chameleon_voxel_ids:
				if cham_id >= 0 and cham_id < models.size():
					var model = models[cham_id]
					if model is VoxelBlockyModelMesh:
						var mat = model.get_material_override(0)
						if mat is ShaderMaterial:
							_chameleon_material = mat
							_chameleon_material.set_shader_parameter("chameleon_keys", _keys_texture)
							_chameleon_material.set_shader_parameter("chameleon_data", _data_texture)
							if debug_mode:
								print("   ✅ Материал хамелеона подключён через terrain (ID: ", cham_id, ")")
							return


# ═══════════════════════════════════════════════════════════
#  ПУБЛИЧНОЕ API
# ═══════════════════════════════════════════════════════════

func is_chameleon_block(voxel_id: int) -> bool:
	return voxel_id in chameleon_voxel_ids


func paint_chameleon(pos: Vector3i, texture_name: String) -> bool:
	"""Покрасить хамелеон текстурой по имени"""
	var uv = _get_uv(texture_name)
	if uv.is_empty():
		if debug_mode:
			print("   ❌ Текстура не найдена в атласе: ", texture_name)
		return false
	
	var uv_data = Vector4(
		uv["left"], uv["top"],
		uv["right"] - uv["left"],
		uv["bottom"] - uv["top"]
	)
	_chameleon_positions[pos] = uv_data
	_rebuild_textures()
	
	if debug_mode:
		print("🎨 Хамелеон покрашен: ", pos, " → ", texture_name)
	return true


func paint_chameleon_by_block_id(pos: Vector3i, source_block_id: int) -> bool:
	"""Покрасить хамелеон текстурой блока по его voxel ID"""
	var tex_name = block_id_to_texture.get(source_block_id, "")
	if tex_name == "":
		if debug_mode:
			print("   ❌ Нет текстуры для блока ID: ", source_block_id)
		return false
	return paint_chameleon(pos, tex_name)


func remove_chameleon(pos: Vector3i):
	"""Удалить покраску (при разрушении блока)"""
	if _chameleon_positions.has(pos):
		_chameleon_positions.erase(pos)
		_rebuild_textures()
		if debug_mode:
			print("🔄 Хамелеон очищен: ", pos)


func is_chameleon_at(pos: Vector3i) -> bool:
	return _chameleon_positions.has(pos)


func get_chameleon_count() -> int:
	return _chameleon_positions.size()


# ═══════════════════════════════════════════════════════════
#  ХЕШИРОВАНИЕ (совпадает с шейдером!)
# ═══════════════════════════════════════════════════════════

func _hash_pos(x: int, y: int, z: int) -> int:
	var wx = ((x % 1024) + 1024) % 1024
	var wy = ((y % 1024) + 1024) % 1024
	var wz = ((z % 1024) + 1024) % 1024
	var h = wx * 73 + wy * 523 + wz * 997
	return h % map_size


# ═══════════════════════════════════════════════════════════
#  ОБНОВЛЕНИЕ ТЕКСТУР
# ═══════════════════════════════════════════════════════════

func _rebuild_textures():
	_keys_image = Image.create(map_size, 1, false, Image.FORMAT_RGBAF)
	_data_image = Image.create(map_size, 1, false, Image.FORMAT_RGBAF)
	
	var collisions = 0
	var failed = 0
	
	for pos in _chameleon_positions:
		var data: Vector4 = _chameleon_positions[pos]
		var hash_idx = _hash_pos(pos.x, pos.y, pos.z)
		
		var placed = false
		for i in range(max_probe):
			var idx = (hash_idx + i) % map_size
			var key = _keys_image.get_pixel(idx, 0)
			
			if key.a < 0.5:  # Пустой слот
				_keys_image.set_pixel(idx, 0,
					Color(float(pos.x), float(pos.y), float(pos.z), 1.0))
				_data_image.set_pixel(idx, 0,
					Color(data.x, data.y, data.z, data.w))
				placed = true
				if i > 0:
					collisions += 1
				break
		
		if not placed:
			failed += 1
			push_warning("ChameleonManager: Хеш-таблица переполнена для " + str(pos))
	
	# Загружаем на GPU
	_keys_texture.update(_keys_image)
	_data_texture.update(_data_image)
	
	# Обновляем материал
	if _chameleon_material:
		_chameleon_material.set_shader_parameter("chameleon_keys", _keys_texture)
		_chameleon_material.set_shader_parameter("chameleon_data", _data_texture)
	
	if debug_mode and (collisions > 0 or failed > 0):
		print("   📊 Хеш: коллизий=", collisions, " провалов=", failed)


func _get_uv(texture_name: String) -> Dictionary:
	if _atlas_coords == null:
		return {}
	var coords = _atlas_coords.coordinates.get(texture_name, null)
	if coords == null:
		return {}
	return coords["uv"]


# ═══════════════════════════════════════════════════════════
#  СОХРАНЕНИЕ / ЗАГРУЗКА СОСТОЯНИЯ МИРА
# ═══════════════════════════════════════════════════════════

func get_save_data() -> Dictionary:
	var data = {}
	for pos in _chameleon_positions:
		var key = "%d,%d,%d" % [pos.x, pos.y, pos.z]
		var v: Vector4 = _chameleon_positions[pos]
		data[key] = [v.x, v.y, v.z, v.w]
	return data


func load_save_data(data: Dictionary):
	_chameleon_positions.clear()
	for key in data:
		var parts = key.split(",")
		if parts.size() != 3:
			continue
		var pos = Vector3i(int(parts[0]), int(parts[1]), int(parts[2]))
		var v = data[key]
		if v is Array and v.size() == 4:
			_chameleon_positions[pos] = Vector4(v[0], v[1], v[2], v[3])
	_rebuild_textures()
	if debug_mode:
		print("🔄 Загружено хамелеонов: ", _chameleon_positions.size())
