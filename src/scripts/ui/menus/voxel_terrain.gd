extends VoxelTerrain

# Путь к файлу конфигурации (должен совпадать с путём в меню настроек)
const CONFIG_PATH := "user://voxel_settings.cfg"

func _ready():
	# Добавляем в группу для доступа из настроек
	add_to_group("voxel_terrain")
	load_settings()

func load_settings():
	var config = ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		print("Файл настроек не найден, используются значения по умолчанию.")
		return

	# Применяем сохранённые значения к свойствам VoxelTerrain
	max_view_distance = config.get_value("voxel", "max_view_distance", max_view_distance)
	generate_collisions = config.get_value("voxel", "generate_collisions", generate_collisions)
	use_gpu_generation = config.get_value("voxel", "use_gpu_generation", use_gpu_generation)

	print("Настройки VoxelTerrain загружены: view_distance=", max_view_distance, 
		  ", collisions=", generate_collisions, 
		  ", gpu=", use_gpu_generation)
