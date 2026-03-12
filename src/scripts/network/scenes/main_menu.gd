extends Control

# Ссылки на кнопки
@onready var btn_server: Button = $CenterContainer/VBoxContainer/BtnServer
@onready var btn_client: Button = $CenterContainer/VBoxContainer/BtnClient
@onready var btn_evil_client: Button = $CenterContainer/VBoxContainer/BtnEvilClient
@onready var btn_exit: Button = $CenterContainer/VBoxContainer/ExitBtn

func _ready() -> void:
	# Подключаем сигналы кнопок
	btn_server.pressed.connect(_on_btn_server_pressed)
	btn_client.pressed.connect(_on_btn_client_pressed)
	btn_evil_client.pressed.connect(_on_btn_evil_client_pressed)
	btn_exit.pressed.connect(_on_btn_exit_pressed)

# Обработчик кнопки "Запустить сервер"
func _on_btn_server_pressed() -> void:
	print("Запуск сервера...")
	get_tree().change_scene_to_file("res://src/scripts/network/server_main.tscn")

# Обработчик кнопки "Присоединиться к серверу"
func _on_btn_client_pressed() -> void:
	print("Подключение к серверу...")
	get_tree().change_scene_to_file("res://src/scripts/network/client_main.tscn")

# Обработчик кнопки "Test Evil Client"
func _on_btn_evil_client_pressed() -> void:
	print("Запуск тестового evil клиента...")
	get_tree().change_scene_to_file("res://src/scripts/network/auto_tests/test_evil_client.tscn")

# Обработчик кнопки "Выход"
func _on_btn_exit_pressed() -> void:
	print("Выход из игры...")
	get_tree().quit()
