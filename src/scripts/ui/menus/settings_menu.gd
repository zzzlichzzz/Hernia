extends Control

# Путь к файлу конфигурации
const CONFIG_PATH := "user://voxel_settings.cfg"

# Ссылки на элементы интерфейса
var view_distance_slider: HSlider
var view_distance_label: Label
var collisions_checkbox: CheckBox
var gpu_checkbox: CheckBox

# Текущие значения настроек (локальные)
var current_view_distance: int = 128
var current_collisions: bool = true
var current_gpu: bool = false

func _ready():
	# Создаём интерфейс
	create_ui()

	# Загружаем настройки из файла
	load_settings()

	# Подключаем сигналы
	view_distance_slider.value_changed.connect(_on_view_distance_changed)
	collisions_checkbox.toggled.connect(_on_collisions_toggled)
	gpu_checkbox.toggled.connect(_on_gpu_toggled)

func create_ui():
	# Центрирующий контейнер
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# Главный вертикальный контейнер
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vbox.add_theme_constant_override("separation", 10)
	center.add_child(vbox)

	# Заголовок
	var title = Label.new()
	title.text = "Настройки Voxel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# --- Дистанция просмотра ---
	var hbox_dist = HBoxContainer.new()
	hbox_dist.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(hbox_dist)

	var label_dist = Label.new()
	label_dist.text = "Дистанция:"
	label_dist.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_dist.add_child(label_dist)

	view_distance_label = Label.new()
	view_distance_label.text = str(current_view_distance)
	view_distance_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	hbox_dist.add_child(view_distance_label)

	view_distance_slider = HSlider.new()
	view_distance_slider.min_value = 16
	view_distance_slider.max_value = 512
	view_distance_slider.step = 1
	view_distance_slider.value = current_view_distance
	view_distance_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(view_distance_slider)

	# --- Генерация коллизий ---
	collisions_checkbox = CheckBox.new()
	collisions_checkbox.text = "Генерировать коллизии"
	collisions_checkbox.button_pressed = current_collisions
	collisions_checkbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(collisions_checkbox)

	# --- GPU генерация ---
	gpu_checkbox = CheckBox.new()
	gpu_checkbox.text = "Использовать GPU генерацию"
	gpu_checkbox.button_pressed = current_gpu
	gpu_checkbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(gpu_checkbox)

	vbox.add_child(HSeparator.new())

	# Кнопки
	var hbox_buttons = HBoxContainer.new()
	hbox_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox_buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(hbox_buttons)

	var save_btn = Button.new()
	save_btn.text = "Сохранить"
	save_btn.pressed.connect(_on_save_pressed)
	hbox_buttons.add_child(save_btn)

	var back_btn = Button.new()
	back_btn.text = "Назад"
	back_btn.pressed.connect(_on_back_pressed)
	hbox_buttons.add_child(back_btn)

func _on_view_distance_changed(value: float):
	current_view_distance = int(value)
	view_distance_label.text = str(current_view_distance)

func _on_collisions_toggled(enabled: bool):
	current_collisions = enabled

func _on_gpu_toggled(enabled: bool):
	current_gpu = enabled

func _on_save_pressed():
	save_settings()

func _on_back_pressed():
	# Возвращаемся в главное меню (измените путь при необходимости)
	get_tree().change_scene_to_file("res://src/scenes/ui/menu.tscn")

func save_settings():
	var config = ConfigFile.new()
	config.set_value("voxel", "max_view_distance", current_view_distance)
	config.set_value("voxel", "generate_collisions", current_collisions)
	config.set_value("voxel", "use_gpu_generation", current_gpu)
	config.save(CONFIG_PATH)
	print("Настройки сохранены")

func load_settings():
	var config = ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return  # Используем значения по умолчанию (уже заданы)

	# Читаем из файла
	current_view_distance = config.get_value("voxel", "max_view_distance", current_view_distance)
	current_collisions = config.get_value("voxel", "generate_collisions", current_collisions)
	current_gpu = config.get_value("voxel", "use_gpu_generation", current_gpu)

	# Обновляем UI
	view_distance_slider.value = current_view_distance
	view_distance_label.text = str(current_view_distance)
	collisions_checkbox.button_pressed = current_collisions
	gpu_checkbox.button_pressed = current_gpu
