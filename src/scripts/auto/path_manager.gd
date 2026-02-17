extends Node
# Глобальный менеджер путей с умными функциями

# Расширения, которые относятся к game (все остальные - к project)
@export var game_extensions: Array[String] = [
	"png", "jpg", "jpeg",  # Изображения
	"ogg", "mp3", "wav",   # Аудио
	"obj", "gltf", "glb",  # Модели
	"tres", "res",         # Ресурсы
]

var game_folder: String
var project_folder: String = "res://"

func _ready():
	# Определяем папку игры
	if Engine.is_editor_hint():
		game_folder = "user://"
	else:
		game_folder = OS.get_executable_path().get_base_dir().path_join("")
	
	print("📁 PathManager инициализирован")
	print("   Проект: ", project_folder)
	print("   Игра:   ", game_folder)
	print("   Game расширения: ", game_extensions)

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

# 🔥 УМНЫЙ ПУТЬ - game для указанных расширений, project для остальных

func smart(path: String) -> String:
	"""
	Умный выбор пути:
	- Если расширение в game_extensions → game
	- Иначе → project
	"""
	var ext = path.get_extension().to_lower()
	
	if ext in game_extensions:
		return game(path)
	else:
		return project(path)

# 🔥 СУПЕР-КОРОТКИЕ ВЕРСИИ

static func g(path: String) -> String:
	"""Короткая версия game()"""
	var inst = Engine.get_main_loop().root.get_node_or_null("/root/PathManager")
	return inst.game(path) if inst else ""

static func p(path: String) -> String:
	"""Короткая версия project()"""
	var inst = Engine.get_main_loop().root.get_node_or_null("/root/PathManager")
	return inst.project(path) if inst else ""

static func s(path: String) -> String:
	"""Короткая версия smart()"""
	var inst = Engine.get_main_loop().root.get_node_or_null("/root/PathManager")
	return inst.smart(path) if inst else ""
