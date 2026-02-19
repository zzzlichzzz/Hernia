extends Resource
class_name BlockData

@export var block_name: String = ""
@export var model_path: String = ""
@export var transparent: bool = false
@export var solid: bool = true
@export var hardness: float = 1.0

# Поля для системы (не @export)
var library_id: int = -1
var material_type: String = "opaque"
