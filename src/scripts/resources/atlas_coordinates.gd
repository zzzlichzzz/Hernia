extends Resource
class_name AtlasCoordinates

@export var coordinates: Dictionary = {}
@export var atlas_texture: Texture2D
@export var block_sizes: Dictionary = {}

func get_uv(block_name: String) -> Rect2:
	if coordinates.has(block_name):
		var coord = coordinates[block_name]
		return Rect2(coord.uv.left, coord.uv.top, 
					coord.uv.right - coord.uv.left, 
					coord.uv.bottom - coord.uv.top)
	return Rect2(0, 0, 1, 1)

func get_atlas_texture_for_block(block_name: String) -> AtlasTexture:
	if not coordinates.has(block_name):
		return null
	
	var coord = coordinates[block_name]
	var atlas_tex = AtlasTexture.new()
	atlas_tex.atlas = atlas_texture
	atlas_tex.region = Rect2(coord.x, coord.y, coord.width, coord.height)
	return atlas_tex
