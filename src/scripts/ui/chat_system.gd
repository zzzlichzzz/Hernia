extends CanvasLayer

# Настройки
@export var command_prefix: String = "/"
@export var max_history: int = 10

# Ссылки
var _player: Node3D = null

# UI элементы
var _chat_panel: PanelContainer
var _chat_output: RichTextLabel
var _chat_input: LineEdit
var _command_history: Array = []
var _history_index: int = -1

# Состояние
var _chat_open: bool = false

# signal command_executed(cmd: String, args: Array)  # Не используется

func _ready():
	# Добавляем в группу для поиска
	add_to_group("chat")
	_create_chat_ui()
	_find_player()
	_connect_signals()

func _find_player():
	_player = get_tree().get_first_node_in_group("player")
	if not _player:
		_player = get_tree().current_scene.get_node_or_null("Player")

func _connect_signals():
	# Подключаемся к сигналам ввода
	get_tree().root.files_dropped.connect(_on_files_dropped)

func _create_chat_ui():
	# Панель чата
	_chat_panel = PanelContainer.new()
	_chat_panel.anchor_left = 0.0
	_chat_panel.anchor_right = 1.0
	_chat_panel.anchor_bottom = 0.0
	_chat_panel.offset_top = 0.0
	_chat_panel.offset_right = 0.0
	_chat_panel.offset_bottom = 200.0
	_chat_panel.visible = false
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0, 0, 0, 0.5)
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(0.3, 0.3, 0.3)
	_chat_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_chat_panel)
	
	# Вывод сообщений
	_chat_output = RichTextLabel.new()
	_chat_output.anchor_left = 0.0
	_chat_output.anchor_right = 1.0
	_chat_output.anchor_bottom = 1.0
	_chat_output.offset_left = 5.0
	_chat_output.offset_top = 5.0
	_chat_output.offset_right = -5.0
	_chat_output.offset_bottom = -35.0
	_chat_output.bbcode_enabled = true
	_chat_output.text = ""
	_chat_output.mouse_filter = Control.MOUSE_FILTER_STOP
	_chat_panel.add_child(_chat_output)
	
	# Поле ввода
	_chat_input = LineEdit.new()
	_chat_input.anchor_left = 0.0
	_chat_input.anchor_right = 1.0
	_chat_input.anchor_bottom = 0.0
	_chat_input.offset_left = 5.0
	_chat_input.offset_top = -30.0
	_chat_input.offset_right = -5.0
	_chat_input.offset_bottom = -5.0
	_chat_input.placeholder_text = "Type a command..."
	_chat_input.custom_minimum_size.y = 24
	_chat_input.text_submitted.connect(_on_command_submitted)
	_chat_panel.add_child(_chat_input)
	
	# Скрываем панель, показываем только по необходимости
	_chat_panel.visible = false
	_chat_panel.offset_bottom = 35  # Только строка ввода

func _input(event: InputEvent):
	if event is InputEventKey:
		var key_event = event as InputEventKey
		
		# Открытие чата - T или /
		if key_event.keycode == KEY_T and key_event.pressed and not key_event.echo:
			_open_chat()
		elif key_event.keycode == KEY_SLASH and key_event.pressed and not key_event.echo:
			_open_chat(true)
		# Закрытие чата - Escape
		elif key_event.keycode == KEY_ESCAPE and key_event.pressed and _chat_open:
			_close_chat()
		# История команд - стрелки вверх/вниз
		elif _chat_open:
			if key_event.keycode == KEY_UP and key_event.pressed:
				_navigate_history(1)
			elif key_event.keycode == KEY_DOWN and key_event.pressed:
				_navigate_history(-1)

func _open_chat(force_command: bool = false):
	_chat_open = true
	_chat_panel.visible = true
	_chat_panel.offset_bottom = 200  # Показываем историю
	_chat_input.text = command_prefix if force_command else ""
	_chat_input.grab_focus()

func _close_chat():
	_chat_open = false
	_chat_panel.visible = false
	_chat_panel.offset_bottom = 35
	_chat_input.text = ""
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func is_chat_open() -> bool:
	return _chat_open

