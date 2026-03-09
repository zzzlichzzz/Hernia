@tool
class_name ItemData extends Resource


@export var id: StringName:
	set(value):
		id = value
		resource_name = value
@export var display_name: String
@export var icon_path: String
@export var max_stack: int = 64
@export var world_mesh: Mesh
@export var consumable: bool = false




	


	
