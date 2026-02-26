extends Resource
class_name BlockDefinition

@export var block_name: String = ""
@export var texture_name: String = ""

# ═══ Текстуры для отдельных граней ═══
@export var texture_top: String = ""
@export var texture_bottom: String = ""
@export var texture_side: String = ""

# ═══ Оверлей для боковых граней ═══
@export var texture_side_overlay: String = ""

# Модель блока
@export var model: Mesh

# Параметры рендеринга
@export var culls_neighbors: bool = true
@export var transparency_index: int = 0

# ═══ Тип материала ═══
enum MaterialType { OPAQUE, TRANSPARENT, FOLIAGE, MULTI_FACE }

@export var material_type_enum: MaterialType = MaterialType.OPAQUE:
	set(value):
		material_type_enum = value
		match value:
			MaterialType.OPAQUE:
				material_type = "opaque"
			MaterialType.TRANSPARENT:
				material_type = "transparent"
			MaterialType.FOLIAGE:
				material_type = "foliage"
			MaterialType.MULTI_FACE:
				material_type = "multi_face"
	get:
		return material_type_enum

var material_type: String = "opaque"

# Коллизия
@export var collision_enabled: bool = true
@export var collision_aabbs: Array[AABB] = [AABB(Vector3(0, 0, 0), Vector3(1, 1, 1))]
@export var collision_mask: int = 1

# Свойства
@export var transparent: bool = false
@export var solid: bool = true
@export var hardness: float = 1.0
@export var rotation_type: int = 0
@export var is_fluid: bool = false
@export var viscosity: float = 0.8


func has_per_face_textures() -> bool:
	return texture_top != "" or texture_bottom != "" or texture_side != ""

func has_side_overlay() -> bool:
	return texture_side_overlay != ""

func _init():
	match material_type_enum:
		MaterialType.OPAQUE:
			material_type = "opaque"
		MaterialType.TRANSPARENT:
			material_type = "transparent"
		MaterialType.FOLIAGE:
			material_type = "foliage"
		MaterialType.MULTI_FACE:
			material_type = "multi_face"
