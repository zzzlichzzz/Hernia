extends Resource
class_name AtlasCoordinates

@export var coordinates: Dictionary = {}
@export var atlas_texture: Texture2D
@export var block_sizes: Dictionary = {}
@export var png_filename: String = "block_atlas.png"   # информационное поле (можно оставить)
@export var png_path: String = ""                      # полный путь к PNG (например, "res://src/assets/textures/atlas/block_atlas.png")

# Возвращает полный путь к PNG (берётся из png_path)
func get_png_path() -> String:
	return png_path

# Загружает PNG как текстуру, если файл существует, иначе возвращает atlas_texture
func load_png_as_texture() -> Texture2D:
	if png_path.is_empty():
		return atlas_texture
	if FileAccess.file_exists(png_path):
		var img = Image.load_from_file(png_path)
		if img:
			return ImageTexture.create_from_image(img)
	return atlas_texture

# Возвращает UV-прямоугольник для блока по имени
func get_uv(block_name: String) -> Rect2:
	if coordinates.has(block_name):
		var coord = coordinates[block_name]
		return Rect2(
			coord.uv.left, coord.uv.top,
			coord.uv.right - coord.uv.left,
			coord.uv.bottom - coord.uv.top
		)
	return Rect2(0, 0, 1, 1)
