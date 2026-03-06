class_name ItemBlock extends "res://src/data/items/item_data.gd"


@export var block_definition: BlockDefinition


func _ready():
	pass

func getBlockDefinition() -> BlockDefinition:
	return block_definition