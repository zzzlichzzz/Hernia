extends Control

@export var inventory_path: NodePath = ""  # путь к узлу CreativeInventory
@onready var slots_container = $HBoxContainer

var _inventory: Node = null
var _slot_controls: Array[Control] = []

func _ready():
	_find_inventory()
	if _inventory:
		if _inventory.has_signal("hotbar_updated"):
			_inventory.hotbar_updated.connect(_on_hotbar_updated)
		if _inventory.has_signal("selected_slot_changed"):
			_inventory.selected_slot_changed.connect(_on_selected_slot_changed)
		_initialize_slots()
	else:
		push_error("hotbar.gd: инвентарь не найден")

func _find_inventory():
	if inventory_path:
		_inventory = get_node(inventory_path)
		if _inventory: return
	_inventory = _find_inventory_recursive(get_tree().current_scene)

func _find_inventory_recursive(node: Node) -> Node:
	if node.has_method("get_selected_block_info"):  # признак CreativeInventory
		return node
	for child in node.get_children():
		var found = _find_inventory_recursive(child)
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
	if _inventory:
		_on_selected_slot_changed(_inventory.selected_slot)

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
	
	if _inventory and _inventory.hotbar_items.size() > index:
		var item = _inventory.hotbar_items[index]
		if item and item.has("texture") and item.texture:
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
	if selected:
		style.border_color = Color.WHITE
	else:
		style.border_color = Color(0.5, 0.5, 0.5)
	panel.add_theme_stylebox_override("panel", style)

func _on_hotbar_updated(index: int):
	if index == -1:
		_update_all_slots()
	else:
		_update_slot(index)

func _on_selected_slot_changed(index: int):
	for i in _slot_controls.size():
		_highlight_slot(i, i == index)
