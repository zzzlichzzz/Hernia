class_name ItemArrayRegistry extends Resource



@export var item_array: Array[ItemData]



func addItem(item: ItemData) -> void:
	item_array.append(item)
