class_name ItemLibrary extends Resource


var ArrayList: Array[ItemData]

enum Type {
	VARIANT_1 = 1,
	VARIANT_2 = 2,
	VARIANT_3 = 3,
	VARIANT_4 = 4,
}


@export var block_item: Array[ItemData] = []
@export var consumble_item: Array[ItemData] = []

func addItem(item: ItemData) -> void:
	ArrayList.append(item)
	
func getArray(name: String) -> Array[ItemData]:
	match name:
		"block_item":
			return block_item
		"consumble_item":
			return consumble_item
	var v: Array[ItemData] = []
	return v
