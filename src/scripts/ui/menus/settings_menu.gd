extends Control

const CONFIG_PATH := "user://voxel_settings.cfg"

var view_distance_slider: HSlider
var view_distance_label: Label
var collisions_checkbox: CheckBox
var gpu_checkbox: CheckBox
var vsync_checkbox: CheckBox
var fov_slider: HSlider
var fov_label: Label
var sensitivity_slider: HSlider
var sensitivity_label: Label
var current_view_distance: int = 256
var current_collisions: bool = true
var current_gpu: bool = false
var current_vsync: bool = true
var current_fov: int = 75
var current_sensitivity: float = 0.5

func _ready():
	create_ui()
	load_settings()
	_connect_signals()

func create_ui():
	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(500, 0)
	vbox.size_flags_vertical = Control.PRESET_CENTER
	center.add_child(vbox)
	
	var title = Label.new()
	title.text = "НАСТРОЙКИ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	vbox.add_child(title)
	vbox.add_child(_spacer(20))
	
	vbox.add_child(_section_label("ГРАФИКА"))
	var hbox_dist = _setting_row("Дистанция:", "128")
	view_distance_slider = hbox_dist.get_node("Slider")
	view_distance_label = hbox_dist.get_node("Value")
	vbox.add_child(hbox_dist)
	
	vsync_checkbox = _checkbox("V-Sync", current_vsync)
	gpu_checkbox = _checkbox("GPU генерация", current_gpu)
	vbox.add_child(vsync_checkbox)
	vbox.add_child(gpu_checkbox)
	vbox.add_child(_spacer(15))
	
	vbox.add_child(_section_label("УПРАВЛЕНИЕ"))
	var hbox_fov = _setting_row("FOV:", "75")
	fov_slider = hbox_fov.get_node("Slider")
	fov_label = hbox_fov.get_node("Value")
	vbox.add_child(hbox_fov)
	
	var hbox_sens = _setting_row("Чувствительность:", "0.5")
	sensitivity_slider = hbox_sens.get_node("Slider")
	sensitivity_label = hbox_sens.get_node("Value")
	vbox.add_child(hbox_sens)
	vbox.add_child(_spacer(25))
	
	var hbox_buttons = HBoxContainer.new()
	hbox_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox_buttons)
	hbox_buttons.add_child(_button("СОХРАНИТЬ", Color(0.3, 0.7, 0.3), _on_save_pressed))
	hbox_buttons.add_child(_spacer_x(20))
	hbox_buttons.add_child(_button("НАЗАД", Color(0.7, 0.3, 0.3), _on_back_pressed))

func _spacer(h: int) -> Control:
	var c = Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

func _spacer_x(w: int) -> Control:
	var c = Control.new()
	c.custom_minimum_size = Vector2(w, 0)
	return c

func _section_label(text: String) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	return l

func _setting_row(label_text: String, default_value: String) -> HBoxContainer:
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

func _checkbox(text: String, checked: bool) -> CheckBox:
	var cb = CheckBox.new()
	cb.text = text
	cb.button_pressed = checked
	cb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return cb

func _button(text: String, color: Color, callback: Callable) -> Button:
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
	btn.pressed.connect(callback)
	return btn

func _connect_signals():
	if view_distance_slider: view_distance_slider.value_changed.connect(_on_view_distance_changed)
	if gpu_checkbox: gpu_checkbox.toggled.connect(func(v): current_gpu = v)
	if vsync_checkbox: vsync_checkbox.toggled.connect(func(v): current_vsync = v)
	if fov_slider: fov_slider.value_changed.connect(_on_fov_changed)
	if sensitivity_slider: sensitivity_slider.value_changed.connect(_on_sensitivity_changed)

func _on_view_distance_changed(value: float):
	current_view_distance = int(value)
	if view_distance_label: view_distance_label.text = str(current_view_distance)

func _on_fov_changed(value: float):
	current_fov = int(value)
	if fov_label: fov_label.text = str(current_fov)

func _on_sensitivity_changed(value: float):
	current_sensitivity = value
	if sensitivity_label: sensitivity_label.text = "%.2f" % current_sensitivity

func _on_save_pressed():
	save_settings()

func _on_back_pressed():
	get_tree().change_scene_to_file("res://src/scenes/ui/Menu.tscn")

func save_settings():
	var config = ConfigFile.new()
	config.set_value("graphics", "max_view_distance", current_view_distance)
	config.set_value("graphics", "vsync", current_vsync)
	config.set_value("graphics", "use_gpu_generation", current_gpu)
	config.set_value("graphics", "generate_collisions", current_collisions)
	config.set_value("graphics", "fov", current_fov)
	config.set_value("controls", "sensitivity", current_sensitivity)
	config.set_value("voxel", "max_view_distance", current_view_distance)
	config.set_value("voxel", "generate_collisions", current_collisions)
	config.set_value("voxel", "use_gpu_generation", current_gpu)
	
	if config.save(CONFIG_PATH) == OK:
		apply_voxel_settings()
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if current_vsync else DisplayServer.VSYNC_DISABLED)

func apply_voxel_settings():
	var vt = get_tree().get_first_node_in_group("voxel_terrain")
	if vt:
		vt.max_view_distance = current_view_distance
		vt.generate_collisions = current_collisions
		vt.use_gpu_generation = current_gpu

func load_settings():
	var config = ConfigFile.new()
	if config.load(CONFIG_PATH) != OK: return
	
	current_view_distance = config.get_value("voxel", "max_view_distance", config.get_value("graphics", "max_view_distance", 256))
	current_gpu = config.get_value("voxel", "use_gpu_generation", config.get_value("graphics", "use_gpu_generation", false))
	current_collisions = config.get_value("voxel", "generate_collisions", config.get_value("graphics", "generate_collisions", true))
	current_vsync = config.get_value("graphics", "vsync", current_vsync)
	current_fov = config.get_value("graphics", "fov", current_fov)
	current_sensitivity = config.get_value("controls", "sensitivity", current_sensitivity)
	
	_update_ui()

func _update_ui():
	if view_distance_slider:
		view_distance_slider.min_value = 16; view_distance_slider.max_value = 2048; view_distance_slider.step = 16; view_distance_slider.value = current_view_distance
	if view_distance_label: view_distance_label.text = str(current_view_distance)
	if vsync_checkbox: vsync_checkbox.button_pressed = current_vsync
	if gpu_checkbox: gpu_checkbox.button_pressed = current_gpu
	if fov_slider:
		fov_slider.min_value = 50; fov_slider.max_value = 120; fov_slider.step = 5; fov_slider.value = current_fov
	if fov_label: fov_label.text = str(current_fov)
	if sensitivity_slider:
		sensitivity_slider.min_value = 0.1; sensitivity_slider.max_value = 2.0; sensitivity_slider.step = 0.05; sensitivity_slider.value = current_sensitivity
	if sensitivity_label: sensitivity_label.text = "%.2f" % current_sensitivity
