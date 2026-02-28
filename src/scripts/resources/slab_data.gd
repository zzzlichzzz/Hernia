extends Resource
class_name SlabData
## Хранит данные о полублоках. Сохраняется при сборке, загружается в игре.

# { "stone_slab": { "bottom_id": 4, "top_id": 5, "full_id": 3 } }
@export var slab_registry: Dictionary = {}

# { 4: { "name": "stone_slab", "variant": "bottom" }, 5: { ... } }
@export var slab_id_map: Dictionary = {}
