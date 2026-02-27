extends CharacterBody3D

# Экспортируемые параметры
@export var move_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var gravity: float = 9.8
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.002
@export var blocks_directory: String = "res://src/assets/textures/blocks/"
@export var block_library_path: String = "res://src/data/blocks/voxel_blocky_library.tres"

# Ручное сопоставление "имя_папки" -> ID (заполните в инспекторе)
@export var custom_block_mapping: Dictionary = {
	"stone": 3,
	"dirt": 2,
	"grass_block": 1
}

@onready var neck: Node3D = $Neck
@onready var camera: Camera3D = $Neck/Camera3D

# Сигналы
signal selected_slot_changed(index: int)
signal hotbar_updated(index: int)

# Константы
const HOTBAR_SLOTS: int = 9
const SLOT_SIZE: int = 40
const SLOT_MARGIN: int = 4

# UI элементы
var canvas_layer: CanvasLayer
var hotbar_slots: Array[Button] = []
var hotbar_icons: Array[TextureRect] = []
var hotbar_items: Array = []
var selected_slot: int = 0
var selected_block: Dictionary = {}

# Инвентарь
var inventory_open: bool = false
var inventory_panel: Panel
var inventory_grid: GridContainer
var available_blocks: Array[Dictionary] = []
var hovered_block: Dictionary = {}

# Библиотека блоков
var _block_library: VoxelBlockyLibrary = null
var _block_name_to_id: Dictionary = {}

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_load_block_library()
	load_blocks_from_directory()
	create_ui()
	for i in HOTBAR_SLOTS:
		hotbar_items.append(null)

func _load_block_library():
	if not ResourceLoader.exists(block_library_path):
		push_error("❌ Библиотека блоков не найдена: ", block_library_path)
		return
	_block_library = load(block_library_path) as VoxelBlockyLibrary
	if _block_library == null:
		push_error("❌ Не удалось загрузить библиотеку: ", block_library_path)
		return
	
	var models: Array = _block_library.models
	print("\n========== БЛОКИ В БИБЛИОТЕКЕ ==========")
	for i in range(models.size()):
		var model = models[i]
		if model == null:
			print("  [", i, "] <null>")
			continue
		var name = model.resource_name
		if name == "":
			name = model.resource_path.get_file().get_basename()
		name = name.to_lower()
		_block_name_to_id[name] = i
		print("  [", i, "] ", name)
	print("========================================\n")

func load_blocks_from_directory() -> void:
	var dir = DirAccess.open(blocks_directory)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir() and file_name != "." and file_name != "..":
				var folder_name = file_name
				var block_path = blocks_directory + folder_name + "/"
				var texture_path = block_path + folder_name + ".png"
				if FileAccess.file_exists(texture_path):
					var texture = load(texture_path)
					if texture:
						# Сначала проверяем ручное сопоставление
						var block_id = custom_block_mapping.get(folder_name, -1)
						if block_id == -1:
							# Пробуем автоматическое по имени папки
							var folder_lower = folder_name.to_lower()
							block_id = _block_name_to_id.get(folder_lower, -1)
						
						if block_id == -1:
							print("⚠️ Блок '", folder_name, "' не сопоставлен! ID = -1 (нельзя поставить)")
						else:
							print("✓ Блок '", folder_name, "' → ID ", block_id)
						
						available_blocks.append({
							"id": block_id,
							"name": folder_name,
							"texture": texture,
							"path": block_path
						})
					else:
						print("❌ Не удалось загрузить текстуру: ", texture_path)
				else:
					print("❌ Файл текстуры не найден: ", texture_path)
			file_name = dir.get_next()
	else:
		print("❌ Ошибка открытия папки: ", blocks_directory, ". Проверьте путь.")
	
	if available_blocks.is_empty():
		print("⚠️ ВНИМАНИЕ: В креативном меню нет блоков.")

func _input(event: InputEvent) -> void:
	if inventory_open and not (event is InputEventKey and (event.keycode == KEY_E or event.keycode == KEY_ESCAPE or (event.keycode >= KEY_1 and event.keycode <= KEY_9))):
		return

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		neck.rotate_x(-event.relative.y * mouse_sensitivity)
		neck.rotation.x = clamp(neck.rotation.x, -PI/2, PI/2)

	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	if event is InputEventKey and event.keycode == KEY_E and event.pressed:
		toggle_inventory()
	
	if inventory_open and event is InputEventKey and event.pressed and not event.echo:
		var slot_index = _key_to_slot(event.keycode)
		if slot_index != -1 and not hovered_block.is_empty():
			hotbar_items[slot_index] = hovered_block
			update_hotbar_icon(slot_index)
			hotbar_updated.emit(slot_index)
			set_selected_slot(slot_index)
			print("Блок ", hovered_block.name, " (ID: ", hovered_block.id, ") помещён в слот ", slot_index + 1)
	
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

func _physics_process(delta: float) -> void:
	if inventory_open:
		return
	
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var current_speed = sprint_speed if Input.is_action_pressed("sprint") else move_speed

	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	move_and_slide()

func create_ui() -> void:
	canvas_layer = CanvasLayer.new()
	add_child(canvas_layer)
	create_crosshair()
	create_hotbar()
	create_inventory()

