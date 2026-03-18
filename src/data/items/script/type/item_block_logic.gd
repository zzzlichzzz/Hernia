@tool
class_name ItemBlockLogic extends ItemBlock


@export var path: StringName


func _ready() -> void:
	pass # Replace with function body.

func _process(delta: float) -> void:
	pass
	

func get_scene() -> Resource:
	return load(path)
