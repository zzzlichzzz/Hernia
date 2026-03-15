extends Resource
class_name AtlasCoordinates

@export var coordinates: Dictionary = {}
@export var atlas_texture: Texture2D
@export var block_sizes: Dictionary = {}
@export var png_filename: String = "block_atlas.png"
@export var png_path: String = ""

@export var icon_path: String = "res://src/assets/textures/atlas/icon/block_atlas.png"
@export var icon_path_coordinates: String = "res://src/assets/textures/atlas/icon/block_coordinates.tres"


func get_png_path() -> String:
	return png_path if png_path != "" else "res://src/assets/textures/atlas/block/" + png_filename

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
	
	
func get_icon_texture(name: String) -> ImageTexture:
	var img = Image.load_from_file(icon_path)
	var atlas_coords = load(icon_path_coordinates)
	if name == "air":
		return ImageTexture.new()
	if name == "empty":
		return ImageTexture.new()
	var data = atlas_coords.coordinates[name]
	var texture = ImageTexture
	if data.x + data.width <= img.get_width() and data.y + data.height <= img.get_height():
				var region_img = Image.create(data.width, data.height, false, img.get_format())
				region_img.blit_rect(img, Rect2i(data.x, data.y, data.width, data.height), Vector2i(0, 0))
				texture = ImageTexture.create_from_image(region_img)
	return texture
				
