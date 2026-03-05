extends Node
## Точка входа.
## Headless → сразу server_main.tscn
## Обычный → menu.tscn (или что у тебя главное меню)

const SERVER_SCENE := "res://src/scripts/network/server_main.tscn"
const MENU_SCENE   := "res://src/scenes/menu.tscn"   # ← поменяй на свой путь


func _ready() -> void:
	if CmdArgs.is_headless():
		print("[entry] Headless режим → запуск сервера")
		get_tree().change_scene_to_file(SERVER_SCENE)
	else:
		get_tree().change_scene_to_file(MENU_SCENE)
