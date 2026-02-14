extends Node3D

@onready var camera = $Camera3D
@onready var block_mesh = $BlockContainer/BlockMesh
@onready var line_edit = $UI/Control/VBoxContainer/LineEdit
@onready var info_label = $UI/Control/VBoxContainer/InfoLabel
@onready var distance_slider = $UI/Control/VBoxContainer/DistanceGroup/DistanceSlider
@onready var distance_label = $UI/Control/VBoxContainer/DistanceGroup/DistanceLabel
@onready var lod_buttons = {
	1: $UI/Control/VBoxContainer/LODGroup/LODButtons/LOD1,
	2: $UI/Control/VBoxContainer/LODGroup/LODButtons/LOD2,
	4: $UI/Control/VBoxContainer/LODGroup/LODButtons/LOD4,
	8: $UI/Control/VBoxContainer/LODGroup/LODButtons/LOD8
}
@onready var lod_indicator = $LODIndicator
@onready var apply_button = $UI/Control/VBoxContainer/HBoxContainer/Button
@onready var reset_button = $UI/Control/VBoxContainer/HBoxContainer/ButtonReset

var atlas_coords: AtlasCoordinates = null
var current_block: String = "stone"
var current_lod: int = 1
var available_blocks: Array = []

func _ready():
	# Настройка мыши
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Загрузка атласа
	load_atlas()
	
	# Подключение сигналов
	setup_ui()
	
	# Установка начального блока
	update_block()
	
	print("✅ Тестовая сцена готова!")

func load_atlas():
	var path = "res://src/assets/textures/atlas/block_coordinates.tres"
	if ResourceLoader.exists(path):
		atlas_coords = load(path)
		available_blocks = atlas_coords.coordinates.keys()
		print("✅ Атлас загружен, блоков: ", available_blocks.size())
		info_label.text = "✅ Атлас загружен. Всего блоков: " + str(available_blocks.size())
		
		# Показываем первые 5 блоков как подсказку
		var examples = ""
		for i in range(min(5, available_blocks.size())):
			examples += available_blocks[i]
			if i < 4 and i < available_blocks.size() - 1:
				examples += ", "
		info_label.text += "\n📋 Примеры: " + examples
	else:
		print("❌ Атлас не найден!")
		info_label.text = "❌ Атлас не найден! Запустите AtlasManager.build_atlas()"

func setup_ui():
	# Кнопка применения блока
	apply_button.pressed.connect(_on_apply_pressed)
	
	# Кнопка сброса
	reset_button.pressed.connect(_on_reset_pressed)
	
	# Enter в поле ввода
	line_edit.text_submitted.connect(_on_apply_pressed)
	
	# Кнопки LOD
	for lod in lod_buttons:
		lod_buttons[lod].pressed.connect(_on_lod_pressed.bind(lod))
	
	# Слайдер дистанции
	distance_slider.value_changed.connect(_on_distance_changed)

func _on_apply_pressed(_text = ""):
	var block_name = line_edit.text.strip_edges().to_lower()
	
	if block_name.is_empty():
		return
	
	if atlas_coords and atlas_coords.coordinates.has(block_name):
		current_block = block_name
		update_block()
		info_label.text = "✅ Блок установлен: " + block_name
		line_edit.clear()
	else:
		# Поиск похожих блоков
		var suggestions = []
		for block in available_blocks:
			if block.contains(block_name):
				suggestions.append(block)
				if suggestions.size() >= 5:
					break
		
		if suggestions.size() > 0:
			info_label.text = "❌ Блок не найден. Похожие: " + ", ".join(suggestions)
		else:
			info_label.text = "❌ Блок не найден: " + block_name

func _on_reset_pressed():
	current_block = "stone"
	line_edit.text = ""
	current_lod = 1
	update_lod_buttons()
	update_block()
	info_label.text = "🔄 Сброс к камню"

func _on_lod_pressed(lod: int):
	current_lod = lod
	update_lod_buttons()
	update_block()

func _on_distance_changed(value: float):
	camera.position.z = value
	distance_label.text = "Дистанция до камеры: " + str(value) + " м"
	update_block()

func update_lod_buttons():
	for lod in lod_buttons:
		lod_buttons[lod].button_pressed = (lod == current_lod)
	
	lod_indicator.text = "LOD: x" + str(current_lod)
	
	# Цвет индикатора
	match current_lod:
		1: lod_indicator.modulate = Color(0, 1, 0)  # зелёный
		2: lod_indicator.modulate = Color(1, 1, 0)  # жёлтый
		4: lod_indicator.modulate = Color(1, 0.5, 0)  # оранжевый
		8: lod_indicator.modulate = Color(1, 0, 0)  # красный

func update_block():
	if not atlas_coords or not atlas_coords.coordinates.has(current_block):
		return
	
	# Получаем координаты для текущего LOD
	var coords = get_lod_coords()
	if not coords:
		return
	
	var block_data = coords.coordinates[current_block]
	
	# Создаём материал с текстурой из атласа
	var material = create_block_material(coords, block_data)
	block_mesh.material_override = material

func get_lod_coords() -> AtlasCoordinates:
	if current_lod == 1:
		return atlas_coords
	
	var lod_path = "res://src/assets/textures/atlas/block_coordinates_lod_" + str(current_lod) + ".tres"
	if ResourceLoader.exists(lod_path):
		return load(lod_path)
	
	return atlas_coords

func create_block_material(coords: AtlasCoordinates, block_data: Dictionary) -> StandardMaterial3D:
	# Создаём простой материал
	var material = StandardMaterial3D.new()
	
	# Создаём AtlasTexture для блока
	var atlas_tex = AtlasTexture.new()
	atlas_tex.atlas = coords.atlas_texture
	atlas_tex.region = Rect2(block_data.x, block_data.y, block_data.width, block_data.height)
	
	material.albedo_texture = atlas_tex
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED  # Для яркости
	
	return material
