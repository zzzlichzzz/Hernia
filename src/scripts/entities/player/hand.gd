extends Node3D

var mesh_instance: MeshInstance3D

# Библиотека блоков
var _library: VoxelBlockyLibrary = null

func _ready():
	# Находим MeshInstance3D в дочерних узлах
	mesh_instance = $MeshInstance3D
	
	# Загружаем библиотеку блоков
	_load_library()
	# Прячем руку по умолчанию
	if mesh_instance:
		mesh_instance.visible = false
	else:
		push_error("Hand: MeshInstance3D не найден!")

func _load_library():
	var library_path = "res://src/data/blocks/voxel_blocky_library.tres"
	if ResourceLoader.exists(library_path):
		_library = load(library_path) as VoxelBlockyLibrary
		if _library:
			print("Библиотека блоков загружена для руки")

func set_block(block_name: String, block_id: int = -1):
	if not mesh_instance:
		return
	
	# Если передан ID, используем его
	if block_id < 0 and _library:
		block_id = _library.get_model_index_from_resource_name(block_name)
	
	# Если есть библиотека, получаем модель
	if _library and block_id >= 0:
		var model = _library.get_model(block_id)
		if model:
			# Используем меш из модели
			if model.mesh:
				mesh_instance.mesh = model.mesh
			else:
				mesh_instance.mesh = BoxMesh.new()
			
			# Применяем материал
			var material = model.get_material_override(0)
			mesh_instance.material_override = material
			mesh_instance.visible = true
			return
	
	# Если модель не найдена, пробуем текстуру
	if block_name and block_name != "empty":
		# Создаём простой куб с текстурой
		mesh_instance.mesh = BoxMesh.new()
		
		var textures_dir = "res://src/assets/icons/blocks/"
		var path = textures_dir + block_name + ".png"
		if FileAccess.file_exists(path):
			var texture = load(path) as Texture2D
			if texture:
				var material = StandardMaterial3D.new()
				material.albedo_texture = texture
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mesh_instance.material_override = material
				mesh_instance.visible = true
				return
	
	# Если ничего не найдено, прячем руку
	mesh_instance.visible = false

func set_block_by_id(block_id: int):
	if not mesh_instance:
		return
	
	if _library and block_id >= 0:
		var model = _library.get_model(block_id)
		if model:
			if model.mesh:
				mesh_instance.mesh = model.mesh
			else:
				mesh_instance.mesh = BoxMesh.new()
			
			var material = model.get_material_override(0)
			mesh_instance.material_override = material
			mesh_instance.visible = true
			return
	
	mesh_instance.visible = false

func hide_hand():
	if mesh_instance:
		mesh_instance.visible = false
