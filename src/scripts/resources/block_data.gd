extends Resource
class_name BlockData

@export var block_name: String = ""
@export var model_path: String = ""
@export var texture_name: String = ""
@export var transparent: bool = false
@export var solid: bool = true
@export var hardness: float = 1.0
@export var rotation_type: int = 0

# Поля для системы (не @export)
var library_id: int = -1
var material: StandardMaterial3D
var variant_ids: Array[int] = []  # 🔥 ID моделей в библиотеке
var sprite_texture: Texture2D  # 🔥 Для инвентаря
