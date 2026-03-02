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
		if _inventory and _inventory.has_method("get_selected_block_info"):
			return
	# Пытаемся найти CreativeInventory по относительному пути от игрока
	var player = get_tree().get_first_node_in_group("player")
	if player:
		# Пробуем разные имена узлов инвентаря
		_inventory = player.get_node_or_null("CreativeInventory")
		if _inventory and _inventory.has_method("get_selected_block_info"):
			return
		_inventory = player.get_node_or_null("inventory")
		if _inventory and _inventory.has_method("get_selected_block_info"):
			return
	# Ищем через рекурсивный обход
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
	panel.custom_minimum_size = Vector2(48, 48)
	panel.set_meta("slot_index", index)
	
	# Создаём стиль с серым фоном
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 0.9)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.4, 0.4, 0.4)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)
	
	# Иконка (в центре)
	var icon = TextureRect.new()
	icon.name = "Icon"
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(36, 36)
	icon.anchor_left = 0.5
	icon.anchor_right = 0.5
	icon.anchor_top = 0.5
	icon.anchor_bottom = 0.5
	icon.offset_left = -18
	icon.offset_top = -18
	icon.offset_right = 18
	icon.offset_bottom = 18
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(icon)
	
	# Номер слота (в левом верхнем углу)
	var label = Label.new()
	label.text = str(index + 1)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.custom_minimum_size = Vector2(20, 20)
	label.position = Vector2(3, 2)
	label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	label.add_theme_font_size_override("font_size", 11)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	# Получаем текущий стиль или создаём новый
	var style = panel.get_theme_stylebox("panel")
	if style == null:
		style = StyleBoxFlat.new()
		style.bg_color = Color(0.15, 0.15, 0.15, 0.9)
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
	else:
		style = style.duplicate()
	
	if selected:
		style.border_color = Color(1.0, 1.0, 1.0)  # Белый цвет как в Майнкрафте
		style.border_width_left = 3
		style.border_width_right = 3
		style.border_width_top = 3
		style.border_width_bottom = 3
	else:
		style.border_color = Color(0.4, 0.4, 0.4)
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
	panel.add_theme_stylebox_override("panel", style)

func _on_hotbar_updated(index: int):
	if index == -1:
		_update_all_slots()
	else:
		_update_slot(index)

func _on_selected_slot_changed(index: int):
	for i in range(_slot_controls.size()):
		_highlight_slot(i, i == index)
