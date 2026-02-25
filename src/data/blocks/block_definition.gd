extends Resource
class_name BlockDefinition

@export var block_name: String = ""
@export var texture_name: String = ""

# Модель блока (ArrayMesh)
@export var model: ArrayMesh

# Параметры рендеринга для godot_voxel
@export var culls_neighbors: bool = true   # Отсекать ли грани соседей
@export var transparency_index: int = 0    # 0 = непрозрачный, >0 = прозрачный

# Тип материала для шейдера
enum MaterialType { OPAQUE, TRANSPARENT, FOLIAGE }
@export var material_type_enum: MaterialType = MaterialType.OPAQUE
var material_type: String = "opaque"  # автоматически устанавливается из enum

# Коллизия
@export var collision_enabled: bool = true                     # Включена ли коллизия для блока
@export var collision_aabbs: Array[AABB] = [AABB(Vector3(0, 0, 0), Vector3(1, 1, 1))]  # По умолчанию полный куб
@export var collision_mask: int = 1                            # Маска коллизии (битовая)

# Прочие свойства
@export var transparent: bool = false
@export var solid: bool = true
@export var hardness: float = 1.0
@export var rotation_type: int = 0
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
