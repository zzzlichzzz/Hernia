@tool
class_name ItemBlock extends ItemData

@export var block_definition: BlockDefinition
var block = null


func getBlockDefinition() -> BlockDefinition:
	return block_definition
