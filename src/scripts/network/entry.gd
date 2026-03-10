extends Node
## Точка входа → меню.

const MENU_SCENE := "res://src/scripts/network/scenes/main_menu.tscn"


func _ready() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)
