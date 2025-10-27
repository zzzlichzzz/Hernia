class_name BlockCore extends Node3D

signal broken(by)
signal interacted(by)
signal placed(by)

@export var hardness: float = 1.0  # базовая прочность
var modules: Array = []

func _ready():
	# Авто-сборка модулей
	for child in get_children():
		if child is BlockModule:
			modules.append(child)
			child.on_init(self)

func break_block(by = null):
	emit_signal("broken", by)
	for module in modules:
		module.on_break(self, by)
	queue_free()

func interact(player):
	emit_signal("interacted", player)
	for module in modules:
		module.on_interact(self, player)

func place(placer):
	emit_signal("placed", placer)
	for module in modules:
		module.on_place(self, placer)

func neighbor_update(neighbor_pos):
	for module in modules:
		module.on_neighbor_update(self, neighbor_pos)

func _process(delta):
	for module in modules:
		module.on_tick(self, delta)
