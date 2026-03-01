extends Node

@export var player_path: NodePath = ""
var _player: Node = null

signal block_selected(block_id: int, block_name: String)

func _ready():
	_find_player()
	if _player and _player.has_signal("selected_slot_changed"):
		_player.selected_slot_changed.connect(_on_player_selected_slot_changed)
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
	if not _player: return
	var info = _player.get_selected_block_info() if _player.has_method("get_selected_block_info") else {}
	var block_id = info.get("id", -1) if not info.is_empty() else -1
	var block_name = info.get("name", "empty") if not info.is_empty() else "empty"
	block_selected.emit(block_id, block_name)
