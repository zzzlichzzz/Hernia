extends Node

# Путь к библиотеке блоков
@export var block_library_path: String = "res://src/data/blocks/voxel_blocky_library.tres"
# Путь к папке с текстурами блоков (для иконок)
@export var textures_directory: String = "res://src/assets/textures/blocks/"
# Путь к папке с иконками блоков
@export var icons_directory: String = "res://src/assets/icons/blocks/"
# Ручное сопоставление имени блока (из библиотеки) к имени папки с текстурой (если отличаются)
@export var texture_name_mapping: Dictionary = {}

# Ссылка на игрока (родитель)
var player: CharacterBody3D

# Данные хотбара
var hotbar_items: Array = []                  # 9 слотов, null или Dictionary {id, name, texture}
var selected_slot: int = 0
var selected_block: Dictionary = {}           # текущий блок в руке

# Данные инвентаря
var available_blocks: Array[Dictionary] = []  # список блоков для творческого меню
var hovered_block: Dictionary = {}            # блок, на который наведена мышь в инвентаре
var inventory_open: bool = false

# UI
var inventory_panel: Panel
var inventory_grid: GridContainer
var canvas_layer: CanvasLayer

# Drag & Drop
var dragged_block: Dictionary = {}
var _drag_preview: Control = null

# Сигналы
signal selected_slot_changed(index: int)
signal hotbar_updated(index: int)  # -1 для полного обновления

# Библиотека
var _block_library: VoxelBlockyLibrary
var _block_id_to_info: Dictionary = {}  # id -> {name: String, model: VoxelBlockyModel}

func _ready():
	# Получаем игрока (родитель должен быть CharacterBody3D)
	player = get_parent()
	if not player is CharacterBody3D:
		push_error("CreativeInventory должен быть дочерним узлом CharacterBody3D")
		return
	
	# Инициализация хотбара
	for i in 9:
		hotbar_items.append(null)
	
	# Загружаем библиотеку и создаём список блоков
	_load_block_library()
	_create_blocks_list()
	
	# Создаём UI инвентаря
	_create_inventory_ui()

func _load_block_library():
	if not ResourceLoader.exists(block_library_path):
		push_error("Библиотека не найдена: ", block_library_path)
		return
	_block_library = load(block_library_path) as VoxelBlockyLibrary
	if _block_library == null:
		push_error("Не удалось загрузить библиотеку")
		return
	
	var models: Array = _block_library.models
	print("Загружено моделей: ", models.size())
	for i in range(models.size()):
		var model = models[i]
		if model == null:
			continue
		var block_name = model.resource_name
		if block_name == "":
			block_name = model.resource_path.get_file().get_basename()
		_block_id_to_info[i] = {
			"name": block_name,
			"model": model
		}
		print("Блок ID ", i, ": ", block_name)

func _create_blocks_list():
	# Для каждого блока в библиотеке пытаемся найти текстуру
	for id in _block_id_to_info:
		var info = _block_id_to_info[id]
		var block_name = info.name
		var texture = null
		
		# Нормализуем имя: заменяем пробелы на подчёркивания для поиска файлов
		var normalized_name = block_name.replace(" ", "_").to_lower()
		
		# Проверяем сначала в папке icons/blocks (приоритет)
		var icon_path = icons_directory + normalized_name + ".png"
		if FileAccess.file_exists(icon_path):
			texture = load(icon_path)
		else:
			# Пробуем в папке textures/blocks
			var texture_path = textures_directory + block_name + "/" + block_name + ".png"
			if FileAccess.file_exists(texture_path):
				texture = load(texture_path)
			else:
				# Попробуем другой вариант: просто файл в textures_directory
				texture_path = textures_directory + block_name + ".png"
				if FileAccess.file_exists(texture_path):
					texture = load(texture_path)
				else:
					print("Текстура не найдена для блока ", block_name, ", используется заглушка")
		
		available_blocks.append({
			"id": id,
			"name": block_name,
			"texture": texture
		})
	print("Доступно блоков для инвентаря: ", available_blocks.size())

