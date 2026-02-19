extends Resource
class_name BlockDefinition
# Определение блока для последующей сборки в библиотеку

@export var block_name: String = ""

# 🔥 ИСПРАВЛЕНО: используем Dictionary с подсказкой для редактора
@export var model_paths: Dictionary = {
	"default": ""
}

@export var material_type: String = "opaque"  # opaque, transparent, foliage
@export var transparent: bool = false
@export var solid: bool = true
@export var hardness: float = 1.0
@export var rotation_type: int = 0  # 0 = none, 1 = axial, 2 = y

# Для сложных коллизий (опционально)
@export var collision_aabbs: Array = []  # массив AABB
@export var collision_mask: int = 1

# Для жидкостей
@export var is_fluid: bool = false
@export var viscosity: float = 0.8
