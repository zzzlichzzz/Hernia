extends Control

var slot_index: int = 0
var inventory = null
var _default_color: Color = Color(0.15, 0.15, 0.15, 0.9)
var _border_color: Color = Color(0.4, 0.4, 0.4)
var _is_hovered: bool = false

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func(): _is_hovered = true; _border_color = Color(0.6, 0.6, 0.6); queue_redraw())
	mouse_exited.connect(func(): _is_hovered = false; _border_color = Color(0.4, 0.4, 0.4); queue_redraw())

func _draw():
	var rect = get_rect()
	draw_rect(Rect2(0, 0, rect.size.x, rect.size.y), _default_color)
	draw_rect(Rect2(0, 0, rect.size.x, rect.size.y), _border_color, false, 2.0)

func _can_drop_data(at_position: Vector2, data) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.has("block")

func _drop_data(at_position: Vector2, data):
	if typeof(data) == TYPE_DICTIONARY and data.has("block") and inventory and inventory.has_method("set_hotbar_slot"):
		inventory.set_hotbar_slot(slot_index, data["block"])
