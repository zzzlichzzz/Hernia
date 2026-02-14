extends Node2D

@onready var line_edit = $CanvasLayer/Control/VBoxContainer/LineEdit
@onready var results_container = $CanvasLayer/Control/VBoxContainer/ScrollContainer/VBoxContainer
@onready var button = $CanvasLayer/Control/VBoxContainer/Button

# Ссылки на атласы
var atlas_coords: AtlasCoordinates = null
var lod_atlases: Dictionary = {}  # { factor: AtlasCoordinates }

func _ready():
	# Загружаем координаты атласа
	load_atlas_data()
	
	# Подключаем кнопку
	button.pressed.connect(_on_search_pressed)
	
	# Enter тоже работает
	line_edit.text_submitted.connect(_on_search_pressed)
	
	print("✅ Тестовая комната готова!")
	print("📝 Введите название блока (stone, dirt, grass_top и т.д.)")
	print("🔄 F5 - пересобрать атлас")

func load_atlas_data():
	var path = "res://src/assets/textures/atlas/block_coordinates.tres"
	if ResourceLoader.exists(path):
		atlas_coords = load(path)
		print("✅ Атлас загружен: ", path)
		
		# Загружаем LOD атласы
		load_lod_atlases()
	else:
		print("❌ Атлас не найден! Сначала соберите атлас.")
		add_result("ОШИБКА", "Атлас не найден! Запустите AtlasManager.build_atlas()")

func load_lod_atlases():
	lod_atlases.clear()
	
	# Проверяем наличие LOD атласов
	var lod_factors = [2, 4, 8]
	var found = 0
	
	for factor in lod_factors:
		var lod_path = "res://src/assets/textures/atlas/block_coordinates_lod_" + str(factor) + ".tres"
		if ResourceLoader.exists(lod_path):
			lod_atlases[factor] = load(lod_path)
			print("✅ LOD x" + str(factor) + " загружен")
			found += 1
	
	if found > 0:
		print("📊 Загружено LOD: ", found)

func _on_search_pressed(_text = ""):
	var block_name = line_edit.text.strip_edges().to_lower()
	
	if block_name.is_empty():
		add_result("⚠️", "Введите название блока")
		return
	
	if not atlas_coords:
		add_result("❌", "Атлас не загружен")
		load_atlas_data()
		return
	
	display_block_info(block_name)
	line_edit.clear()

func display_block_info(block_name: String):
	# Очищаем старые результаты
	clear_results()
	
	# Проверяем наличие блока в оригинале
	if not atlas_coords.coordinates.has(block_name):
		add_result("❌ НЕ НАЙДЕН", "Блок '" + block_name + "' отсутствует в атласе")
		show_suggestions(block_name)
		return
	
	# ЗАГОЛОВОК
	add_result("🎯 БЛОК:", block_name)
	add_separator()
	
	# ПОКАЗЫВАЕМ ВСЕ LOD УРОВНИ (ВКЛЮЧАЯ X1)
	var all_levels = [1, 2, 4, 8]
	
	for factor in all_levels:
		var coords = get_atlas_for_level(factor)
		if coords and coords.coordinates.has(block_name):
			display_block_at_level(block_name, factor, coords)
	
	# Сравнительная таблица размеров
	add_result("📋 СРАВНЕНИЕ РАЗМЕРОВ:", "")
	for factor in all_levels:
		var coords = get_atlas_for_level(factor)
		if coords and coords.coordinates.has(block_name):
			var data = coords.coordinates[block_name]
			var size_str = str(data.width) + "x" + str(data.height)
			var atlas_size = " (" + str(coords.atlas_texture.get_size().x) + "x" + str(coords.atlas_texture.get_size().y) + ")"
			add_result("   LOD x" + str(factor) + ":", size_str + atlas_size)

func display_block_at_level(block_name: String, factor: int, coords: AtlasCoordinates):
	var data = coords.coordinates[block_name]
	var atlas_size = coords.atlas_texture.get_size()
	
	add_result("   🔷 LOD x" + str(factor) + ":", "")
	add_result("      📌 Позиция:", "X: " + str(data.x) + "  Y: " + str(data.y))
	add_result("      📏 Размер:", str(data.width) + "x" + str(data.height))
	add_result("      🖼️ Атлас:", str(atlas_size.x) + "x" + str(atlas_size.y))
	
	# UV координаты
	var uv = data.uv
	add_result("      🔷 UV:", "")
	add_result("         Left:", str(uv.left))
	add_result("         Top:", str(uv.top))
	add_result("         Right:", str(uv.right))
	add_result("         Bottom:", str(uv.bottom))
	
	# Процент от оригинала
	var orig_data = atlas_coords.coordinates[block_name]
	var percent_x = float(data.width) / orig_data.width * 100
	var percent_y = float(data.height) / orig_data.height * 100
	add_result("      📊 От оригинала:", str(round(percent_x)) + "% x " + str(round(percent_y)) + "%")
	
	# ПРЕВЬЮ ДЛЯ КАЖДОГО LOD (ВКЛЮЧАЯ X1)
	var preview_texture = get_preview_texture(block_name, factor)
	if preview_texture:
		add_preview_to_results(preview_texture, factor)
	
	add_result("      ---", "")

