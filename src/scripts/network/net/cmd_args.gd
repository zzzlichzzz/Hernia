class_name CmdArgs
## Утилита для разбора аргументов командной строки.
##
## Godot передаёт пользовательские аргументы после "--":
##   godot --headless -- --port 8080 --max-clients 16
##
## OS.get_cmdline_user_args()  →  ["--port", "8080", "--max-clients", "16"]

var _args: Dictionary = {}   # "--port" → "8080"
var _flags: Array     = []   # ["--verbose"] (без значения)


func _init() -> void:
	_parse(OS.get_cmdline_user_args())


## Разобрать массив аргументов.
func _parse(raw: PackedStringArray) -> void:
	var i := 0
	while i < raw.size():
		var arg: String = raw[i]
		if arg.begins_with("--"):
			# Следующий элемент — значение? (не начинается с --)
			if i + 1 < raw.size() and not raw[i + 1].begins_with("--"):
				_args[arg] = raw[i + 1]
				i += 2
			else:
				# Флаг без значения
				_flags.append(arg)
				i += 1
		else:
			i += 1


## Получить значение аргумента. Вернёт default если не найден.
func get_string(key: String, default: String = "") -> String:
	if key in _args:
		return _args[key]
	return default


## Получить целое число.
func get_int(key: String, default: int = 0) -> int:
	if key in _args:
		if (_args[key] as String).is_valid_int():
			return int(_args[key])
		push_warning("CmdArgs: '%s' не число: %s" % [key, _args[key]])
	return default


## Получить float.
func get_float(key: String, default: float = 0.0) -> float:
	if key in _args:
		if (_args[key] as String).is_valid_float():
			return float(_args[key])
	return default


## Проверить наличие флага (аргумент без значения).
func has_flag(key: String) -> bool:
	return key in _flags


## Проверить наличие аргумента (с или без значения).
func has(key: String) -> bool:
	return key in _args or key in _flags


## Вывести все разобранные аргументы (для отладки).
func print_all() -> void:
	print("[cmd] Аргументы: %s" % str(_args))
	print("[cmd] Флаги:     %s" % str(_flags))


## Проверить, запущен ли Godot в headless-режиме.
static func is_headless() -> bool:
	return DisplayServer.get_name() == "headless"
