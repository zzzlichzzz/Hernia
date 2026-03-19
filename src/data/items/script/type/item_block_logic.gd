@tool
class_name ItemBlockLogic extends ItemBlock


@export var path: StringName

func _init() -> void:
	self.block = preload("res://src/scripts/blocks/type/block_logic.gd").new()

func _process(delta: float) -> void:
	pass
	

func get_scene() -> Resource:
	return load(path)
