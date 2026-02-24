extends Resource
class_name BlockDefinition
# Определение блока для последующей сборки в библиотеку

@export var block_name: String = ""
@export var texture_name: String = ""
@export var model: ArrayMesh

# 🔥 НОВЫЕ ПАРАМЕТРЫ ДЛЯ УПРАВЛЕНИЯ РЕНДЕРИНГОМ
@export var culls_neighbors: bool = true  # Должен ли этот блок отсекать грани соседей
@export var transparency_index: int = 0    # 0 = непрозрачный, >0 = прозрачный [citation:5][citation:9]

enum MaterialType { OPAQUE, TRANSPARENT, FOLIAGE }
@export var material_type_enum: MaterialType = MaterialType.OPAQUE
var material_type: String = "opaque"

@export var transparent: bool = false
@export var solid: bool = true
@export var hardness: float = 1.0
@export var rotation_type: int = 0

@export var collision_aabbs: Array = []
@export var collision_mask: int = 1

@export var is_fluid: bool = false
@export var viscosity: float = 0.8

func _get_property_list() -> Array:
	var properties = []
	properties.append({
		"name": "material_type",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "opaque,transparent,foliage",
		"usage": PROPERTY_USAGE_DEFAULT
	})
	return properties

func _set(property: StringName, value) -> bool:
	match property:
		"material_type_enum":
			match value:
				MaterialType.OPAQUE:
					material_type = "opaque"
				MaterialType.TRANSPARENT:
					material_type = "transparent"
				MaterialType.FOLIAGE:
					material_type = "foliage"
			return true
	return false

func _get(property: StringName):
	match property:
		"material_type_enum":
			match material_type:
				"opaque":
					return MaterialType.OPAQUE
				"transparent":
					return MaterialType.TRANSPARENT
				"foliage":
					return MaterialType.FOLIAGE
			return MaterialType.OPAQUE
	return null
