class_name PlayerInteraction extends Node3D

var interaction_item: InteractionItem
var interaction_block: InteractionBlock
var interaction_entity: InteractionEntity	
var player: BasePlayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	player = get_parent()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	_handle_input()


func _handle_input():

	#if player and "inventory_open" in player:
		#if player.is_open_inventory(): return


	if Input.is_action_pressed("break_block") and interaction_block != null:
		interaction_block._break_block()

	# ПКМ — поставить / покрасить хамелеон
	#if Input.is_action_pressed("place_block"):
		#if _try_paint_chameleon(target["position"]):
			#pass
		#else:
			#var place_pos = target["place_position"]
			#if _can_place_at(place_pos):
				#_place_block(place_pos)
		#_place_timer = place_cooldown
#
	## Средняя кнопка — выбрать
	#if Input.is_action_just_pressed("pick_block"):
		#_pick_block(target["position"])



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
