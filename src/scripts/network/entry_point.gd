extends Node
## Точка входа.
## Headless → server_main.tscn
## Обычный → menu.tscn

const SERVER_SCENE := "res://src/scripts/network/server_main.tscn"
const MENU_SCENE   := "res://src/scenes/menu.tscn"


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("[entry] Headless режим → запуск сервера")
		get_tree().change_scene_to_file(SERVER_SCENE)
	else:
		get_tree().change_scene_to_file(MENU_SCENE)
