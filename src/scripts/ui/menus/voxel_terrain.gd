extends VoxelTerrain

const CONFIG_PATH := "user://voxel_settings.cfg"
var _settings_loaded: bool = false

func _ready():
	add_to_group("voxel_terrain")
	load_settings()

func load_settings():
	var config = ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		_apply_settings(256, true, false)
		_settings_loaded = true
		return

	var view_dist = config.get_value("voxel", "max_view_distance", max_view_distance)
	var collisions = config.get_value("voxel", "generate_collisions", generate_collisions)
	var gpu = config.get_value("voxel", "use_gpu_generation", use_gpu_generation)
	
	_apply_settings(view_dist, collisions, gpu)
	_settings_loaded = true

func _apply_settings(view_dist: int, collisions: bool, gpu: bool):
	max_view_distance = view_dist
	generate_collisions = collisions
	use_gpu_generation = gpu

func update_view_distance(new_distance: int):
	max_view_distance = new_distance
