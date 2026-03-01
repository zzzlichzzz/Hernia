extends Node

@export var player_path: NodePath = ""
var _player: Node = null

# Переменные для работы с блоками
var _current_block_id: int = 1
var _min_block_id: int = 1
var _max_block_id: int = 5
var _block_count: int = 5
var _block_names: Dictionary = {}
var loop_selection: bool = true

# Ссылка на PlayerInteraction
var _player_interaction: Node = null

# Библиотека блоков
var _library: VoxelBlockyLibrary = null

signal block_selected(block_id: int, block_name: String)

func _ready():
	_find_player()
	_load_library()
	_find_player_interaction()
	
	# Подключаемся к сигналу изменения слота от create_inventory
	var inventory = _find_inventory()
	if inventory and inventory.has_signal("selected_slot_changed"):
		inventory.selected_slot_changed.connect(_on_player_selected_slot_changed)
		# Инициализируем текущий выбранный блок
		_on_player_selected_slot_changed(0)
	
	print("🎮 BlockSelector (хотбар) готов!")

func _find_player():
	if player_path:
		_player = get_node(player_path)
		if _player: return
	_player = _find_player_recursive(get_tree().current_scene)

func _find_player_recursive(node: Node) -> Node:
	if node is CharacterBody3D:
		return node
	for child in node.get_children():
		var found = _find_player_recursive(child)
		if found:
			return found
	return null

func _input(event: InputEvent):
	if not _player: return
	
	# Колёсико мыши работает только когда инвентарь закрыт
	if not _player.inventory_open and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if _player.has_method("select_next_slot"):
				_player.select_next_slot()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if _player.has_method("select_previous_slot"):
				_player.select_previous_slot()

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
func _find_player_interaction():
	if _player:
		for child in _player.get_children():
			if child.has_method("set_selected_block"):
				_player_interaction = child
				break

func _load_library():
	# Загружаем библиотеку блоков
	var library_path = "res://src/data/blocks/voxel_blocky_library.tres"
	var lib = load(library_path)
	if lib and lib is VoxelBlockyLibrary:
		_library = lib
		var models: Array = _library.models
		_block_count = models.size()
		_max_block_id = _block_count - 1
		_block_names = {}
		for i in range(models.size()):
			var model = models[i]
			if model:
				_block_names[i] = model.resource_name if model.resource_name else "block_%d" % i
		print("📚 Загружено блоков: ", _block_count)
	else:
		push_warning("⚠️ Не удалось загрузить библиотеку блоков")
		# Используем значения по умолчанию
		_block_names = {
			0: "air",
			1: "grass",
			2: "cherry_planks",
			3: "cherry_stair",
			4: "dirt",
			5: "stone"
		}
		_block_count = 6
		_max_block_id = 5

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

func _on_player_selected_slot_changed(index: int):
	# Ищем create_inventory для получения информации о выбранном блоке
	var inventory = _find_inventory()
	if inventory:
		var info = inventory.get_selected_block_info()
		var block_id = info.get("id", -1) if not info.is_empty() else -1
		var block_name = info.get("name", "empty") if not info.is_empty() else "empty"
		
		# Устанавливаем блок через PlayerInteraction если доступен
		if _player_interaction and _player_interaction.has_method("set_selected_block"):
			_player_interaction.set_selected_block(block_id)
			# Обновляем текстуру
			var texture_name = _get_texture_for_block(block_id)
			if texture_name and _player_interaction.has_method("set_selected_texture"):
				_player_interaction.set_selected_texture(texture_name)
		
		_current_block_id = block_id
		block_selected.emit(block_id, block_name)
		print("📦 BlockSelector: выбран блок ", block_name, " ID=", block_id)

func _find_inventory() -> Node:
	# Ищем CreativeInventory среди детей игрока
	if _player:
		for child in _player.get_children():
			if child.has_method("get_selected_block_info"):
				return child
	return null