func _create_inventory_ui():
	canvas_layer = CanvasLayer.new()
	add_child(canvas_layer)
	
	var panel_width = 400
	var panel_height = 300
	inventory_panel = Panel.new()
	inventory_panel.name = "Inventory"
	inventory_panel.size = Vector2(panel_width, panel_height)
	inventory_panel.position = (get_viewport().get_visible_rect().size - inventory_panel.size) / 2
	inventory_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	inventory_panel.hide()
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.2, 0.2, 0.2, 0.95)
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.border_width_top = 3
	panel_style.border_width_bottom = 3
	panel_style.border_color = Color(0.5, 0.5, 0.5)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	inventory_panel.add_theme_stylebox_override("panel", panel_style)
	canvas_layer.add_child(inventory_panel)
	
	var title = Label.new()
	title.text = "Творческий инвентарь"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	title.size = Vector2(panel_width, 30)
	title.position = Vector2(0, 5)
	inventory_panel.add_child(title)
	
	var margin = MarginContainer.new()
	margin.anchor_left = 0.0
	margin.anchor_top = 0.0
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.offset_top = 40
	margin.offset_bottom = 40
	margin.offset_left = 10
	margin.offset_right = 10
	inventory_panel.add_child(margin)
	
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	
	inventory_grid = GridContainer.new()
	inventory_grid.columns = 9
	inventory_grid.add_theme_constant_override("h_separation", 6)
	inventory_grid.add_theme_constant_override("v_separation", 6)
	inventory_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	scroll.add_child(inventory_grid)
	
	for block in available_blocks:
		var slot_button = _create_inventory_slot_button(block)
		inventory_grid.add_child(slot_button)
	
	var close_btn = Button.new()
	close_btn.text = "Закрыть"
	close_btn.size = Vector2(80, 30)
	close_btn.position = Vector2((panel_width - 80) / 2.0, panel_height - 35)
	close_btn.pressed.connect(toggle_inventory)
	
	var close_style = StyleBoxFlat.new()
	close_style.bg_color = Color(0.2, 0.2, 0.2)
	close_style.border_width_left = 1
	close_style.border_width_right = 1
	close_style.border_width_top = 1
	close_style.border_width_bottom = 1
	close_style.border_color = Color(0.6, 0.6, 0.6)
	close_style.corner_radius_top_left = 4
	close_style.corner_radius_top_right = 4
	close_style.corner_radius_bottom_left = 4
	close_style.corner_radius_bottom_right = 4
	close_btn.add_theme_stylebox_override("normal", close_style)
	inventory_panel.add_child(close_btn)

# Функция для обработки drag на уровне сетки инвентаря
func _get_drag_data_grid(at_position: Vector2) -> Variant:
	# Пробуем найти элемент под мышью
	var hovered = _find_hovered_slot(at_position)
	if hovered != null:
		return {"block": hovered.duplicate()}
	return null

# Найти элемент под мышью в инвентаре
func _find_hovered_slot(mouse_pos: Vector2) -> Dictionary:
	# Получаем глобальную позицию мыши
	var viewport = get_viewport()
	var mouse_global_pos = viewport.get_mouse_position()
	
	# Провяем каждый дочерний элемент сетки
	for child in inventory_grid.get_children():
		if child is Control:
			var rect = child.get_global_rect()
			if rect.has_point(mouse_global_pos):
				var block = child.get_meta("block_data", {})
				if not block.is_empty():
					return block
	return {}

