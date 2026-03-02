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
		var name = model.resource_name
		if name == "":
			name = model.resource_path.get_file().get_basename()
		_block_id_to_info[i] = {
			"name": name,
			"model": model
		}
		print("Блок ID ", i, ": ", name)

func _create_blocks_list():
	# Для каждого блока в библиотеке пытаемся найти текстуру
	for id in _block_id_to_info:
		var info = _block_id_to_info[id]
		var name = info.name
		var texture = null
		
		# Нормализуем имя: заменяем пробелы на подчёркивания для поиска файлов
		var normalized_name = name.replace(" ", "_").to_lower()
		
		# Проверяем сначала в папке icons/blocks (приоритет)
		var icon_path = icons_directory + normalized_name + ".png"
		if FileAccess.file_exists(icon_path):
			texture = load(icon_path)
		else:
			# Пробуем в папке textures/blocks
			var texture_path = textures_directory + name + "/" + name + ".png"
			if FileAccess.file_exists(texture_path):
				texture = load(texture_path)
			else:
				# Попробуем другой вариант: просто файл в textures_directory
				texture_path = textures_directory + name + ".png"
				if FileAccess.file_exists(texture_path):
					texture = load(texture_path)
				else:
					print("Текстура не найдена для блока ", name, ", используется заглушка")
		
		available_blocks.append({
			"id": id,
			"name": name,
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
		var slot_button = Button.new()
		slot_button.custom_minimum_size = Vector2(40, 40)
		slot_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		slot_button.tooltip_text = block.name
		
		var btn_style_normal = _create_inventory_slot_style(Color(0.5, 0.5, 0.5))
		var btn_style_hover = _create_inventory_slot_style(Color.WHITE)
		slot_button.add_theme_stylebox_override("normal", btn_style_normal)
		slot_button.add_theme_stylebox_override("hover", btn_style_hover)
		
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
			slot_button.add_child(texture_rect)
		else:
			var color_rect = ColorRect.new()
			color_rect.color = Color(0.5, 0.5, 0.5)  # серая заглушка
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
			slot_button.add_child(color_rect)
		
		slot_button.mouse_entered.connect(_on_inventory_slot_mouse_entered.bind(block))
		slot_button.mouse_exited.connect(_on_inventory_slot_mouse_exited)
		
		inventory_grid.add_child(slot_button)
	
	var close_btn = Button.new()
	close_btn.text = "Закрыть"
	close_btn.size = Vector2(80, 30)
	close_btn.position = Vector2((panel_width - 80) / 2, panel_height - 35)
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
