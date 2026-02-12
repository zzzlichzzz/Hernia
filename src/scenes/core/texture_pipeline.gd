extends Node

const AtlasCoordinates = preload("res://src/scripts/resources/atlas_coordinates.gd")

@onready var atlas_coords_resource = load("res://src/assets/textures/atlas/block_coordinates.tres")

func _ready() -> void:
	if atlas_coords_resource:
		var atlas_coords = atlas_coords_resource as AtlasCoordinates
		if atlas_coords:
			print(atlas_coords.get_uv("dirt"))
		else:
			print("❌ Не удалось привести тип")
