@tool
class_name NetworkFieldDef
extends Resource

## Имя поля (snake_case). Станет ключом в Dictionary.
@export var field_name: String = "":
	set(value):
		field_name = value
		_update_resource_name()

enum FieldType { BOOL, INT, FLOAT, VECTOR2, VECTOR3, STRING, PACKED_BYTES }
## Тип данных поля.
@export var field_type: FieldType = FieldType.INT:
	set(value):
		field_type = value
		_update_resource_name()

enum ByteSize { AUTO, BITS_8, BITS_16, BITS_32 }
## Размер компонента. Для VEC3 — размер каждого из x, y, z.
@export var byte_size: ByteSize = ByteSize.AUTO:
	set(value):
		byte_size = value
		_update_resource_name()

## Знаковость (только INT).
@export var is_signed: bool = false

@export_group("Quantization")
## Квантизация float → целое в диапазоне [min, max].
@export var use_quantization: bool = false
## Минимум диапазона.
@export var quantize_min: float = 0.0
## Максимум диапазона. Должен быть > min.
@export var quantize_max: float = 1.0

@export_group("Binding")
## Ключ в Dictionary из source_method. Точечная нотация: "rotation.x"
@export var source_key: String = ""
## Описание поля (комментарий).
@export var source_description: String = ""


func _update_resource_name() -> void:
	if field_name == "":
		resource_name = "unnamed_field"
		return

	var type_names := ["bool", "int", "float", "vec2", "vec3", "string", "bytes"]
	var size_names := ["auto", "8bit", "16bit", "32bit"]

	var t: String = type_names[field_type] if field_type < type_names.size() else "?"
	var s: String = size_names[byte_size] if byte_size < size_names.size() else "?"

	resource_name = "%s (%s, %s)" % [field_name, t, s]
