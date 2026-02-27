extends Control

@export var player_path: NodePath = ""
@onready var slots_container = $HBoxContainer

var _player: Node = null
var _slot_controls: Array[Control] = []

func _ready():
	_find_player()
	if _player:
		if _player.has_signal("hotbar_updated"):
			_player.hotbar_updated.connect(_on_hotbar_updated)
		if _player.has_signal("selected_slot_changed"):
			_player.selected_slot_changed.connect(_on_selected_slot_changed)
		_initialize_slots()
	else:
		push_error("hotbar.gd: игрок не найден")

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

func _initialize_slots():
	for child in slots_container.get_children():
		child.queue_free()
	_slot_controls.clear()
	
	for i in range(9):
		var slot = _create_slot(i)
		slots_container.add_child(slot)
		_slot_controls.append(slot)
	
	_update_all_slots()
	if _player:
		_on_selected_slot_changed(_player.selected_slot)

func _create_slot(index: int) -> Control:
	var panel = Panel.new()
	panel.size = Vector2(44, 44)
	panel.set_meta("slot_index", index)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.5, 0.5, 0.5)
	panel.add_theme_stylebox_override("panel", style)
	
	var icon = TextureRect.new()
	icon.name = "Icon"
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(36, 36)
	icon.position = Vector2(4, 4)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(icon)
	
	var label = Label.new()
	label.text = str(index + 1)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.size = Vector2(40, 40)
	label.position = Vector2(2, 2)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", 10)
	panel.add_child(label)
	
	return panel

func _update_all_slots():
	for i in range(min(9, _slot_controls.size())):
		_update_slot(i)

func _update_slot(index: int):
	if index < 0 or index >= _slot_controls.size():
		return
	var panel = _slot_controls[index]
	var icon = panel.get_node("Icon") as TextureRect
	if not icon:
		return
	
	if _player and _player.hotbar_items.size() > index:
		var item = _player.hotbar_items[index]
		if item and item.has("texture"):
			icon.texture = item.texture
			icon.show()
		else:
			icon.texture = null
			icon.hide()
	else:
		icon.hide()

func _highlight_slot(index: int, selected: bool):
	if index < 0 or index >= _slot_controls.size():
		return
	var panel = _slot_controls[index]
	var style = panel.get_theme_stylebox("panel").duplicate()
	style.border_color = Color.WHITE if selected else Color(0.5, 0.5, 0.5)
	panel.add_theme_stylebox_override("panel", style)

func _on_hotbar_updated(index: int):
	if index == -1:
		_update_all_slots()
	else:
		_update_slot(index)

func _on_selected_slot_changed(index: int):
	for i in _slot_controls.size():
		_highlight_slot(i, i == index)
