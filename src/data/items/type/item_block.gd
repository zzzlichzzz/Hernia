@tool
class_name ItemBlock extends ItemData


@export var block_definition: BlockDefinition

func _ready():
	pass

func getBlockDefinition() -> BlockDefinition:
	return block_definition
