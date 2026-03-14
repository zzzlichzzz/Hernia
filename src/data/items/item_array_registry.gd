class_name ItemArrayRegistry extends Resource




@export var item_array: Array[ItemData]



func addItem(index: int, item: ItemData) -> void:
	item_array.set(index, item)
	
func getItem(id: int) -> ItemData:
	return item_array.get(id)
	
func isItemBlock(id: int) -> bool:
	return item_array.get(id) is ItemBlock
