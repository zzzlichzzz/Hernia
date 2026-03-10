extends Node

# ═══════════════════════════════════════════════════════════
# CREATIVE INVENTORY — автономный модуль инвентаря
# ═══════════════════════════════════════════════════════════
# Добавьте как дочерний узел Player (CharacterBody3D).
# Если есть — инвентарь работает. Нет — всё остальное не ломается.
# ═══════════════════════════════════════════════════════════

# --- Настройки ---
@export var library_path: String = "res://src/data/items/items.tres"
@export var icons_directory: String = "res://src/assets/textures/atlas/icon/"

# --- Внутренние ресурсы ---
var atlas_coords: AtlasCoordinates = null
var atlas_path: String = "res://src/assets/textures/atlas/icon/block_coordinates.tres"

# --- Ссылки ---
var player: CharacterBody3D = null

# --- Данные хотбара ---
var hotbar_items: Array = []          # 9 слотов: null или Dictionary {id, name, texture}
var selected_slot: int = 0
var selected_block: Dictionary = {}   # текущий блок в руке (копия слота)

# --- Данные инвентаря ---
var available_blocks: Array[Dictionary] = []  # все доступные блоки
var hovered_block: Dictionary = {}            # блок под курсором (в открытом инвентаре)
var inventory_open: bool = false

# --- UI ---
var _canvas_layer: CanvasLayer = null
var _inventory_panel: Panel = null
var _inventory_grid: GridContainer = null

# --- Библиотека ---
var _items_library: ItemArrayRegistry = null
var _block_id_to_info: Dictionary = {}  # id -> {name, model}

# --- Сигналы ---
signal selected_slot_changed(index: int)
signal hotbar_updated(index: int)       # -1 = полное обновление
signal inventory_toggled(is_open: bool)


# ═══════════════════════════════════════════════════════════
#  ЖИЗНЕННЫЙ ЦИКЛ
# ═══════════════════════════════════════════════════════════

func _init():
	_load_atlas_data()


func _ready():
	player = get_parent() as CharacterBody3D
	if player == null:
		push_error("CreativeInventory: родитель должен быть CharacterBody3D")
		return

	# Инициализация слотов
	hotbar_items.resize(9)
	for i in 9:
		hotbar_items[i] = null

	_load_block_library()
	_build_available_blocks()
	_create_inventory_ui()


# ═══════════════════════════════════════════════════════════
#  ЗАГРУЗКА ДАННЫХ
# ═══════════════════════════════════════════════════════════

func _load_atlas_data():
	if ResourceLoader.exists(atlas_path):
		atlas_coords = load(atlas_path)
	else:
		push_warning("CreativeInventory: атлас не найден: %s" % atlas_path)


func _load_block_library():
	_items_library = load(library_path)
	if _items_library == null:
		push_error("CreativeInventory: не удалось загрузить библиотеку: %s" % library_path)
		return

	var items: Dictionary = _items_library.item_array
	for key in items:
		var model = items[key]
		if model == null:
			continue
		var block_name: String = model.resource_name
		if block_name.is_empty():
			block_name = model.resource_path.get_file().get_basename()
		_block_id_to_info[key] = {
			"name": block_name,
			"model": model,
		}


func _build_available_blocks():
	available_blocks.clear()
	for id in _block_id_to_info:
		var info = _block_id_to_info[id]
		var texture: Texture2D = null
		if atlas_coords:
			texture = atlas_coords.get_icon_texture(info.name)

		available_blocks.append({
			"id": id,
			"name": info.name,
			"texture": texture,
		})


# ═══════════════════════════════════════════════════════════
#  ВВОД
# ═══════════════════════════════════════════════════════════

func _input(event: InputEvent):
	if not event is InputEventKey or not event.pressed or event.echo:
		return

	# E — открыть/закрыть инвентарь
	if event.keycode == KEY_E:
		toggle_inventory()
		return

	# Цифры 1-9
	var slot_index := _key_to_slot(event.keycode)
	if slot_index == -1:
		return

	if inventory_open:
		# В открытом инвентаре — положить наведённый блок в слот
		if not hovered_block.is_empty():
			_place_hovered_block_into_slot(slot_index)
	else:
		# В закрытом — выбрать слот
		set_selected_slot(slot_index)