func get_preview_texture(block_name: String, factor: int) -> AtlasTexture:
	if factor == 1:
		return atlas_coords.get_atlas_texture_for_block(block_name)
	elif lod_atlases.has(factor) and lod_atlases[factor].coordinates.has(block_name):
		return lod_atlases[factor].get_atlas_texture_for_block(block_name)
	return null

func add_preview_to_results(texture: AtlasTexture, factor: int):
	# Вертикальный контейнер для всего блока превью
	var preview_block = VBoxContainer.new()
	preview_block.add_theme_constant_override("separation", 5)
	
	# Метка сверху
	var label = Label.new()
	label.text = "         🖼️ Превью LOD x" + str(factor) + ":"
	label.add_theme_font_size_override("font_size", 13)
	label.modulate = Color(1, 1, 0.8)
	preview_block.add_child(label)
	
	# Горизонтальный контейнер для изображения
	var image_container = HBoxContainer.new()
	
	# Отступ слева (увеличен для лучшего выравнивания)
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(70, 0)
	image_container.add_child(spacer)
	
	# Большое изображение с NEAREST фильтром
	var preview = TextureRect.new()
	preview.texture = texture
	preview.custom_minimum_size = Vector2(128, 128)
	preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.modulate = Color(1, 1, 1, 1)
	
	# NEAREST FILTER ДЛЯ ЧЁТКИХ ПИКСЕЛЕЙ
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	
	# Рамка
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 0.8)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.6, 0.6, 0.6)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	preview.add_theme_stylebox_override("normal", style)
	
	image_container.add_child(preview)
	
	# Информация о размере
	var size_info = Label.new()
	size_info.text = "         Размер: " + str(texture.region.size.x) + "x" + str(texture.region.size.y) + " px"
	size_info.add_theme_font_size_override("font_size", 11)
	size_info.modulate = Color(0.8, 0.8, 0.8)
	
	preview_block.add_child(image_container)
	preview_block.add_child(size_info)
	
	results_container.add_child(preview_block)

func get_atlas_for_level(factor: int) -> AtlasCoordinates:
	if factor == 1:
		return atlas_coords
	elif lod_atlases.has(factor):
		return lod_atlases[factor]
	return null

func show_suggestions(input: String):
	var suggestions = []
	for block in atlas_coords.coordinates.keys():
		if block.contains(input):
			suggestions.append(block)
			if suggestions.size() >= 5:
				break
	
	if suggestions.size() > 0:
		add_result("💡 Похожие блоки:", ", ".join(suggestions))
	else:
		# Показываем первые 10 блоков как пример
		var example_blocks = []
		var i = 0
		for block in atlas_coords.coordinates.keys():
			example_blocks.append(block)
			i += 1
			if i >= 10:
				break
		add_result("📋 Доступные блоки:", ", ".join(example_blocks) + "...")

func add_separator():
	var sep = Label.new()
	sep.modulate = Color(0.5, 0.5, 0.5)
	results_container.add_child(sep)

func add_result(label: String, value: String = ""):
	var result_label = Label.new()
	result_label.text = label + " " + value
	
	# Стилизация
	if label.contains("❌"):
		result_label.modulate = Color(1, 0.3, 0.3)
	elif label.contains("✅") or label.contains("🎯"):
		result_label.modulate = Color(0.3, 1, 0.3)
		result_label.add_theme_font_size_override("font_size", 16)
	elif label.contains("📌") or label.contains("📏"):
		result_label.modulate = Color(0.8, 0.8, 1)
	elif label.contains("🔷"):
		result_label.modulate = Color(0.6, 0.8, 1)
	
	# Отступы для вложенных элементов
	if label.begins_with("      "):
		result_label.add_theme_font_size_override("font_size", 12)
		result_label.modulate = Color(0.7, 0.7, 0.7)
	elif label.begins_with("         "):
		result_label.add_theme_font_size_override("font_size", 11)
		result_label.modulate = Color(0.6, 0.6, 0.6)
	
	results_container.add_child(result_label)

func clear_results():
	for child in results_container.get_children():
		child.queue_free()

# Горячие клавиши для тестирования
func _input(event):
	if event.is_action_pressed("ui_accept") and line_edit.has_focus():
		_on_search_pressed()
	
	# F5 - пересобрать атлас
	if event.is_action_pressed("ui_accept") and Input.is_key_pressed(KEY_F5):
		print("🔄 Ручная пересборка атласа...")
		AtlasManager.build_atlas()
		# Перезагружаем данные
		await get_tree().create_timer(0.5).timeout
		load_atlas_data()
