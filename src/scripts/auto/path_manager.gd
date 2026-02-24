extends Node

static var game_folder: String
static var project_folder: String = "res://"

func _ready():
	game_folder = OS.get_executable_path().get_base_dir().path_join("")
	
	print("📁 PathManager инициализирован")
	print("   Проект: ", project_folder)
	print("   Игра:   ", game_folder)

# 🔥 ОСНОВНЫЕ ФУНКЦИИ

func game(path: String) -> String:
	"""
	Путь к файлу в папке игры.
	Автоматически удаляет 'res://' если есть.
	"""
	var clean_path = path.trim_prefix("res://")
	return game_folder.path_join(clean_path)

func project(path: String) -> String:
	"""
	Путь к файлу в папке проекта.
	Автоматически удаляет лишние префиксы.
	"""
	var clean_path = path.trim_prefix("res://").trim_prefix("user://").trim_prefix(game_folder)
	return project_folder.path_join(clean_path)
