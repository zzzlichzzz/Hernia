extends Node

@export var player_path: NodePath = ""
var _player: Node = null

signal block_selected(block_id: int, block_name: String)

func _ready():
	_find_player()
	if _player and _player.has_signal("selected_slot_changed"):
		_player.selected_slot_changed.connect(_on_player_selected_slot_changed)
	print("🎮 BlockSelector (хотбар) готов!")

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

func _input(event: InputEvent):
	if not _player: return
	
	# Колёсико мыши работает только когда инвентарь закрыт
	if not _player.inventory_open and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if _player.has_method("select_next_slot"):
				_player.select_next_slot()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if _player.has_method("select_previous_slot"):
				_player.select_previous_slot()

func _on_player_selected_slot_changed(index: int):
	if not _player: return
	var info = _player.get_selected_block_info() if _player.has_method("get_selected_block_info") else {}
	var block_id = info.get("id", -1) if not info.is_empty() else -1
	var block_name = info.get("name", "empty") if not info.is_empty() else "empty"
	block_selected.emit(block_id, block_name)
