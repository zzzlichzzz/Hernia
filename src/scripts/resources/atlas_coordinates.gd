extends Resource
class_name AtlasCoordinates

@export var coordinates: Dictionary = {}
@export var atlas_texture: Texture2D
@export var block_sizes: Dictionary = {}
@export var png_filename: String = "block_atlas.png"

# 🔥 ДОБАВЛЯЕМ ЭТО ПОЛЕ
@export var png_path: String = ""

# Полный путь для использования в коде
func get_png_path() -> String:
	if png_path != "":
		return png_path
	return PathManager.game("res://src/assets/textures/atlas/" + png_filename)

# Метод для загрузки PNG как текстуры
func load_png_as_texture() -> Texture2D:
	var path = get_png_path()
	if FileAccess.file_exists(path):
		var img = Image.load_from_file(path)
		if img:
			return ImageTexture.create_from_image(img)
	return atlas_texture

func get_uv(block_name: String) -> Rect2:
	if coordinates.has(block_name):
		var coord = coordinates[block_name]
		return Rect2(coord.uv.left, coord.uv.top, 
					coord.uv.right - coord.uv.left, 
					coord.uv.bottom - coord.uv.top)
	return Rect2(0, 0, 1, 1)
