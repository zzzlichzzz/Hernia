extends Node

# Ссылка на скрипт взаимодействия с вокселями
@export var player_interaction_path: NodePath = "../PlayerInteraction"
@onready var _player_interaction: Node = get_node_or_null(player_interaction_path)

# Путь к библиотеке блоков
@export var library_path: String = "res://src/data/blocks/voxel_blocky_library.tres"

# Настройки
@export var loop_selection: bool = true  # Зацикливать выбор
@export var skip_air_block: bool = true  # Пропускать воздух (ID 0) при выборе

# Данные из библиотеки
var _library: VoxelBlockyLibrary = null
var _block_names: Dictionary = {}  # {id: name}
var _block_count: int = 0
var _min_block_id: int = 1
var _max_block_id: int = 1

# Текущий выбранный блок
var _current_block_id: int = 1

# Сигналы
signal block_selected(block_id: int, block_name: String)
signal library_loaded(block_count: int)

func _ready():
	# Загружаем библиотеку
	_load_library()
	
	# Ищем PlayerInteraction если путь не указан
	if _player_interaction == null:
		_player_interaction = _find_player_interaction()
	
	# Устанавливаем начальный блок
	_set_block(_current_block_id)
	
	print("🎮 BlockSelector готов!")
	print("📜 Используйте колёсико мыши для выбора блока")

func _load_library():
	# Загружаем ресурс библиотеки
	if not ResourceLoader.exists(library_path):
		push_error("❌ Библиотека не найдена: %s" % library_path)
		return
	
	_library = load(library_path) as VoxelBlockyLibrary
	
	if _library == null:
		push_error("❌ Не удалось загрузить библиотеку: %s" % library_path)
		return
	
	# Получаем информацию о блоках
	_parse_library()
	
	print("=".repeat(50))
	print("📚 БИБЛИОТЕКА БЛОКОВ ЗАГРУЖЕНА")
	print("=".repeat(50))
	print("📁 Путь: %s" % library_path)
	print("🧱 Всего блоков: %d" % _block_count)
	print("-".repeat(50))
	print("📋 Список блоков:")
	
	for id in _block_names:
		var name = _block_names[id]
		var marker = " ← [текущий]" if id == _current_block_id else ""
		print("   [%d] %s%s" % [id, name, marker])
	
	print("=".repeat(50))
	
	library_loaded.emit(_block_count)

func _parse_library():
	_block_names.clear()
	
	# Получаем массив моделей напрямую из свойства models
	var models: Array = _library.models
	_block_count = models.size()
	
	if _block_count == 0:
		push_warning("⚠️ Библиотека пуста!")
		return
	
	# Перебираем все модели
	for i in range(_block_count):
		var model: VoxelBlockyModel = models[i]
		
		if model == null:
			_block_names[i] = "Empty_%d" % i
			continue
		
		var block_name: String = ""
		
		# Способ 1: resource_name (основной)
		if model.resource_name != "":
			block_name = model.resource_name
		# Способ 2: resource_path (берём имя файла)
		elif model.resource_path != "":
			block_name = model.resource_path.get_file().get_basename()
		# Способ 3: просто номер
		else:
			block_name = "Block_%d" % i
		
		_block_names[i] = block_name
	
	# Определяем диапазон ID
	if skip_air_block and _block_count > 1:
		_min_block_id = 1
	else:
		_min_block_id = 0
	
	_max_block_id = _block_count - 1
	
	# Корректируем текущий блок если нужно
	_current_block_id = clampi(_current_block_id, _min_block_id, _max_block_id)

func _find_player_interaction() -> Node:
	var parent = get_parent()
	if parent:
		for child in parent.get_children():
			if child.has_method("set_selected_block"):
				return child
	
	var nodes = get_tree().get_nodes_in_group("player")
	for node in nodes:
		if node.has_method("set_selected_block"):
			return node
		for child in node.get_children():
			if child.has_method("set_selected_block"):
				return child
	
	push_warning("⚠️ PlayerInteraction не найден!")
	return null

