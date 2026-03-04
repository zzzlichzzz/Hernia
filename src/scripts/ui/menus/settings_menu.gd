extends Control

# Путь к файлу конфигурации (должен совпадать с путём в VoxelTerrain)
const CONFIG_PATH := "user://voxel_settings.cfg"

# Ссылки на элементы интерфейса
var view_distance_slider: HSlider
var view_distance_label: Label
var collisions_checkbox: CheckBox
var gpu_checkbox: CheckBox
var vsync_checkbox: CheckBox
var fov_slider: HSlider
var fov_label: Label
var sensitivity_slider: HSlider
var sensitivity_label: Label

# Текущие значения настроек (локальные)
var current_view_distance: int = 256
var current_collisions: bool = true
var current_gpu: bool = false
var current_vsync: bool = true
var current_fov: int = 75
var current_sensitivity: float = 0.5

func _ready():
	# Создаём интерфейс
	create_ui()
	
	# Загружаем настройки из файла
	load_settings()
	
	# Подключаем сигналы
	if view_distance_slider:
		view_distance_slider.value_changed.connect(_on_view_distance_changed)
	if collisions_checkbox:
		collisions_checkbox.toggled.connect(_on_collisions_toggled)
	if gpu_checkbox:
		gpu_checkbox.toggled.connect(_on_gpu_toggled)
	if vsync_checkbox:
		vsync_checkbox.toggled.connect(_on_vsync_toggled)
	if fov_slider:
		fov_slider.value_changed.connect(_on_fov_changed)
	if sensitivity_slider:
		sensitivity_slider.value_changed.connect(_on_sensitivity_changed)

func create_ui():
	# Полноэкранный контейнер
	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# Центрирующий контейнер
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	
	# Главный вертикальный контейнер
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(500, 0)
	vbox.size_flags_vertical = Control.PRESET_CENTER
	center.add_child(vbox)
	
	# Заголовок
	var title = Label.new()
	title.text = "НАСТРОЙКИ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	vbox.add_child(title)
	
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer1)
	
	# === ГРАФИКА ===
	var graphics_label = _create_section_label("ГРАФИКА")
	vbox.add_child(graphics_label)
	
	# Дистанция просмотра
	var hbox_dist = _create_setting_row("Дистанция:", "128")
	view_distance_slider = hbox_dist.get_node("Slider")
	view_distance_label = hbox_dist.get_node("Value")
	vbox.add_child(hbox_dist)
	
	# V-Sync
	vsync_checkbox = CheckBox.new()
	vsync_checkbox.text = "V-Sync (вертикальная синхронизация)"
	vsync_checkbox.button_pressed = current_vsync
	vsync_checkbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(vsync_checkbox)
	
	# GPU генерация
	gpu_checkbox = CheckBox.new()
	gpu_checkbox.text = "GPU генерация чанков"
	gpu_checkbox.button_pressed = current_gpu
	gpu_checkbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(gpu_checkbox)
	
	# Генерация коллизий
	collisions_checkbox = CheckBox.new()
	collisions_checkbox.text = "Генерировать коллизии"
	collisions_checkbox.button_pressed = current_collisions
	collisions_checkbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(collisions_checkbox)
	
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 15)
	vbox.add_child(spacer2)
	
	# === УПРАВЛЕНИЕ ===
	var controls_label = _create_section_label("УПРАВЛЕНИЕ")
	vbox.add_child(controls_label)
	
	# FOV
	var hbox_fov = _create_setting_row("Угол обзора (FOV):", "75")
	fov_slider = hbox_fov.get_node("Slider")
	fov_label = hbox_fov.get_node("Value")
	vbox.add_child(hbox_fov)
	
	# Чувствительность мыши
	var hbox_sens = _create_setting_row("Чувствительность:", "0.5")
	sensitivity_slider = hbox_sens.get_node("Slider")
	sensitivity_label = hbox_sens.get_node("Value")
	vbox.add_child(hbox_sens)
	
	var spacer3 = Control.new()
	spacer3.custom_minimum_size = Vector2(0, 25)
	vbox.add_child(spacer3)
	
	# Кнопки
	var hbox_buttons = HBoxContainer.new()
	hbox_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox_buttons)
	
	var save_btn = _create_menu_button("СОХРАНИТЬ", Color(0.3, 0.7, 0.3))
	save_btn.pressed.connect(_on_save_pressed)
	hbox_buttons.add_child(save_btn)
	
	var spacer_btn = Control.new()
	spacer_btn.custom_minimum_size = Vector2(20, 0)
	hbox_buttons.add_child(spacer_btn)
	
	var back_btn = _create_menu_button("НАЗАД", Color(0.7, 0.3, 0.3))
	back_btn.pressed.connect(_on_back_pressed)
	hbox_buttons.add_child(back_btn)

func _create_section_label(text: String) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	return label

func _create_setting_row(label_text: String, default_value: String) -> HBoxContainer:
	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var label = Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)
	
	var value_label = Label.new()
	value_label.name = "Value"
	value_label.text = default_value
	value_label.custom_minimum_size = Vector2(50, 0)
	value_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	hbox.add_child(value_label)
	
	var slider = HSlider.new()
	slider.name = "Slider"
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(slider)
	
	return hbox

