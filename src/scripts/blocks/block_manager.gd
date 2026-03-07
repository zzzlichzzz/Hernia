extends Node
class_name BlockManager

static var atlas: AtlasCoordinates = null

static func init():
	if atlas == null: atlas = load("res://src/assets/textures/atlas/block/block_coordinates.tres")

static func get_uv(block: String) -> Rect2:
	init()
	return atlas.get_uv(block)

static func get_texture(block: String) -> AtlasTexture:
	init()
	return atlas.get_atlas_texture_for_block(block)
