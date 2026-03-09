class_name ItemArrayRegistry extends Resource



#@export var item_array: Array[ItemData]
@export var item_array: Dictionary[String, ItemData]


func addItem(item: ItemData) -> void:
	item_array.set(item.id, item)
	
func getItem(id: String) -> ItemData:
	return item_array.get(id, null)
	
func getItemBlockID(id: String) -> int:
	return item_array.get(id).getIdBlock()
	
func isItemBlock(id: String) -> bool:
	return item_array.get(id) is ItemBlock
