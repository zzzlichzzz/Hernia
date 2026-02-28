extends RefCounted
class_name SlabPlacementHelper
## Логика размещения полублоков в стиле Minecraft

static func get_placement(
	hit_voxel_pos: Vector3i,     # блок, на который смотрим
	place_voxel_pos: Vector3i,   # куда бы встал новый блок (previous_position)
	hit_world_pos: Vector3,      # точная мировая точка попадания
	hit_normal: Vector3,         # нормаль грани
	slab_name: String,
	voxel_tool: VoxelTool,
	registry: Node
) -> Dictionary:
	
	var slab_info = registry.get_slab_ids(slab_name)
	if slab_info.is_empty():
		return {"action": "none"}
	
	var hit_voxel_id = voxel_tool.get_voxel(hit_voxel_pos)
	var place_voxel_id = voxel_tool.get_voxel(place_voxel_pos)
	
	# ═══ СЛУЧАЙ 1: Кликнули по полублоку того же типа → объединяем ═══
	if registry.is_slab_id(hit_voxel_id):
		var hit_slab = registry.get_slab_info_by_id(hit_voxel_id)
		
		if hit_slab["name"] == slab_name and hit_slab["full_id"] >= 0:
			var variant = hit_slab["variant"]
			
			# Нижний полублок + клик сверху → полный блок
			if variant == "bottom" and hit_normal.y > 0.5:
				return {
					"action": "combine",
					"voxel_id": hit_slab["full_id"],
					"position": hit_voxel_pos
				}
			
			# Верхний полублок + клик снизу → полный блок
			if variant == "top" and hit_normal.y < -0.5:
				return {
					"action": "combine",
					"voxel_id": hit_slab["full_id"],
					"position": hit_voxel_pos
				}
	
	# ═══ СЛУЧАЙ 2: Место назначения уже содержит полублок того же типа ═══
	if registry.is_slab_id(place_voxel_id):
		var target_slab = registry.get_slab_info_by_id(place_voxel_id)
		
		if target_slab["name"] == slab_name and target_slab["full_id"] >= 0:
			var target_variant = target_slab["variant"]
			var new_variant = _determine_variant(hit_world_pos, hit_normal)
			
			# Разные половинки → полный блок
			if (target_variant == "bottom" and new_variant == "top") or \
			   (target_variant == "top" and new_variant == "bottom"):
				return {
					"action": "combine",
					"voxel_id": target_slab["full_id"],
					"position": place_voxel_pos
				}
	
	# ═══ СЛУЧАЙ 3: Обычное размещение ═══
	if place_voxel_id != 0:
		return {"action": "none"}
	
	var variant = _determine_variant(hit_world_pos, hit_normal)
	var voxel_id: int
	
	if variant == "bottom":
		voxel_id = slab_info["bottom_id"]
	else:
		voxel_id = slab_info["top_id"]
	
	return {
		"action": "place",
		"voxel_id": voxel_id,
		"position": place_voxel_pos
	}


static func _determine_variant(hit_world_pos: Vector3, hit_normal: Vector3) -> String:
	"""
	Minecraft-логика:
	- Клик на верхнюю грань → нижний полублок
	- Клик на нижнюю грань → верхний полублок
	- Клик на бок → зависит от Y точки попадания
	"""
	if hit_normal.y > 0.5:
		return "bottom"
	elif hit_normal.y < -0.5:
		return "top"
	else:
		var local_y = hit_world_pos.y - floor(hit_world_pos.y)
		return "top" if local_y >= 0.5 else "bottom"
