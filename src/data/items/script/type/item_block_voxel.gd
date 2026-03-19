class_name ItemBlockVoxel extends ItemBlock

# Блоки для воксела (Статичные)

func _init() -> void:
	self.block = preload("res://src/scripts/blocks/type/block_voxel.gd").new()
	
	