# Создание кнопки слота инвентаря с поддержкой drag & drop
func _create_inventory_slot_button(block: Dictionary) -> Control:
	# Создаём кастомный элемент с поддержкой drag
	var slot = _InventorySlot.new()
	slot.custom_minimum_size = Vector2(40, 40)
	slot.set_meta("block_data", block)
	slot.set_meta("block_name", block.name)
	
	# Стили
	var btn_style = _create_inventory_slot_style(Color(0.5, 0.5, 0.5))
	slot.add_theme_stylebox_override("panel", btn_style)
	
	# Текстура
	if block.texture:
		var texture_rect = TextureRect.new()
		texture_rect.texture = block.texture
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.custom_minimum_size = Vector2(32, 32)
		texture_rect.size = Vector2(32, 32)
		texture_rect.anchor_left = 0.5
		texture_rect.anchor_right = 0.5
		texture_rect.anchor_top = 0.5
		texture_rect.anchor_bottom = 0.5
		texture_rect.offset_left = -16
		texture_rect.offset_top = -16
		texture_rect.offset_right = 16
		texture_rect.offset_bottom = 16
		texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(texture_rect)
	else:
		var color_rect = ColorRect.new()
		color_rect.color = Color(0.5, 0.5, 0.5)
		color_rect.custom_minimum_size = Vector2(32, 32)
		color_rect.anchor_left = 0.5
		color_rect.anchor_right = 0.5
		color_rect.anchor_top = 0.5
		color_rect.anchor_bottom = 0.5
		color_rect.offset_left = -16
		color_rect.offset_top = -16
		color_rect.offset_right = 16
		color_rect.offset_bottom = 16
		color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(color_rect)
	
	# Обработчики событий
	slot.mouse_entered.connect(_on_inventory_slot_mouse_entered.bind(block))
	slot.mouse_exited.connect(_on_inventory_slot_mouse_exited)
	
	return slot

# Класс слота инвентаря с поддержкой drag
class _InventorySlot extends Control:
	var _is_hovered: bool = false
	var _block_data: Dictionary = {}
	# Стиль как в хотбаре
	var _default_color: Color = Color(0.15, 0.15, 0.15, 0.9)
	var _border_color: Color = Color(0.4, 0.4, 0.4)
	var WHITE: Color = Color(0.6, 0.6, 0.6)
	
	func _ready():
		mouse_filter = Control.MOUSE_FILTER_STOP
		# Подключаем сигналы наведения
		mouse_entered.connect(_on_mouse_entered)
		mouse_exited.connect(_on_mouse_exited)
	
	func _on_mouse_entered():
		_is_hovered = true
		_border_color = WHITE
		queue_redraw()
	
	func _on_mouse_exited():
		_is_hovered = false
		_border_color = Color(0.5, 0.5, 0.5)
		queue_redraw()
	
	func _can_drop_data(at_position: Vector2, data) -> bool:
		return typeof(data) == TYPE_DICTIONARY and data.has("block")
	
	func _drop_data(at_position: Vector2, data):
		if typeof(data) == TYPE_DICTIONARY and data.has("block"):
			var inventory = _find_inventory()
			if inventory and inventory.has_method("set_hotbar_slot"):
				var slot_index = get_parent().get_child_count()
				for i in range(get_parent().get_child_count()):
					if get_parent().get_child(i) == self:
						slot_index = i
						break
				inventory.set_hotbar_slot(slot_index, data["block"])
	
	func _find_inventory() -> Node:
		var inv = get_tree().get_first_node_in_group("player")
		if inv:
			inv = inv.get_node_or_null("CreativeInventory")
			if inv and inv.has_method("set_hotbar_slot"):
				return inv
			inv = inv.get_node_or_null("inventory")
			if inv and inv.has_method("set_hotbar_slot"):
				return inv
		return null
	
	func _draw():
		# Рисуем фон
		var rect = get_rect()
		draw_rect(Rect2(0, 0, rect.size.x, rect.size.y), _default_color)
		# Рисуем обводку
		draw_rect(Rect2(0, 0, rect.size.x, rect.size.y), _border_color, false, 2.0)
	
	func _get_drag_data(at_position: Vector2) -> Variant:
		var block = get_meta("block_data", {})
		if not block.is_empty():
			var preview = Control.new()
			preview.custom_minimum_size = Vector2(40, 40)
			
			var bg = StyleBoxFlat.new()
			bg.bg_color = Color(0.3, 0.3, 0.3, 0.8)
			bg.border_width_left = 2
			bg.border_width_right = 2
			bg.border_width_top = 2
			bg.border_width_bottom = 2
			bg.border_color = Color(0.6, 0.6, 0.6)
			preview.add_theme_stylebox_override("panel", bg)
			
			if block.has("texture") and block.texture:
				var texture = TextureRect.new()
				texture.texture = block.texture
				texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				texture.custom_minimum_size = Vector2(32, 32)
				texture.anchor_left = 0.5
				texture.anchor_right = 0.5
				texture.anchor_top = 0.5
				texture.anchor_bottom = 0.5
				texture.offset_left = -16
				texture.offset_top = -16
				texture.offset_right = 16
				texture.offset_bottom = 16
				preview.add_child(texture)
			
			set_drag_preview(preview)
			return {"block": block.duplicate()}
		return null

