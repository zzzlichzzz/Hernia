@tool
extends EditorScript

@export var block_library_path: String = "res://src/data/blocks/voxel_blocky_library.tres"
@export var atlas_coords_path: String = "res://src/assets/textures/atlas/block_coordinates.tres"

func _run():
	print("🎨 Применение текстур к библиотеке блоков...")
	
	var library = load(block_library_path)
	var atlas_coords = load(atlas_coords_path)
	
	if not library or not atlas_coords:
		print("❌ Не удалось загрузить ресурсы")
		return
	
	# Проходим по всем моделям в библиотеке
	for i in range(library.get_reference_count()):
		var model = library.get_model(i)
		if not model:
			continue
			
		# Ищем данные для этого блока в atlas_coords
		var block_name = model.resource_name
		if atlas_coords.coordinates.has(block_name):
			apply_texture_to_model(model, block_name, atlas_coords)
		else:
			print("⚠️ Нет текстуры для блока: ", block_name)
	
	# Сохраняем библиотеку
	ResourceSaver.save(library, block_library_path)
	print("✅ Текстуры применены и библиотека сохранена")

func apply_texture_to_model(model: VoxelBlockyModelMesh, block_name: String, atlas_coords):
	var data = atlas_coords.coordinates[block_name]
	
	# Создаем материал с текстурой из атласа
	var material = StandardMaterial3D.new()
	
	var atlas_tex = AtlasTexture.new()
	atlas_tex.atlas = atlas_coords.atlas_texture
	atlas_tex.region = Rect2(data.x, data.y, data.width, data.height)
	
	material.albedo_texture = atlas_tex
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	
	# Применяем материал к модели
	model.material = material
	
	print("  ✅ Текстура применена к: ", block_name)
