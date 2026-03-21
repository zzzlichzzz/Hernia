class_name BlockLogic extends StaticBody3D


@onready var model = $Block


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.



func _place_block(pos: Vector3i, p: BlockInteraction) -> void:
	if BlockVoxel._place_block_voxel(pos, p):
		var scene_block: Resource = p.items.get_item_int(p._selected_block_id).get_scene()
		var entity = scene_block.instantiate()
		entity.position = Vector3(pos)
		p._world.add_child(entity)
		
		
func _break_block(pos: Vector3i, p: BlockInteraction) -> void:
	if BlockVoxel._remove_block_voxel(pos, p):
		remove_node_at_world_pos_3d(pos, p.get_world_3d())
		
		
func remove_node_at_world_pos_3d(pos: Vector3, v: World3D) -> void:
	var space := v.direct_space_state

	var q := PhysicsPointQueryParameters3D.new()
	q.position = pos
	q.position.z += 0.5
	q.position.x += 0.5
	#q.position.y += 1
	#q.collide_with_areas = true
	q.collide_with_bodies = true
	

	var hits := space.intersect_point(q)
	if hits.is_empty():
		return

	var collider: CollisionObject3D = hits[0]["collider"]
	collider.queue_free()
	

func clickRight() -> void:
	if $Block/AnimationPlayer != null:
		$Block/AnimationPlayer.anim.play("close")
