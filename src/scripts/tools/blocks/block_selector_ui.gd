extends Label

@export var player_path: NodePath = ""
var _player: Node = null

func _ready():
	_find_player()
	if _player and _player.has_signal("selected_slot_changed"):
		_player.selected_slot_changed.connect(_on_selected_slot_changed)
	_update_text_from_player()

func _find_player():
	if player_path:
		_player = get_node(player_path)
		if _player: return
	_player = _find_player_recursive(get_tree().current_scene)

func _find_player_recursive(node: Node) -> Node:
	if node is CharacterBody3D:
		return node
	for child in node.get_children():
		var found = _find_player_recursive(child)
		if found:
			return found
	return null

func _on_selected_slot_changed(_index: int):
	_update_text_from_player()

func _update_text_from_player():
	if not _player or not _player.has_method("get_selected_block_info"):
		text = "Блок: неизвестно"
		return
	var info = _player.get_selected_block_info()
	if info and not info.is_empty():
		text = "🧱 [%s] %s" % [info.get("id", "?"), info.get("name", "пусто")]
	else:
		text = "🧱 [пусто]"
