extends Control

# ═══════════════════════════════════════════════════════════
# HOTBAR — отображение слотов + переключение колёсиком мыши
# ═══════════════════════════════════════════════════════════
# Автономный UI-модуль.
# Находит CreativeInventory самостоятельно.
# Если нет — ничего не ломается.
# ═══════════════════════════════════════════════════════════

@export var inventory_path: NodePath = ""
@onready var slots_container = $HBoxContainer

var _inventory: Node = null
var _slot_controls: Array[Control] = []

# --- Настройки визуала ---
const SLOT_SIZE := Vector2(48, 48)
const ICON_SIZE := Vector2(36, 36)
const CORNER_RADIUS := 4

const COLOR_BG := Color(0.1, 0.1, 0.1, 0.85)
const COLOR_BG_SELECTED := Color(0.15, 0.35, 0.15, 1.0)
const COLOR_BORDER := Color(0.3, 0.3, 0.3)
const COLOR_BORDER_SELECTED := Color(0.2, 1.0, 0.2)
const BORDER_WIDTH := 2
const BORDER_WIDTH_SELECTED := 5

# Свечение выбранного слота
const GLOW_COLOR := Color(0.0, 1.0, 0.0, 0.6)
const GLOW_SIZE := 8


# ═══════════════════════════════════════════════════════════
#  ЖИЗНЕННЫЙ ЦИКЛ
# ═══════════════════════════════════════════════════════════

func _ready():
	await get_tree().process_frame
	_find_inventory()
	if _inventory == null:
		push_error("Hotbar: инвентарь не найден")
		return

	if _inventory.has_signal("hotbar_updated"):
		_inventory.hotbar_updated.connect(_on_hotbar_updated)
	if _inventory.has_signal("selected_slot_changed"):
		_inventory.selected_slot_changed.connect(_on_selected_slot_changed)

	_initialize_slots()


# ═══════════════════════════════════════════════════════════
#  КОЛЁСИКО МЫШИ — переключение слотов
# ═══════════════════════════════════════════════════════════

func _unhandled_input(event: InputEvent):
	if _inventory == null:
		return

	# Не переключаем слоты пока инвентарь открыт
	if _is_inventory_open():
		return

	if not event is InputEventMouseButton or not event.pressed:
		return

	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			_inventory.select_previous_slot()
			get_viewport().set_input_as_handled()
		MOUSE_BUTTON_WHEEL_DOWN:
			_inventory.select_next_slot()
			get_viewport().set_input_as_handled()


func _is_inventory_open() -> bool:
	if _inventory and "inventory_open" in _inventory:
		return _inventory.inventory_open
	return false


# ═══════════════════════════════════════════════════════════
#  ПОИСК ИНВЕНТАРЯ
# ═══════════════════════════════════════════════════════════

func _find_inventory():
	# 1. Явный путь
	if not inventory_path.is_empty():
		var node = get_node_or_null(inventory_path)
		if node and node.has_method("get_selected_block_info"):
			_inventory = node
			return

	# 2. Ищем у игрока (группа "player")
	var player_node = get_tree().get_first_node_in_group("player")
	if player_node:
		for child in player_node.get_children():
			if child.has_method("get_selected_block_info"):
				_inventory = child
				return

	# 3. Рекурсивный поиск
	_inventory = _find_recursive(get_tree().current_scene)


func _find_recursive(node: Node) -> Node:
	if node.has_method("get_selected_block_info"):
		return node
	for child in node.get_children():
		var found := _find_recursive(child)
		if found:
			return found
	return null


# ═══════════════════════════════════════════════════════════
#  СОЗДАНИЕ СЛОТОВ
# ═══════════════════════════════════════════════════════════

func _initialize_slots():
	for child in slots_container.get_children():
		child.queue_free()
	_slot_controls.clear()

	for i in 9:
		var slot := _create_slot(i)
		slots_container.add_child(slot)
		_slot_controls.append(slot)

	_update_all_slots()
	if _inventory:
		_on_selected_slot_changed(_inventory.selected_slot)


func _create_slot(index: int) -> Control:
	var panel := Panel.new()
	panel.custom_minimum_size = SLOT_SIZE
	panel.set_meta("slot_index", index)
	panel.add_theme_stylebox_override("panel", _make_slot_style(false))

	# Скрипт для drag & drop
	var slot_script = load("res://src/scripts/ui/inventory_ui/hotbar_slot.gd")
	if slot_script:
		panel.set_script(slot_script)
		panel.slot_index = index
		panel.inventory = _inventory

	# Иконка блока
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = ICON_SIZE
	icon.anchor_left = 0.5
	icon.anchor_right = 0.5
	icon.anchor_top = 0.5
	icon.anchor_bottom = 0.5
	icon.offset_left = -ICON_SIZE.x / 2.0
	icon.offset_top = -ICON_SIZE.y / 2.0
	icon.offset_right = ICON_SIZE.x / 2.0
	icon.offset_bottom = ICON_SIZE.y / 2.0
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.visible = false
	panel.add_child(icon)

	# Номер слота
	var label := Label.new()
	label.name = "SlotNumber"
	label.text = str(index + 1)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.position = Vector2(3, 2)
	label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	label.add_theme_font_size_override("font_size", 11)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)

	return panel


# ═══════════════════════════════════════════════════════════
#  СТИЛИ
# ═══════════════════════════════════════════════════════════

func _make_slot_style(is_selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	if is_selected:
		style.bg_color = COLOR_BG_SELECTED
		style.border_color = COLOR_BORDER_SELECTED
		style.set_border_width_all(BORDER_WIDTH_SELECTED)
		# Свечение
		style.shadow_color = GLOW_COLOR
		style.shadow_size = GLOW_SIZE
		style.shadow_offset = Vector2.ZERO
	else:
		style.bg_color = COLOR_BG
		style.border_color = COLOR_BORDER
		style.set_border_width_all(BORDER_WIDTH)

	style.set_corner_radius_all(CORNER_RADIUS)
	return style


func _highlight_slot(index: int, is_selected: bool):
	if index < 0 or index >= _slot_controls.size():
		return
	_slot_controls[index].add_theme_stylebox_override("panel", _make_slot_style(is_selected))


# ═══════════════════════════════════════════════════════════
#  ОБНОВЛЕНИЕ СОДЕРЖИМОГО
# ═══════════════════════════════════════════════════════════

func _update_all_slots():
	for i in mini(9, _slot_controls.size()):
		_update_slot(i)


func _update_slot(index: int):
	if index < 0 or index >= _slot_controls.size():
		return

	var icon := _slot_controls[index].get_node_or_null("Icon") as TextureRect
	if icon == null:
		return

	var has_item := false
	if _inventory and _inventory.hotbar_items.size() > index:
		var item = _inventory.hotbar_items[index]
		if item and item.has("texture") and item.texture:
			icon.texture = item.texture
			has_item = true

	icon.visible = has_item


# ═══════════════════════════════════════════════════════════
#  ОБРАБОТЧИКИ СИГНАЛОВ
# ═══════════════════════════════════════════════════════════

func _on_hotbar_updated(index: int):
	if index == -1:
		_update_all_slots()
	else:
		_update_slot(index)


func _on_selected_slot_changed(index: int):
	for i in _slot_controls.size():
		_highlight_slot(i, i == index)