# Класс для поддержки drag & drop (вложенный класс)
class _DragableSlot extends Control:
	var block_data: Dictionary = {}
	
	func _ready():
		# Включаем обработку мыши
		pass
	
	func _get_drag_data(at_position: Vector2) -> Variant:
		if not block_data.is_empty():
			# Создаём превью
			var preview = Control.new()
			preview.custom_minimum_size = Vector2(40, 40)
			
			var bg = StyleBoxFlat.new()
			bg.bg_color = Color(0.3, 0.3, 0.3, 0.8)
			bg.border_width_left = 2
			bg.border_width_right = 2
			bg.border_width_top = 2
			bg.border_width_bottom = 2
			bg.border_color = Color(0.6, 0.6, 0.6)
			preview.add_theme_stylebox_override("panel", bg)
			
			if block_data.has("texture") and block_data.texture:
				var texture = TextureRect.new()
				texture.texture = block_data.texture
				texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				texture.custom_minimum_size = Vector2(32, 32)
				texture.anchor_left = 0.5
				texture.anchor_right = 0.5
				texture.anchor_top = 0.5
				texture.anchor_bottom = 0.5
				texture.offset_left = -16
				texture.offset_top = -16
				texture.offset_right = 16
				texture.offset_bottom = 16
				preview.add_child(texture)
			
			set_drag_preview(preview)
			return {"block": block_data.duplicate()}
		return null

# Переопределяем _get_drag_data для слотов инвентаря
func _get_drag_data(at_position: Vector2) -> Variant:
	# Получаем данные из метаданных элемента, на который наведена мышь
	if not hovered_block.is_empty():
		return {"block": hovered_block.duplicate()}
	return null

func _create_inventory_slot_style(border_color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.3, 0.3, 0.9)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = border_color
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	return style

func _input(event: InputEvent):
	# Открытие/закрытие инвентаря по E
	if event is InputEventKey and event.keycode == KEY_E and event.pressed:
		toggle_inventory()
	
	# Если инвентарь открыт, цифры кладут наведённый блок в слот
	if inventory_open and event is InputEventKey and event.pressed and not event.echo:
		var slot_index = _key_to_slot(event.keycode)
		if slot_index != -1 and not hovered_block.is_empty():
			_place_hovered_block_into_slot(slot_index)
	
	# Если инвентарь закрыт, цифры выбирают слот
	if not inventory_open and event is InputEventKey and event.pressed and not event.echo:
		var slot_index = _key_to_slot(event.keycode)
		if slot_index != -1:
			set_selected_slot(slot_index)

func _key_to_slot(keycode: int) -> int:
	match keycode:
		KEY_1: return 0
		KEY_2: return 1
		KEY_3: return 2
		KEY_4: return 3
		KEY_5: return 4
		KEY_6: return 5
		KEY_7: return 6
		KEY_8: return 7
		KEY_9: return 8
	return -1

func toggle_inventory():
	inventory_open = !inventory_open
	if inventory_open:
		inventory_panel.show()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		player.inventory_open = true
	else:
		inventory_panel.hide()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		player.inventory_open = false
		hovered_block = {}

func _on_inventory_slot_mouse_entered(block: Dictionary):
	hovered_block = block
	print("Наведён блок: ", block.name, " ID: ", block.id)

func _on_inventory_slot_mouse_exited():
	hovered_block = {}

# Обработка ввода на слоте (для drag & drop)
func _on_inventory_slot_input(event: InputEvent, block: Dictionary):
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			hovered_block = block