func create_crosshair() -> void:
	var crosshair = Control.new()
	crosshair.name = "Crosshair"
	crosshair.anchor_left = 0.0
	crosshair.anchor_top = 0.0
	crosshair.anchor_right = 1.0
	crosshair.anchor_bottom = 1.0
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_layer.add_child(crosshair)
	
	var h_line = ColorRect.new()
	h_line.color = Color.WHITE
	h_line.anchor_left = 0.5
	h_line.anchor_top = 0.5
	h_line.anchor_right = 0.5
	h_line.anchor_bottom = 0.5
	h_line.offset_left = -10
	h_line.offset_top = -1
	h_line.offset_right = 10
	h_line.offset_bottom = 1
	crosshair.add_child(h_line)
	
	var v_line = ColorRect.new()
	v_line.color = Color.WHITE
	v_line.anchor_left = 0.5
	v_line.anchor_top = 0.5
	v_line.anchor_right = 0.5
	v_line.anchor_bottom = 0.5
	v_line.offset_left = -1
	v_line.offset_top = -10
	v_line.offset_right = 1
	v_line.offset_bottom = 10
	crosshair.add_child(v_line)

func create_hotbar() -> void:
	var bar_width := HOTBAR_SLOTS * SLOT_SIZE + (HOTBAR_SLOTS - 1) * SLOT_MARGIN
	var bar_height := SLOT_SIZE + SLOT_MARGIN * 2
	
	var hotbar_bg = Panel.new()
	hotbar_bg.name = "HotbarBackground"
	hotbar_bg.anchor_left = 0.5
	hotbar_bg.anchor_top = 1.0
	hotbar_bg.anchor_right = 0.5
	hotbar_bg.anchor_bottom = 1.0
	hotbar_bg.offset_left = -bar_width / 2
	hotbar_bg.offset_top = -bar_height
	hotbar_bg.offset_right = bar_width / 2
	hotbar_bg.offset_bottom = 0
	hotbar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.7)
	bg_style.border_width_top = 2
	bg_style.border_width_bottom = 2
	bg_style.border_width_left = 2
	bg_style.border_width_right = 2
	bg_style.border_color = Color(0.4, 0.4, 0.4)
	hotbar_bg.add_theme_stylebox_override("panel", bg_style)
	canvas_layer.add_child(hotbar_bg)
	
	var hbox = HBoxContainer.new()
	hbox.name = "SlotContainer"
	hbox.anchor_left = 0.0
	hbox.anchor_top = 0.0
	hbox.anchor_right = 1.0
	hbox.anchor_bottom = 1.0
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hotbar_bg.add_child(hbox)
	
	var slot_style_normal = _create_slot_style(Color(0.5, 0.5, 0.5))
	var slot_style_selected = _create_slot_style(Color.WHITE)
	
	for i in HOTBAR_SLOTS:
		var slot_btn = Button.new()
		slot_btn.name = "Slot" + str(i + 1)
		slot_btn.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		slot_btn.add_theme_stylebox_override("normal", slot_style_normal)
		slot_btn.add_theme_stylebox_override("hover", slot_style_normal)
		slot_btn.add_theme_stylebox_override("pressed", slot_style_normal)
		slot_btn.add_theme_stylebox_override("disabled", slot_style_normal)
		slot_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		hbox.add_child(slot_btn)
		hotbar_slots.append(slot_btn)
		
		var icon = TextureRect.new()
		icon.name = "Icon"
		icon.custom_minimum_size = Vector2(SLOT_SIZE - 8, SLOT_SIZE - 8)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.hide()
		slot_btn.add_child(icon)
		hotbar_icons.append(icon)
	
	update_slot_selection(0)

func _create_slot_style(border_color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = border_color
	return style

func update_slot_selection(index: int) -> void:
	var normal_style = _create_slot_style(Color(0.5, 0.5, 0.5))
	var selected_style = _create_slot_style(Color.WHITE)
	for i in hotbar_slots.size():
		hotbar_slots[i].add_theme_stylebox_override("normal", selected_style if i == index else normal_style)

func set_selected_slot(index: int) -> void:
	if index < 0 or index >= hotbar_slots.size():
		return
	selected_slot = index
	update_slot_selection(index)
	selected_block = hotbar_items[index] if hotbar_items[index] != null else {}
	selected_slot_changed.emit(index)
	print("Выбран слот: ", index + 1, ", блок: ", selected_block.get("name", "пусто"), " (ID: ", selected_block.get("id", "?"), ")")

func select_next_slot() -> void:
	set_selected_slot((selected_slot + 1) % hotbar_slots.size())

func select_previous_slot() -> void:
	set_selected_slot((selected_slot - 1 + hotbar_slots.size()) % hotbar_slots.size())

func update_hotbar_icon(index: int) -> void:
	if index < 0 or index >= hotbar_items.size():
		return
	var item = hotbar_items[index]
	var icon = hotbar_icons[index]
	if item and item.has("texture"):
		icon.texture = item.texture
		icon.show()
	else:
		icon.hide()

func get_selected_block_info() -> Dictionary:
	return selected_block.duplicate()

func create_inventory() -> void:
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
		slot_button.custom_minimum_size = Vector2(36, 36)
		slot_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		slot_button.tooltip_text = block.name
		
		var btn_style_normal = _create_inventory_slot_style(Color(0.5, 0.5, 0.5))
		var btn_style_hover = _create_inventory_slot_style(Color.WHITE)
		slot_button.add_theme_stylebox_override("normal", btn_style_normal)
		slot_button.add_theme_stylebox_override("hover", btn_style_hover)
		
		var texture_rect = TextureRect.new()
		texture_rect.texture = block.texture
		texture_rect.custom_minimum_size = Vector2(28, 28)
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_button.add_child(texture_rect)
		
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

func toggle_inventory() -> void:
	inventory_open = !inventory_open
	if inventory_open:
		inventory_panel.show()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		inventory_panel.hide()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		hovered_block = {}

func _on_inventory_slot_mouse_entered(block: Dictionary) -> void:
	hovered_block = block
	print("Наведён блок: ", block.name, " (ID: ", block.id, ")")

func _on_inventory_slot_mouse_exited() -> void:
	hovered_block = {}
