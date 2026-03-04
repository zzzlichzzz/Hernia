extends Control

# Индекс слота
var slot_index: int = 0

# Ссылка на инвентарь
var inventory = null

# Цвета
var _default_color: Color = Color(0.15, 0.15, 0.15, 0.9)
var _border_color: Color = Color(0.4, 0.4, 0.4)
var _hover_color: Color = Color(0.6, 0.6, 0.6)
var _is_hovered: bool = false

func _ready():
	# Настраиваем себя для приёма drop
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Подключаем сигналы наведения
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered():
	_is_hovered = true
	_border_color = _hover_color
	queue_redraw()

func _on_mouse_exited():
	_is_hovered = false
	_border_color = Color(0.4, 0.4, 0.4)
	queue_redraw()

func _draw():
	# Рисуем фон
	var rect = get_rect()
	draw_rect(Rect2(0, 0, rect.size.x, rect.size.y), _default_color)
	# Рисуем обводку
	draw_rect(Rect2(0, 0, rect.size.x, rect.size.y), _border_color, false, 2.0)

func _can_drop_data(at_position: Vector2, data) -> bool:
	# Проверяем, что это данные блока
	if typeof(data) == TYPE_DICTIONARY and data.has("block"):
		return true
	return false

func _drop_data(at_position: Vector2, data):
	if typeof(data) == TYPE_DICTIONARY and data.has("block"):
		var block = data["block"]
		
		if inventory and inventory.has_method("set_hotbar_slot"):
			inventory.set_hotbar_slot(slot_index, block)
			print("Блок перетащен в слот хотбара: ", slot_index + 1, " - ", block.get("name", "unknown"))
