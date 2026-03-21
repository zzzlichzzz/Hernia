class_name BlockVoxel extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


	
func _place_block(pos: Vector3i, p: BlockInteraction) -> void:
	self._place_block_voxel(pos, p)
	
	
func _break_block(pos: Vector3i, p: BlockInteraction) -> void:
	self._remove_block_voxel(pos, p)


static func _remove_block_voxel(pos: Vector3i, p: BlockInteraction) -> bool:
	if p._terrain_tool == null:
		return false

	var old_id := p._terrain_tool.get_voxel(pos)
	if old_id == 0:
		return false
	
		#_world.remove_child()
	var cham := ChameleonManager.get_instance()
	if cham and cham.is_chameleon_block(old_id):
		cham.remove_chameleon(pos)
	p._terrain_tool.value = 0
	p._terrain_tool.do_point(pos)

	var new_id := p._terrain_tool.get_voxel(pos)
	if new_id == 0:
		print("⛏️ Блок сломан: ", pos)
		p.block_broken.emit(pos, old_id)
		p._send("block_break", [Vector3(pos)])
		return true
	else:
		push_warning("❌ Не удалось сломать блок: %s" % str(pos))
		return false

static func _place_block_voxel(pos: Vector3i, p: BlockInteraction) -> bool:
	if p._terrain_tool == null:
		return false

	var current := p._terrain_tool.get_voxel(pos)
	if current != 0:
		return false

	p._update_selected_block_from_inventory()

	# [CHANGE 2] Проверка на невалидный id ДО обращения к массиву
	if p._selected_block_id < 0:
		return false
	# [CHANGE 1] Проверка items
	if p.items == null:
		return false
	if not p.items.isItemBlock(p._selected_block_id):
		return false
		
	var voxel_id: int = p._selected_block_id
	p._terrain_tool.value = voxel_id
	p._terrain_tool.do_point(pos)

	var new_id := p._terrain_tool.get_voxel(pos)
	if new_id == voxel_id:
		print("🧱 Блок установлен: ", pos)
		p.block_placed.emit(pos, p._selected_block_id)
		p._send("block_place", [Vector3(pos), p.voxel_id])
	return true
	
func clickRight() -> void:
	pass
