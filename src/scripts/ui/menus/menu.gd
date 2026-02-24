extends Control

# Путь к вашей основной игровой сцене (измените при необходимости)
const GAME_SCENE := "res://src/scenes/testing/LodScene.tscn"

func _ready() -> void:
	# 1. Тёмный фон на весь экран
	var background = ColorRect.new()
	background.color = Color(0.1, 0.1, 0.2)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	# 2. Создаём вертикальный контейнер для заголовка и кнопок
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)  # Центрируем на экране
	vbox.size = Vector2(300, 250)                  # Фиксированный размер
	add_child(vbox)

	# 3. Заголовок
	var title = Label.new()
	title.text = "Моя Игра"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	vbox.add_child(title)

	# 4. Добавляем немного пустого пространства между заголовком и кнопками
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(spacer)

	# 5. Кнопка "Новая игра"
	var new_game_btn = Button.new()
	new_game_btn.text = "Новая игра"
	new_game_btn.pressed.connect(_on_new_game_pressed)
	vbox.add_child(new_game_btn)

	# 6. Кнопка "Настройки"
	var settings_btn = Button.new()
	settings_btn.text = "Настройки"
	settings_btn.pressed.connect(_on_settings_pressed)
	vbox.add_child(settings_btn)

	# 7. Кнопка "Выход"
	var exit_btn = Button.new()
	exit_btn.text = "Выход"
	exit_btn.pressed.connect(_on_exit_pressed)
	vbox.add_child(exit_btn)

func _on_new_game_pressed() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://src/scenes/ui/SettingsMenu.tscn")

func _on_exit_pressed() -> void:
	get_tree().quit()
