class_name InteractionBlock extends Interaction


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
	
func _break_block(pos: Vector3i):
	if _terrain_tool == null:
		return
	var old_id = _terrain_tool.get_voxel(pos)
	if old_id == 0:
		return

	# Хамелеон: очистка при разрушении
	var cham = ChameleonManager.get_instance()
	if cham and cham.is_chameleon_block(old_id):
		cham.remove_chameleon(pos)

	_terrain_tool.value = 0
	_terrain_tool.do_point(pos)
	var new_id = _terrain_tool.get_voxel(pos)
	if new_id == 0:
		print("⛏️ Блок сломан: ", pos)
		block_broken.emit(pos, old_id)
		# ── Мультиплеер: отправить другим ────
		_send_block_break(pos)
	else:
		print("❌ Не удалось сломать блок: ", pos)
