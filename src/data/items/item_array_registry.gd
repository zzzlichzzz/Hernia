class_name ItemArrayRegistry extends Resource




@export var item_array: Array[ItemData]
@export var items: Dictionary[String, int]


func addItem(index: int, item: ItemData) -> void:
	item_array.set(index, item)
	
func get_item_string(id: String) -> ItemData:
	return item_array.get(items.get(id))

func get_item_int(id: int) -> ItemData:
	return item_array.get(id)



func getItemId(name: String) -> int:
	return items.get(name)

func isItemBlock(id: int) -> bool:
	return item_array.get(id) is ItemBlock
