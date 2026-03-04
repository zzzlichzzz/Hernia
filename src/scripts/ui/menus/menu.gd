extends Control

# Путь к основной игровой сцене
const GAME_SCENE := "res://src/scenes/testing/LodScene.tscn"
const LOADING_SCREEN := "res://src/scenes/ui/LoadingScreen.tscn"

func _ready() -> void:
	# 1. Тёмный фон на весь экран
	var background = ColorRect.new()
	background.color = Color(0.05, 0.05, 0.1)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	# 2. Создаём вертикальный контейнер для заголовка и кнопок
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.size = Vector2(400, 300)
	vbox.add_theme_constant_override("separation", 20)
	add_child(vbox)

	# 3. Заголовок игры
	var title = Label.new()
	title.text = "HERNIA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	vbox.add_child(title)

	# Подзаголовок
	var subtitle = Label.new()
	subtitle.text = "Voxel Game Prototype"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(subtitle)

	# 4. Добавляем пространство
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(spacer)

	# 5. Кнопка "Новая игра"
	var new_game_btn = _create_button("Новая игра", Color(0.3, 0.7, 0.3))
	new_game_btn.pressed.connect(_on_new_game_pressed)
	vbox.add_child(new_game_btn)

	# 6. Кнопка "Настройки"
	var settings_btn = _create_button("Настройки", Color(0.3, 0.5, 0.7))
	settings_btn.pressed.connect(_on_settings_pressed)
	vbox.add_child(settings_btn)

	# 7. Кнопка "Выход"
	var exit_btn = _create_button("Выход", Color(0.7, 0.3, 0.3))
	exit_btn.pressed.connect(_on_exit_pressed)
	vbox.add_child(exit_btn)

	# 8. Версия
	var version = Label.new()
	version.text = "v0.1.0"
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version.add_theme_font_size_override("font_size", 12)
	version.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	vbox.add_child(version)

func _create_button(text: String, color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(200, 50)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	# Стиль кнопки
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = color.darkened(0.6)
	style_normal.border_width_left = 2
	style_normal.border_width_right = 2
	style_normal.border_width_top = 2
	style_normal.border_width_bottom = 2
	style_normal.border_color = color
	style_normal.corner_radius_top_left = 8
	style_normal.corner_radius_top_right = 8
	style_normal.corner_radius_bottom_left = 8
	style_normal.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("normal", style_normal)
	
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = color.darkened(0.3)
	style_hover.border_width_left = 2
	style_hover.border_width_right = 2
	style_hover.border_width_top = 2
	style_hover.border_width_bottom = 2
	style_hover.border_color = color.lightened(0.3)
	style_hover.corner_radius_top_left = 8
	style_hover.corner_radius_top_right = 8
	style_hover.corner_radius_bottom_left = 8
	style_hover.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("hover", style_hover)
	
	var style_pressed = StyleBoxFlat.new()
	style_pressed.bg_color = color.darkened(0.7)
	style_pressed.border_width_left = 2
	style_pressed.border_width_right = 2
	style_pressed.border_width_top = 2
	style_pressed.border_width_bottom = 2
	style_pressed.border_color = color
	style_pressed.corner_radius_top_left = 8
	style_pressed.corner_radius_top_right = 8
	style_pressed.corner_radius_bottom_left = 8
	style_pressed.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("pressed", style_pressed)
	
	btn.add_theme_font_size_override("font_size", 18)
	
	return btn

func _on_new_game_pressed() -> void:
	# Показываем загрузку и запускаем игру
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://src/scenes/ui/SettingsMenu.tscn")

func _on_exit_pressed() -> void:
	get_tree().quit()
