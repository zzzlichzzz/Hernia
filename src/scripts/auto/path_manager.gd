extends Node

static var game_folder: String
static var project_folder: String = "res://"

func _ready():
	game_folder = OS.get_executable_path().get_base_dir().path_join("")

func game(path: String) -> String:
	return game_folder.path_join(path.trim_prefix("res://"))

func project(path: String) -> String:
	return project_folder.path_join(path.trim_prefix("res://").trim_prefix("user://").trim_prefix(game_folder))
