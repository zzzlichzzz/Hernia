extends Resource
class_name AtlasCoordinates

@export var coordinates: Dictionary = {}
@export var atlas_texture: Texture2D
@export var block_sizes: Dictionary = {}
@export var png_filename: String = "block_atlas.png"
@export var png_path: String = ""

func get_png_path() -> String:
	return png_path if png_path != "" else "res://src/assets/textures/atlas/" + png_filename

func load_png_as_texture() -> Texture2D:
	var path = get_png_path()
	if FileAccess.file_exists(path):
		var img = Image.load_from_file(path)
		if img: return ImageTexture.create_from_image(img)
	return atlas_texture

func get_uv(block_name: String) -> Rect2:
	if coordinates.has(block_name):
		var c = coordinates[block_name]
		return Rect2(c.uv.left, c.uv.top, c.uv.right - c.uv.left, c.uv.bottom - c.uv.top)
	return Rect2(0, 0, 1, 1)