func _key_to_slot(keycode: int) -> int:
	if keycode >= KEY_1 and keycode <= KEY_9:
		return keycode - KEY_1
	return -1


# ═══════════════════════════════════════════════════════════
#  УПРАВЛЕНИЕ ИНВЕНТАРЁМ
# ═══════════════════════════════════════════════════════════

func toggle_inventory():
	inventory_open = !inventory_open

	if inventory_open:
		_inventory_panel.show()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		_inventory_panel.hide()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		hovered_block = {}

	# Совместимость с PlayerInteraction:
	# он проверяет player."inventory_open"
	_sync_inventory_state_to_player()
	inventory_toggled.emit(inventory_open)


func _sync_inventory_state_to_player():
	if player and "inventory_open" in player:
		player.inventory_open = inventory_open


# ═══════════════════════════════════════════════════════════
#  УПРАВЛЕНИЕ СЛОТАМИ
# ═══════════════════════════════════════════════════════════

func set_selected_slot(index: int):
	index = clampi(index, 0, 8)
	selected_slot = index
	selected_block = hotbar_items[index].duplicate() if hotbar_items[index] != null else {}
	selected_slot_changed.emit(index)


func select_next_slot():
	set_selected_slot((selected_slot + 1) % 9)


func select_previous_slot():
	set_selected_slot((selected_slot - 1 + 9) % 9)


func set_hotbar_slot(slot_index: int, block: Dictionary):
	if slot_index < 0 or slot_index >= 9:
		return
	hotbar_items[slot_index] = block.duplicate()
	hotbar_updated.emit(slot_index)
	# Если это текущий выбранный слот — обновить selected_block
	if slot_index == selected_slot:
		selected_block = block.duplicate()
		selected_slot_changed.emit(slot_index)


func clear_hotbar():
	for i in 9:
		hotbar_items[i] = null
	hotbar_updated.emit(-1)
	selected_block = {}
	selected_slot_changed.emit(selected_slot)


func get_selected_block_info() -> Dictionary:
	return selected_block.duplicate()


func _place_hovered_block_into_slot(slot_index: int):
	if slot_index < 0 or slot_index >= 9 or hovered_block.is_empty():
		return
	set_hotbar_slot(slot_index, hovered_block)
	set_selected_slot(slot_index)


## Добавить блок в первый пустой слот хотбара по имени
func place_item_in_hotbar(block_name: String) -> bool:
	for block in available_blocks:
		if block.name.to_lower() != block_name.to_lower():
			continue
		# Нашли блок — ищем пустой слот
		for slot_idx in 9:
			if hotbar_items[slot_idx] == null:
				set_hotbar_slot(slot_idx, block)
				return true
		push_warning("CreativeInventory: нет пустых слотов для '%s'" % block_name)
		return false

	push_warning("CreativeInventory: блок '%s' не найден" % block_name)
	return false


# ═══════════════════════════════════════════════════════════
#  HOVER (наведение мыши в инвентаре)
# ═══════════════════════════════════════════════════════════

func _on_inventory_slot_mouse_entered(block: Dictionary):
	hovered_block = block


func _on_inventory_slot_mouse_exited():
	hovered_block = {}


# ═══════════════════════════════════════════════════════════
#  UI — СОЗДАНИЕ
# ═══════════════════════════════════════════════════════════

func _create_inventory_ui():
	_canvas_layer = CanvasLayer.new()
	add_child(_canvas_layer)

	var viewport_size := get_viewport().get_visible_rect().size
	var panel_size := Vector2(400, 300)

	_inventory_panel = Panel.new()
	_inventory_panel.name = "InventoryPanel"
	_inventory_panel.size = panel_size
	_inventory_panel.position = (viewport_size - panel_size) / 2.0
	_inventory_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_inventory_panel.add_theme_stylebox_override("panel", _make_panel_style())
	_inventory_panel.hide()
	_canvas_layer.add_child(_inventory_panel)

	# Заголовок
	var title := Label.new()
	title.text = "Творческий инвентарь"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	title.size = Vector2(panel_size.x, 30)
	title.position = Vector2(0, 5)
	_inventory_panel.add_child(title)

	# Контейнер со скроллом
	var margin := MarginContainer.new()
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.offset_top = 40
	margin.offset_bottom = 40
	margin.offset_left = 10
	margin.offset_right = -10
	_inventory_panel.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	_inventory_grid = GridContainer.new()
	_inventory_grid.columns = 9
	_inventory_grid.add_theme_constant_override("h_separation", 6)
	_inventory_grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(_inventory_grid)

	# Заполняем сетку блоками
	for block in available_blocks:
		var slot := _create_inventory_slot(block)
		_inventory_grid.add_child(slot)

	# Кнопка закрытия
	var close_btn := Button.new()
	close_btn.text = "Закрыть"
	close_btn.size = Vector2(80, 30)
	close_btn.position = Vector2((panel_size.x - 80) / 2.0, panel_size.y - 35)
	close_btn.pressed.connect(toggle_inventory)
	_inventory_panel.add_child(close_btn)