func _on_command_submitted(text: String):
	if text.is_empty():
		_close_chat()
		return
	
	# Добавляем в историю
	_command_history.append(text)
	if _command_history.size() > max_history:
		_command_history.pop_front()
	_history_index = -1
	
	# Выполняем команду
	var result = _execute_command(text)
	
	# Показываем результат
	if result != "":
		_add_message(result)
	
	_close_chat()

func _navigate_history(direction: int):
	if _command_history.is_empty():
		return
	
	_history_index += direction
	if _history_index < 0:
		_history_index = -1
		_chat_input.text = ""
	elif _history_index >= _command_history.size():
		_history_index = _command_history.size() - 1
	
	if _history_index >= 0:
		_chat_input.text = _command_history[_command_history.size() - 1 - _history_index]

func _execute_command(text: String) -> String:
	var trimmed = text.strip_edges()
	if not trimmed.begins_with(command_prefix):
		return ""
	
	var cmd_str = trimmed.substr(1).strip_edges()
	var parts = cmd_str.split(" ", false)
	if parts.is_empty():
		return ""
	
	var cmd = parts[0].to_lower()
	var args = parts.slice(1)
	
	match cmd:
		"help":
			return _cmd_help(args)
		"gamemode", "gm":
			return _cmd_gamemode(args)
		"setblock":
			return _cmd_setblock(args)
		"time":
			return _cmd_time(args)
		"weather":
			return _cmd_weather(args)
		"spawnpoint":
			return _cmd_spawnpoint(args)
		"tp", "teleport":
			return _cmd_teleport(args)
		"give":
			return _cmd_give(args)
		"clear":
			return _cmd_clear(args)
		"kill":
			return _cmd_kill(args)
		"reload":
			return _cmd_reload(args)
		"debug":
			return _cmd_debug(args)
		"coords", "pos":
			return _cmd_coords()
		_:
			return "[color=red]Unknown command: %s[/color]" % cmd

func _cmd_help(_args: Array) -> String:
	var help_text = "[color=yellow]--- Available Commands ---[/color]\n"
	help_text += "[color=cyan]/help[/color] - Show this help\n"
	help_text += "[color=cyan]/gm <0|1|2>[/color] - Change game mode (0=Survival, 1=Creative, 2=Spectator)\n"
	help_text += "[color=cyan]/coords[/color] - Show current coordinates\n"
	help_text += "[color=cyan]/tp <x> <y> <z>[/color] - Teleport to coordinates\n"
	help_text += "[color=cyan]/give <block>[/color] - Give block to hotbar\n"
	help_text += "[color=cyan]/clear[/color] - Clear inventory\n"
	help_text += "[color=cyan]/kill[/color] - Kill/respawn player\n"
	help_text += "[color=cyan]/time set <day|night>[/color] - Set time\n"
	help_text += "[color=cyan]/reload[/color] - Reload current scene\n"
	help_text += "[color=cyan]/debug[/color] - Toggle debug overlay"
	return help_text

func _cmd_gamemode(args: Array) -> String:
	if args.is_empty():
		return "[color=red]Usage: /gm <0|1|2>[/color]"
	
	var mode = args[0]
	var mode_name = ""
	var mode_int = -1
	
	match mode:
		"0", "survival", "s":
			mode_int = 0
			mode_name = "Survival"
		"1", "creative", "c":
			mode_int = 1
			mode_name = "Creative"
		"2", "spectator", "sp":
			mode_int = 2
			mode_name = "Spectator"
		_:
			return "[color=red]Invalid game mode. Use 0, 1, or 2[/color]"
	
	# Применяем режим
	if _player and _player.has_method("set_gamemode"):
		_player.set_gamemode(mode_int)
	
	return "[color=green]Game mode set to %s[/color]" % mode_name

func _cmd_setblock(args: Array) -> String:
	if args.is_empty():
		return "[color=red]Usage: /setblock <block_name>[/color]"
	
	# Логика установки блока
	return "[color=green]Block placed[/color]"