func _create_menu_button(text: String, color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(150, 45)
	
	var style = StyleBoxFlat.new()
	style.bg_color = color.darkened(0.6)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = color
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("normal", style)
	
	var style_hover = style.duplicate()
	style_hover.bg_color = color.darkened(0.3)
	btn.add_theme_stylebox_override("hover", style_hover)
	
	btn.add_theme_font_size_override("font_size", 14)
	
	return btn

func _on_view_distance_changed(value: float):
	current_view_distance = int(value)
	if view_distance_label:
		view_distance_label.text = str(current_view_distance)

func _on_collisions_toggled(enabled: bool):
	current_collisions = enabled

func _on_gpu_toggled(enabled: bool):
	current_gpu = enabled

func _on_vsync_toggled(enabled: bool):
	current_vsync = enabled

func _on_fov_changed(value: float):
	current_fov = int(value)
	if fov_label:
		fov_label.text = str(current_fov)

func _on_sensitivity_changed(value: float):
	current_sensitivity = value
	if sensitivity_label:
		sensitivity_label.text = "%.2f" % current_sensitivity

func _on_save_pressed():
	save_settings()

func _on_back_pressed():
	get_tree().change_scene_to_file("res://src/scenes/ui/Menu.tscn")

func save_settings():
	var config = ConfigFile.new()
	# Сохраняем в секцию graphics (для совместимости)
	config.set_value("graphics", "max_view_distance", current_view_distance)
	config.set_value("graphics", "vsync", current_vsync)
	config.set_value("graphics", "use_gpu_generation", current_gpu)
	config.set_value("graphics", "generate_collisions", current_collisions)
	config.set_value("graphics", "fov", current_fov)
	config.set_value("controls", "sensitivity", current_sensitivity)
	# Сохраняем в секцию voxel (для VoxelTerrain)
	config.set_value("voxel", "max_view_distance", current_view_distance)
	config.set_value("voxel", "generate_collisions", current_collisions)
	config.set_value("voxel", "use_gpu_generation", current_gpu)
	
	var err = config.save(CONFIG_PATH)
	if err == OK:
		print("Настройки сохранены")
		# Применяем настройки к VoxelTerrain
		apply_voxel_settings()
		# Применяем V-Sync
		if current_vsync:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
		else:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	else:
		print("Ошибка сохранения настроек: ", err)

func apply_voxel_settings():
	# Находим VoxelTerrain и применяем настройки
	var voxel_terrain = get_tree().get_first_node_in_group("voxel_terrain")
	if voxel_terrain:
		voxel_terrain.max_view_distance = current_view_distance
		voxel_terrain.generate_collisions = current_collisions
		voxel_terrain.use_gpu_generation = current_gpu
		print("Применены настройки VoxelTerrain: view_distance=", current_view_distance)
	else:
		print("VoxelTerrain не найден, настройки будут применены при загрузке мира")

func load_settings():
	var config = ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return
	
	# Читаем настройки графики
	# Используем null как sentinel для определения, было ли считано значение
	var loaded_view = config.get_value("voxel", "max_view_distance", null)
	if loaded_view == null:
		loaded_view = config.get_value("graphics", "max_view_distance", 256)
	current_view_distance = loaded_view
	
	var loaded_gpu = config.get_value("voxel", "use_gpu_generation", null)
	if loaded_gpu == null:
		loaded_gpu = config.get_value("graphics", "use_gpu_generation", true)
	current_gpu = loaded_gpu
	
	var loaded_collisions = config.get_value("voxel", "generate_collisions", null)
	if loaded_collisions == null:
		loaded_collisions = config.get_value("graphics", "generate_collisions", true)
	current_collisions = loaded_collisions
	
	current_vsync = config.get_value("graphics", "vsync", current_vsync)
	current_fov = config.get_value("graphics", "fov", current_fov)
	
	# Читаем настройки управления
	current_sensitivity = config.get_value("controls", "sensitivity", current_sensitivity)
	
	# Обновляем UI
	if view_distance_slider:
		view_distance_slider.min_value = 16
		view_distance_slider.max_value = 2048
		view_distance_slider.step = 16
		view_distance_slider.value = current_view_distance
	if view_distance_label:
		view_distance_label.text = str(current_view_distance)
	if vsync_checkbox:
		vsync_checkbox.button_pressed = current_vsync
	if gpu_checkbox:
		gpu_checkbox.button_pressed = current_gpu
	if collisions_checkbox:
		collisions_checkbox.button_pressed = current_collisions
	if fov_slider:
		fov_slider.min_value = 50
		fov_slider.max_value = 120
		fov_slider.step = 5
		fov_slider.value = current_fov
	if fov_label:
		fov_label.text = str(current_fov)
	if sensitivity_slider:
		sensitivity_slider.min_value = 0.1
		sensitivity_slider.max_value = 2.0
		sensitivity_slider.step = 0.05
		sensitivity_slider.value = current_sensitivity
	if sensitivity_label:
		sensitivity_label.text = "%.2f" % current_sensitivity