# ═══════════════════════════════════════════════════════════
#  UI — СЛОТ ИНВЕНТАРЯ (с поддержкой drag)
# ═══════════════════════════════════════════════════════════

func _create_inventory_slot(block: Dictionary) -> Control:
	var slot := InventorySlotControl.new()
	slot.custom_minimum_size = Vector2(40, 40)
	slot.block_data = block
	slot.mouse_entered.connect(_on_inventory_slot_mouse_entered.bind(block))
	slot.mouse_exited.connect(_on_inventory_slot_mouse_exited)

	# Иконка блока
	if block.texture:
		var tex_rect := TextureRect.new()
		tex_rect.texture = block.texture
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.anchor_left = 0.5
		tex_rect.anchor_right = 0.5
		tex_rect.anchor_top = 0.5
		tex_rect.anchor_bottom = 0.5
		tex_rect.offset_left = -16
		tex_rect.offset_top = -16
		tex_rect.offset_right = 16
		tex_rect.offset_bottom = 16
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(tex_rect)
	else:
		var placeholder := ColorRect.new()
		placeholder.color = Color(0.4, 0.4, 0.4)
		placeholder.anchor_left = 0.5
		placeholder.anchor_right = 0.5
		placeholder.anchor_top = 0.5
		placeholder.anchor_bottom = 0.5
		placeholder.offset_left = -16
		placeholder.offset_top = -16
		placeholder.offset_right = 16
		placeholder.offset_bottom = 16
		placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(placeholder)

	return slot


# ═══════════════════════════════════════════════════════════
#  UI — СТИЛИ
# ═══════════════════════════════════════════════════════════

func _make_panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.2, 0.2, 0.2, 0.95)
	s.border_color = Color(0.5, 0.5, 0.5)
	s.set_border_width_all(3)
	s.set_corner_radius_all(8)
	return s


# ═══════════════════════════════════════════════════════════
#  ВЛОЖЕННЫЙ КЛАСС: СЛОТ ИНВЕНТАРЯ
# ═══════════════════════════════════════════════════════════

class InventorySlotControl extends Control:
	## Данные блока в этом слоте
	var block_data: Dictionary = {}

	# Визуальные настройки
	var _bg_color: Color = Color(0.15, 0.15, 0.15, 0.9)
	var _border_color: Color = Color(0.4, 0.4, 0.4)
	var _hovered: bool = false

	func _ready():
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_entered.connect(func(): _hovered = true; _border_color = Color(0.8, 0.8, 0.8); queue_redraw())
		mouse_exited.connect(func(): _hovered = false; _border_color = Color(0.4, 0.4, 0.4); queue_redraw())

	func _draw():
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, _bg_color)
		draw_rect(r, _border_color, false, 2.0)

	func _get_drag_data(_at_position: Vector2) -> Variant:
		if block_data.is_empty():
			return null

		# Превью для перетаскивания
		var preview := PanelContainer.new()
		preview.custom_minimum_size = Vector2(40, 40)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.3, 0.3, 0.3, 0.8)
		style.border_color = Color(0.6, 0.6, 0.6)
		style.set_border_width_all(2)
		preview.add_theme_stylebox_override("panel", style)

		if block_data.has("texture") and block_data.texture:
			var tex := TextureRect.new()
			tex.texture = block_data.texture
			tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex.custom_minimum_size = Vector2(32, 32)
			preview.add_child(tex)

		set_drag_preview(preview)
		return { "block": block_data.duplicate() }
