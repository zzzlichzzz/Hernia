extends Control
class_name InventorySlot

# ═══════════════════════════════════════════════════════════
# СИГНАЛЫ
# ═══════════════════════════════════════════════════════════

signal slot_clicked(slot: InventorySlot)
signal slot_double_clicked(slot: InventorySlot)
signal slot_right_clicked(slot: InventorySlot)
signal drag_started(slot: InventorySlot, item_data: Dictionary)
signal drag_ended(slot: InventorySlot)

# ═══════════════════════════════════════════════════════════
# EXPORT ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════

@export var slot_index: int = -1
@export var is_hotbar_slot: bool = false
@export var show_selection: bool = true

# ═══════════════════════════════════════════════════════════
# ВНУТРЕННИЕ ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════

var _item_data: Dictionary = {}  # {id, name, texture, count?}
var _is_selected: bool = false
var _is_hovered: bool = false
var _is_dragging: bool = false

# Ссылки на дочерние узлы
@onready var bg_node: TextureRect = $BG
@onready var select_bg_node: TextureRect = $SelectBG
@onready var texture_rect: TextureRect = $TextureRect

# Цвета для стилей
var _normal_color: Color = Color(1, 1, 1, 1)
var _hover_color: Color = Color(1.2, 1.2, 1.2, 1)
var _selected_color: Color = Color(1.5, 1.5, 0.5, 1)

# ═══════════════════════════════════════════════════════════
# ГОТОВОСТЬ
# ═══════════════════════════════════════════════════════════

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Подключаем сигналы наведения
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	# Инициализируем отображение
	_update_display()

func _exit_tree():
	# Очистка при удалении
	pass

# ═══════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════

## Установить данные предмета в слот
func set_item(item: Dictionary) -> void:
	_item_data = item.duplicate() if not item.is_empty() else {}
	_update_display()

## Получить данные предмета
func get_item() -> Dictionary:
	return _item_data.duplicate()

## Проверить, пустой ли слот
func is_empty() -> bool:
	return _item_data.is_empty()

## Очистить слот
func clear() -> void:
	_item_data = {}
	_update_display()

## Установить выделение
func set_selected(selected: bool) -> void:
	_is_selected = selected
	if show_selection and select_bg_node:
		select_bg_node.visible = selected
	_update_display()

## Получить состояние выделения
func is_selected() -> bool:
	return _is_selected

## Установить текстуру фона
func set_background_texture(texture: Texture2D) -> void:
	if bg_node:
		bg_node.texture = texture

## Установить текстуру выделения
func set_selection_texture(texture: Texture2D) -> void:
	if select_bg_node:
		select_bg_node.texture = texture

# ═══════════════════════════════════════════════════════════
# ПРИВАТНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════

func _update_display() -> void:
	if not is_inside_tree():
		return
	
	# Обновляем текстуру предмета
	if texture_rect:
		if not _item_data.is_empty() and _item_data.has("texture"):
			texture_rect.texture = _item_data.texture
			texture_rect.visible = true
		else:
			texture_rect.visible = false
	
	# Обновляем выделение
	if select_bg_node:
		select_bg_node.visible = _is_selected and show_selection

# ═══════════════════════════════════════════════════════════
# ОБРАБОТКА СОБЫТИЙ
# ═══════════════════════════════════════════════════════════

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				# Одиночный клик
				slot_clicked.emit(self)
			elif mouse_event.double_click:
				# Двойной клик
				slot_double_clicked.emit(self)
		
		elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			if mouse_event.pressed:
				slot_right_clicked.emit(self)

func _on_mouse_entered() -> void:
	_is_hovered = true
	if bg_node:
		bg_node.modulate = _hover_color

func _on_mouse_exited() -> void:
	_is_hovered = false
	if bg_node:
		bg_node.modulate = _normal_color if not _is_selected else _selected_color

# ═══════════════════════════════════════════════════════════
# DRAG & DROP
# ═══════════════════════════════════════════════════════════

func _get_drag_data(at_position: Vector2) -> Variant:
	if _item_data.is_empty():
		return null
	
	_is_dragging = true
	
	# Создаём превью для перетаскивания
	var preview = _create_drag_preview()
	set_drag_preview(preview)
	
	# Отправляем сигнал о начале перетаскивания
	drag_started.emit(self, _item_data)
	
	# Возвращаем данные для передачи
	return {
		"item": _item_data.duplicate(),
		"source_slot": self,
		"slot_index": slot_index,
		"is_hotbar": is_hotbar_slot
	}

func _can_drop_data(at_position: Vector2, data) -> bool:
	# Можно бросить если данные корректны
	if typeof(data) != TYPE_DICTIONARY:
		return false
	if not data.has("item"):
		return false
	return true

func _drop_data(at_position: Vector2, data) -> void:
	if not data.has("item"):
		return
	
	var incoming_item = data["item"]
	var source_slot = data.get("source_slot", null)
	
	# Если в текущем слоте есть предмет - меняем местами
	if not is_empty() and source_slot:
		# Обмен предметами между слотами
		var my_item = get_item()
		source_slot.set_item(my_item)
		set_item(incoming_item)
	else:
		# Просто помещаем предмет
		set_item(incoming_item)
		# Очищаем источник если есть
		if source_slot and source_slot != self:
			source_slot.clear()
	
	drag_ended.emit(self)

func _create_drag_preview() -> Control:
	var preview = Control.new()
	preview.custom_minimum_size = Vector2(48, 48)
	
	# Фон превью
	var bg = ColorRect.new()
	bg.color = Color(0.2, 0.2, 0.2, 0.8)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	preview.add_child(bg)
	
	# Рамка
	var border = ColorRect.new()
	border.color = Color(0.6, 0.6, 0.6)
	border.custom_minimum_size = Vector2(48, 48)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_child(border)
	
	# Текстура предмета
	if _item_data.has("texture") and _item_data.texture:
		var tex_rect = TextureRect.new()
		tex_rect.texture = _item_data.texture
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.custom_minimum_size = Vector2(40, 40)
		tex_rect.position = Vector2(4, 4)
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview.add_child(tex_rect)
	
	return preview

# ═══════════════════════════════════════════════════════════
# СЕРИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════

## Сериализовать данные слота для сохранения
func serialize() -> Dictionary:
	if _item_data.is_empty():
		return {}
	
	var result = {
		"slot_index": slot_index,
		"item_id": _item_data.get("id", -1),
		"item_name": _item_data.get("name", ""),
	}
	
	# Количество если есть
	if _item_data.has("count"):
		result["count"] = _item_data["count"]
	
	return result

## Десериализовать данные слота из сохранения
func deserialize(data: Dictionary, texture_lookup: Callable = Callable()) -> void:
	if data.is_empty():
		clear()
		return
	
	_item_data = {
		"id": data.get("item_id", -1),
		"name": data.get("item_name", ""),
	}
	
	if data.has("count"):
		_item_data["count"] = data["count"]
	
	# Восстанавливаем текстуру через callback если передан
	if texture_lookup.is_valid():
		var texture = texture_lookup.call(_item_data.id, _item_data.name)
		if texture:
			_item_data["texture"] = texture
	
	_update_display()