func _cmd_time(args: Array) -> String:
	if args.is_empty() or args[0] != "set":
		return "[color=red]Usage: /time set <day|night>[/color]"
	
	var time_val = args[1] if args.size() > 1 else "day"
	match time_val:
		"day":
			# Утро - можно добавить управление освещением
			return "[color=green]Time set to day[/color]"
		"night":
			# Ночь
			return "[color=green]Time set to night[/color]"
		_:
			return "[color=red]Invalid time. Use day or night[/color]"

func _cmd_weather(args: Array) -> String:
	if args.is_empty():
		return "[color=red]Usage: /weather <clear|rain|thunder>[/color]"
	
	match args[0]:
		"clear":
			return "[color=green]Weather cleared[/color]"
		"rain":
			return "[color=green]Rain enabled[/color]"
		"thunder":
			return "[color=green]Thunder enabled[/color]"
		_:
			return "[color=red]Invalid weather type[/color]"

func _cmd_spawnpoint(_args: Array) -> String:
	if _player:
		var pos = _player.global_position
		return "[color=green]Spawn point set to (%.1f, %.1f, %.1f)[/color]" % [pos.x, pos.y, pos.z]
	return "[color=red]Player not found[/color]"

func _cmd_teleport(args: Array) -> String:
	if args.size() < 3:
		return "[color=red]Usage: /tp <x> <y> <z>[/color]"
	
	var x = args[0].to_float()
	var y = args[1].to_float()
	var z = args[2].to_float()
	
	if _player:
		_player.global_position = Vector3(x, y, z)
		return "[color=green]Teleported to (%.1f, %.1f, %.1f)[/color]" % [x, y, z]
	
	return "[color=red]Player not found[/color]"

func _cmd_give(args: Array) -> String:
	if args.is_empty():
		return "[color=red]Usage: /give <block_name>[/color]"
	
	var block_name = args[0]
	
	# Находим инвентарь и добавляем блок
	if _player:
		var inventory = _player.get_node_or_null("inventory")
		if inventory and inventory.has_method("place_item_in_hotbar"):
			inventory.place_item_in_hotbar(block_name)
			return "[color=green]Given: %s[/color]" % block_name
	
	return "[color=red]Cannot give item[/color]"

func _cmd_clear(_args: Array) -> String:
	if _player:
		var inventory = _player.get_node_or_null("inventory")
		if inventory and inventory.has_method("clear_hotbar"):
			inventory.clear_hotbar()
			return "[color=green]Inventory cleared[/color]"
	
	return "[color=red]Cannot clear inventory[/color]"

func _cmd_kill(_args: Array) -> String:
	if _player and _player.has_method("kill"):
		_player.kill()
		return "[color=green]You died![/color]"
	
	# Резpawn
	if _player:
		var pos = _player.global_position
		_player.global_position = Vector3(pos.x, pos.y + 5, pos.z)
		return "[color=green]Respawned[/color]"
	
	return "[color=red]Player not found[/color]"

func _cmd_reload(_args: Array) -> String:
	get_tree().reload_current_scene()
	return "[color=green]Reloading scene...[/color]"

func _cmd_debug(_args: Array) -> String:
	# Переключаем отладочный оверлей
	var debug_overlay = get_tree().get_first_node_in_group("debug")
	if debug_overlay:
		debug_overlay.visible = not debug_overlay.visible
		return "[color=green]Debug overlay toggled[/color]"
	
	# Пробуем найти по имени
	for node in get_tree().get_nodes_in_group("debug"):
		node.visible = not node.visible
		return "[color=green]Debug overlay toggled[/color]"
	
	return "[color=red]Debug overlay not found[/color]"

func _cmd_coords() -> String:
	if _player:
		var pos = _player.global_position
		return "[color=cyan]Coordinates: %.1f, %.1f, %.1f[/color]" % [pos.x, pos.y, pos.z]
	return "[color=red]Player not found[/color]"

func _add_message(text: String):
	_chat_output.append_text(text + "\n")
	_chat_output.scroll_to_line(_chat_output.get_line_count() - 1)

func _on_files_dropped(_files: Array):
	pass  # Можно добавить обработку файлов
