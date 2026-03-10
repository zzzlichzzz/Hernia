@tool
class_name ItemBlock extends ItemData


@export var block_definition: BlockDefinition
#Костыль для работы с Voxel
@export var id_block: int = 0



func _ready():
	pass

func getBlockDefinition() -> BlockDefinition:
	return block_definition

func getIdBlock() -> int:
	return id_block


func useRightClick() -> void:
	pass
