@tool
extends Node
# Скрипт для создания ОДНОГО материала для всех блоков

# Настройки
@export var output_path: String = "res://src/assets/textures/atlas/"
@export var material_name: String = "block_material.tres"
@export var pixel_filter: bool = true

func get_master_material() -> StandardMaterial3D:
	"""Возвращает мастер-материал (загружает если есть)"""
	var material_path = output_path + material_name
	
	# Проверяем существует ли уже материал
	if ResourceLoader.exists(material_path):
		return load(material_path)
	
	# Если нет - создаем
	print("⚠️ Мастер-материал не найден, создаю...")
	return generate_master_material()

func generate_master_material() -> StandardMaterial3D:
	"""Создает мастер-материал"""
	print("\n🎨 Генерация мастер-материала...")
	
	# Загружаем ресурсы атласа
	var atlas_texture = load("res://src/assets/textures/atlas/block_atlas.tres")
	var atlas_coords = load("res://src/assets/textures/atlas/block_coordinates.tres")
	
	if not atlas_texture:
		print("❌ Не удалось загрузить block_atlas.tres")
		return null
	
	if not atlas_coords:
		print("❌ Не удалось загрузить block_coordinates.tres")
		return null
	
	print("✅ Ресурсы атласа загружены")
	
	# Создаем единый материал
	var material = StandardMaterial3D.new()
	
	# Настройка фильтра
	if pixel_filter:
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	else:
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	
	# Используем весь атлас как текстуру
	material.albedo_texture = atlas_texture
	
	# Дополнительные настройки
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	# Создаем папку если её нет
	DirAccess.make_dir_recursive_absolute(output_path)
	
	# Сохраняем материал
	var material_path = output_path + material_name
	var result = ResourceSaver.save(material, material_path)
	
	if result == OK:
		print("✅ Мастер-материал сохранен: ", material_path)
	else:
		print("❌ Ошибка сохранения материала. Код: ", result)
	
	return material