func _place_hovered_block_into_slot(slot_index: int):
	if slot_index < 0 or slot_index >= 9 or hovered_block.is_empty():
		return
	hotbar_items[slot_index] = hovered_block
	hotbar_updated.emit(slot_index)
	set_selected_slot(slot_index)
	print("Блок ", hovered_block.name, " помещён в слот ", slot_index + 1)

func set_selected_slot(index: int):
	if index < 0 or index >= 9:
		return
	selected_slot = index
	selected_block = hotbar_items[index] if hotbar_items[index] != null else {}
	selected_slot_changed.emit(index)
	print("Выбран слот: ", index + 1, ", блок: ", selected_block.get("name", "пусто"), " ID: ", selected_block.get("id", "?"))

func select_next_slot():
	set_selected_slot((selected_slot + 1) % 9)

func select_previous_slot():
	set_selected_slot((selected_slot - 1 + 9) % 9)

func get_selected_block_info() -> Dictionary:
	return selected_block.duplicate()

# Добавить предмет в хотбар по имени блока
func place_item_in_hotbar(block_name: String) -> void:
	# Ищем блок по имени в available_blocks
	for i in range(available_blocks.size()):
		var block = available_blocks[i]
		if block.name.to_lower() == block_name.to_lower():
			# Нашли блок, добавляем в первый пустой слот
			for slot_idx in range(9):
				if hotbar_items[slot_idx] == null:
					hotbar_items[slot_idx] = block
					hotbar_updated.emit(slot_idx)
					print("Added ", block_name, " to slot ", slot_idx + 1)
					return
		print("No empty slot found in hotbar")
		return

# Очистить хотбар
func clear_hotbar() -> void:
	for i in range(9):
		hotbar_items[i] = null
		hotbar_updated.emit(i)
	print("Hotbar cleared")

# Установить блок в конкретный слот хотбара
func set_hotbar_slot(slot_index: int, block: Dictionary) -> void:
	if slot_index < 0 or slot_index >= 9:
		return
	hotbar_items[slot_index] = block
	hotbar_updated.emit(slot_index)
	print("Блок ", block.get("name", "unknown"), " установлен в слот ", slot_index + 1)

# ═══════════════════════════════════════════════════════════
# DRAG & DROP - Перетаскивание блоков из творческого инвентаря в хотбар
# ═══════════════════════════════════════════════════════════

# Создание превью для перетаскивания
func _create_drag_preview(block: Dictionary) -> Control:
	var preview = Control.new()
	preview.custom_minimum_size = Vector2(40, 40)
	
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.3, 0.3, 0.3, 0.8)
	bg.border_width_left = 2
	bg.border_width_right = 2
	bg.border_width_top = 2
	bg.border_width_bottom = 2
	bg.border_color = Color(0.6, 0.6, 0.6)
	preview.add_theme_stylebox_override("panel", bg)
	
	if block.has("texture") and block.texture:
		var texture = TextureRect.new()
		texture.texture = block.texture
		texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture.custom_minimum_size = Vector2(32, 32)
		texture.size = Vector2(32, 32)
		texture.anchor_left = 0.5
		texture.anchor_right = 0.5
		texture.anchor_top = 0.5
		texture.anchor_bottom = 0.5
		texture.offset_left = -16
		texture.offset_top = -16
		texture.offset_right = 16
		texture.offset_bottom = 16
		preview.add_child(texture)
	
	return preview

# Обработка начала перетаскивания
func _on_slot_drag_started():
	dragged_block = hovered_block
	print("Начато перетаскивание: ", hovered_block.get("name", "unknown"))

# Обработка перетаскивания на слот хотбара
func _can_drop_data(_at_position: Vector2, data) -> bool:
	return data.has("block")

func _drop_data(_at_position: Vector2, data: Dictionary):
	if data.has("block"):
		var block = data["block"]
		var slot_index = data.get("slot_index", -1)
		
		if slot_index >= 0 and slot_index < 9:
			hotbar_items[slot_index] = block
			hotbar_updated.emit(slot_index)
			print("Блок ", block.name, " помещён в слот хотбара ", slot_index + 1)
