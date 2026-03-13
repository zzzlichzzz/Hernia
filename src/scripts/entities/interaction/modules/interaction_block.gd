class_name InteractionBlock extends Interaction


@onready var _terrain: VoxelTerrain = get_node("../../../../VoxelTerrain")
@onready var _raycast: RayCast3D = get_node("../../Neck/Camera3D/RayCast3D")
@onready var _camera: Camera3D = get_node("../../Neck/Camera3D")
var _entity = null

func _ready() -> void:
	_entity = get_parent().get_parent()


signal block_broken(pos: Vector3i, old_id: Vector3i)


func _process(delta: float) -> void:
	pass
	
	
func _break_block():
	if _terrain._terrain_tool == null:
		return
	var pos = _get_combined_target()["position"]
	var old_id = _terrain._terrain_tool.get_voxel(pos)
	if old_id == 0:
		return

	var cham = ChameleonManager.get_instance()
	#if cham and cham.is_chameleon_block(old_id):
		#cham.remove_chameleon(pos)
		
	_terrain._terrain_tool.value = 0
	_terrain._terrain_tool.do_point(pos)
	var new_id = _terrain._terrain_tool.get_voxel(pos)
	if new_id == 0:
		print("⛏️ Блок сломан: ", pos)
		block_broken.emit(pos, old_id)
	else:
		print("❌ Не удалось сломать блок: ", pos)
		
		
func _get_combined_target() -> Dictionary:
	var result = {
		"has_target": false,
		"position": Vector3i.ZERO,
		"place_position": Vector3i.ZERO,
		"face": "top",
		"normal": Vector3.ZERO
	}

	var origin = _camera.global_position
	var forward = -_camera.global_transform.basis.z.normalized()

	var hit = _terrain._terrain_tool.raycast(origin, forward, _entity.REACH_DISTANCE)
	if hit:
		result["has_target"] = true
		result["position"] = hit.position
		result["place_position"] = hit.previous_position

		var normal = Vector3(hit.previous_position - hit.position)
		#result["face"] = _normal_to_face(normal)
		result["normal"] = normal.normalized()

	return result
