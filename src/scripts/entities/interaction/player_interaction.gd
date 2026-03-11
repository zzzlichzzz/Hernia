class_name PlayerInteraction extends Node3D

var interaction_item: InteractionItem
var interaction_block: InteractionBlock
var interaction_entity: InteractionEntity	
var player: BasePlayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	interaction_item = InteractionItem.new()
	interaction_block = InteractionBlock.new()
	interaction_entity = InteractionEntity.new()
	player = get_parent()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	_handle_input()


func _handle_input():

	if player and "inventory_open" in player:
		if player.is_open_inventory(): return


	if Input.is_action_pressed("break_block"):
	#and _break_timer <= 0:
		interaction_block._break_block(player)
		#_break_block(target["position"])
		#_break_timer = break_cooldown

	# ПКМ — поставить / покрасить хамелеон
	if Input.is_action_pressed("place_block") and _place_timer <= 0:
		if _try_paint_chameleon(target["position"]):
			pass
		else:
			var place_pos = target["place_position"]
			if _can_place_at(place_pos):
				_place_block(place_pos)
		_place_timer = place_cooldown

	# Средняя кнопка — выбрать
	if Input.is_action_just_pressed("pick_block"):
		_pick_block(target["position"])


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

	var hit = _terrain_tool.raycast(origin, forward, reach_distance)
	if hit:
		result["has_target"] = true
		result["position"] = hit.position
		result["place_position"] = hit.previous_position

		var normal = Vector3(hit.previous_position - hit.position)
		result["face"] = _normal_to_face(normal)
		result["normal"] = normal.normalized()

	return result
#func _process(delta):
	#if _terrain == null or _terrain_tool == null:
		#return
#
	#if _is_chat_or_inventory_open():
		#return
#
	#if _break_timer > 0:
		#_break_timer -= delta
	#if _place_timer > 0:
		#_place_timer -= delta
#
	#_handle_input()