func _input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_select_next_block()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_select_previous_block()
	
	# Цифровые клавиши 1-9, 0 для быстрого выбора
	if event is InputEventKey and event.pressed:
		var key_to_block: Dictionary = {
			KEY_1: 1, KEY_2: 2, KEY_3: 3,
			KEY_4: 4, KEY_5: 5, KEY_6: 6,
			KEY_7: 7, KEY_8: 8, KEY_9: 9,
			KEY_0: 10
		}
		
		if key_to_block.has(event.keycode):
			var block_id = key_to_block[event.keycode]
			if block_id <= _max_block_id:
				_set_block(block_id)

func _select_next_block():
	var new_id = _current_block_id + 1
	
	if new_id > _max_block_id:
		new_id = _min_block_id if loop_selection else _max_block_id
	
	_set_block(new_id)

func _select_previous_block():
	var new_id = _current_block_id - 1
	
	if new_id < _min_block_id:
		new_id = _max_block_id if loop_selection else _min_block_id
	
	_set_block(new_id)

func _set_block(block_id: int):
	block_id = clampi(block_id, _min_block_id, _max_block_id)
	
	_current_block_id = block_id
	
	if _player_interaction:
		# Устанавливаем block_id
		if _player_interaction.has_method("set_selected_block"):
			_player_interaction.set_selected_block(block_id)
		# Также передаем имя текстуры
		var texture_name = _get_texture_for_block(block_id)
		if _player_interaction.has_method("set_selected_texture") and texture_name:
			_player_interaction.set_selected_texture(texture_name)
	
	_print_current_block()
	
	var block_name = get_block_name(block_id)
	block_selected.emit(block_id, block_name)

func _print_current_block():
	var name = get_block_name(_current_block_id)
	print("🧱 Выбран блок [%d/%d]: %s" % [_current_block_id, _max_block_id, name])

# ============ ПУБЛИЧНЫЙ API ============

## Получить название блока по ID
func get_block_name(block_id: int) -> String:
	if _block_names.has(block_id):
		return _block_names[block_id]
	return "Unknown_%d" % block_id

## Получить текущий ID блока
func get_current_block_id() -> int:
	return _current_block_id

## Получить название текущего блока
func get_current_block_name() -> String:
	return get_block_name(_current_block_id)

## Получить общее количество блоков
func get_block_count() -> int:
	return _block_count

## Получить минимальный ID
func get_min_block_id() -> int:
	return _min_block_id

## Получить максимальный ID
func get_max_block_id() -> int:
	return _max_block_id

## Установить блок по ID
func select_block(block_id: int):
	_set_block(block_id)

## Установить блок по имени (использует API библиотеки)
func select_block_by_name(resource_name: String):
	if _library == null:
		return
	
	# Используем встроенный метод библиотеки
	var index = _library.get_model_index_from_resource_name(resource_name)
	
	if index != null and index >= 0:
		_set_block(index)
	else:
		push_warning("⚠️ Блок с именем '%s' не найден" % resource_name)

## Получить все блоки {id: name}
func get_all_blocks() -> Dictionary:
	return _block_names.duplicate()

## Получить библиотеку
func get_library() -> VoxelBlockyLibrary:
	return _library

## Перезагрузить библиотеку
func reload_library():
	_load_library()

## Получить модель блока по ID (использует API библиотеки)
func get_block_model(block_id: int) -> VoxelBlockyModel:
	if _library and block_id >= 0 and block_id < _block_count:
		return _library.get_model(block_id)
	return null

## Проверить существует ли блок
func has_block(block_id: int) -> bool:
	return _block_names.has(block_id)

## Найти ID блока по имени ресурса
func get_block_id_by_name(resource_name: String) -> int:
	if _library == null:
		return -1
	
	var index = _library.get_model_index_from_resource_name(resource_name)
	return index if index != null else -1

## Получить имя текстуры для block_id
func _get_texture_for_block(block_id: int) -> String:
	# Маппинг block_id → texture_name
	var texture_map = {
		1: "grass_block_top",  # block_grass
		2: "cherry_planks",    # cherry_planks
		3: "cherry_planks",    # cherry_stair
		4: "dirt",             # dirt
		5: "stone"             # stone
	}
	return texture_map.get(block_id, "")
