class_name NetworkFieldDef
extends Resource
## Описание одного поля сетевого пакета.

## Имя поля (станет именем параметра и ключом в Dictionary)
@export var field_name: String = ""

## ═══ Тип данных ═══
enum FieldType {
	BOOL,
	INT,
	FLOAT,
	VECTOR2,
	VECTOR3,
	STRING,
	PACKED_BYTES,
}
@export var field_type: FieldType = FieldType.INT

## ═══ Размер одного компонента в байтах ═══
## VECTOR3 + BITS_16 → каждый из x,y,z = 2 байта (half-float)
## STRING / PACKED_BYTES — игнорируется (length-prefixed)
enum ByteSize {
	AUTO,       # BOOL→1, INT→4, FLOAT→4
	BITS_8,     # 1 байт
	BITS_16,    # 2 байта
	BITS_32,    # 4 байта
}
@export var byte_size: ByteSize = ByteSize.AUTO

## ═══ Знаковость (только для INT) ═══
@export var is_signed: bool = false

## ═══ Квантизация (FLOAT / компоненты вектора) ═══
## Отображает диапазон [min, max] в целое число заданного byte_size
@export var use_quantization: bool = false
@export var quantize_min: float = 0.0
@export var quantize_max: float = 1.0

## ═══ Описание ═══
@export var source_description: String = ""
