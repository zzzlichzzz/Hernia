extends Node
class_name BlockRegistry
# Реестр блоков - регистрирует блоки в VoxelBlockyLibrary

const AtlasMaterial = preload("res://src/scripts/tools/atlas_work/atlas_material.gd")
const BlockData = preload("res://src/scripts/resources/block_data.gd")

# Константы для типов материалов
const MATERIAL_OPAQUE = "opaque"

var blocks: Dictionary = {}  # имя -> BlockData
var blocks_by_id: Dictionary = {}  # id -> BlockData
var voxel_library: VoxelBlockyLibrary

# 🔥 Путь к библиотеке через PathManager (не константа)
var voxel_library_path: String = PathManager.smart("res://src/data/blocks/voxel_blocky_library.tres")

func _ready():
	print("📦 BlockRegistry: Инициализация...")
	_load_or_create_library()
	register_all_blocks()
	_finalize_library()

func _load_or_create_library():
	"""Загружает или создает библиотеку блоков"""
	if ResourceLoader.exists(voxel_library_path):
		voxel_library = load(voxel_library_path)
		print("✅ Библиотека загружена из: ", voxel_library_path)
	else:
		print("📁 Библиотека не найдена, создаю новую...")
		voxel_library = VoxelBlockyLibrary.new()

func _get_model_count() -> int:
	"""Возвращает количество моделей в библиотеке"""
	if not voxel_library or not "models" in voxel_library:
		return 0
	return voxel_library.models.size()

func register_all_blocks():
	"""Регистрирует все типы блоков"""
	print("\n📋 Регистрация блоков...")
	
	# Воздух (индекс 0) - обязателен
	_register_air()
	
	# 🔥 ТОЛЬКО DIRT (один блок)
	_register_block({
		"name": "dirt",
		"model_path": "res://src/assets/models/blocks/dirt.obj",
		"material_type": MATERIAL_OPAQUE,
		"transparent": false,
		"solid": true,
		"hardness": 0.5
	})
	
	print("\n✅ Всего блоков: ", blocks.size())

func _register_air():
	"""Регистрирует воздух (обязательно под индексом 0)"""
	var air_model = VoxelBlockyModelEmpty.new()
	air_model.resource_name = "air"
	
	if _get_model_count() == 0:
		voxel_library.models.append(air_model)
	else:
		voxel_library.models.insert(0, air_model)
	
	print("✅ Воздух зарегистрирован (ID: 0)")

func _register_block(params: Dictionary):
	"""Регистрирует обычный блок с моделью"""
	# Проверяем, не существует ли уже такой блок
	for existing in blocks.values():
		if existing.block_name == params.name:
			print("⚠️ Блок '", params.name, "' уже существует, пропускаю")
			return
	
	var block_data = BlockData.new()
	block_data.block_name = params.name
	block_data.transparent = params.get("transparent", false)
	block_data.solid = params.get("solid", true)
	block_data.hardness = params.get("hardness", 1.0)
	
	# Получаем материал
	var material = _get_material_by_type(params.material_type)
	
	# Создаем модель
	var model = VoxelBlockyModelMesh.new()
	model.resource_name = params.name
	
	# Загружаем mesh (через PathManager)
	var mesh_path = PathManager.smart(params.model_path)
	if ResourceLoader.exists(mesh_path):
		model.mesh = load(mesh_path)
		print("   ✅ Модель загружена: ", mesh_path)
	else:
		print("   ⚠️ Модель не найдена: ", mesh_path, " - создаю заглушку")
		var box = BoxMesh.new()
		box.size = Vector3(1, 1, 1)
		model.mesh = box
	
	# Назначаем материал на модель
	if material and model.mesh and model.mesh.get_surface_count() > 0:
		for surface_idx in range(model.mesh.get_surface_count()):
			model.mesh.surface_set_material(surface_idx, material)
		print("   ✅ Материал назначен: ", params.material_type)
	
	# Добавляем в библиотеку
	var model_id = voxel_library.models.size()
	voxel_library.models.append(model)
	
	# Сохраняем данные блока
	block_data.library_id = model_id
	blocks[params.name] = block_data
	blocks_by_id[model_id] = block_data
	
	print("✅ Блок '", params.name, "' зарегистрирован с ID: ", model_id)

func _get_material_by_type(type: String) -> StandardMaterial3D:
	"""Возвращает материал нужного типа из AtlasMaterial"""
	match type:
		MATERIAL_OPAQUE:
			return AtlasMaterial.get_opaque()
		_:
			return AtlasMaterial.get_opaque()

func _finalize_library():
	"""Запекает и сохраняет библиотеку"""
	if not voxel_library:
		push_error("❌ Библиотека не инициализирована!")
		return
	
	print("\n🔥 Запекание библиотеки...")
	voxel_library.bake()
	
	# 🔥 Сохраняем по пути, который уже содержит PathManager.smart()
	var result = ResourceSaver.save(voxel_library, voxel_library_path)
	
	if result == OK:
		print("✅ Библиотека сохранена в: ", voxel_library_path)
		_debug_print_summary()
	else:
		push_error("❌ Ошибка сохранения библиотеки! Код: ", result)

func _debug_print_summary():
	"""Выводит информацию о зарегистрированных блоках"""
	print("\n📊 **СОСТОЯНИЕ РЕЕСТРА**")
	print("   Всего блоков: ", blocks.size())
	print("   Моделей в библиотеке: ", _get_model_count())
	
	print("\n   **Блоки:**")
	for name in blocks.keys():
		var data = blocks[name]
		print("   - ", name, " -> ID: ", data.library_id)
	
	# Показываем все модели в библиотеке для проверки
	print("\n   **Модели в библиотеке:**")
	for i in range(_get_model_count()):
		var model = voxel_library.models[i]
		print("   [", i, "] ", model.resource_name)

# Публичные методы

func get_block_by_name(name: String) -> BlockData:
	return blocks.get(name)

func get_block_by_id(id: int) -> BlockData:
	return blocks_by_id.get(id)

func get_model_library() -> VoxelBlockyLibrary:
	return voxel_library

func get_model_id_by_name(name: String) -> int:
	var block = blocks.get(name)
	return block.library_id if block else -1
