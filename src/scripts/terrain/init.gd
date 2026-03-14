class_name Init extends Node


var items: ItemArrayRegistry



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	items = load("res://src/data/items/items.tres")


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
	#pass
