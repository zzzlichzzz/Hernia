extends Node2D

@onready var line_edit = $CanvasLayer/Control/VBoxContainer/LineEdit
@onready var results_container = $CanvasLayer/Control/VBoxContainer/ScrollContainer/VBoxContainer
@onready var button = $CanvasLayer/Control/VBoxContainer/Button
@onready var path_label = $CanvasLayer/Control/VBoxContainer/Label

# Ссылка на координаты атласа
var AtlasManager = "res://src/scripts/build/atlas/atlas_manager.gd"
var atlas_coords: AtlasCoordinates = null
var atlas_path = "src/assets/textures/atlas/block/block_coordinates.tres"


func _ready():
	# Показываем путь к атласу
	update_path_display()
	
	# Загружаем координаты атласа
	load_atlas_data()
	
	# Подключаем кнопку
	button.pressed.connect(_on_search_pressed)
	
	# Enter тоже работает
	line_edit.text_submitted.connect(_on_search_pressed)
	
	print("✅ Тестовая комната готова!")
	print("📝 Введите название блока (stone, dirt, grass и т.д.)")
	print("🔄 F5 - пересобрать атлас")

func update_path_display():
	if not path_label:
		return
	
	var full_path = "res://src/assets/textures/atlas/"
	path_label.text = "📁 Атлас в: " + full_path
	path_label.modulate = Color(0.8, 0.8, 0.8)

func load_atlas_data():
	if ResourceLoader.exists(atlas_path):
		atlas_coords = load(atlas_path)
		print("✅ Атлас загружен из: ", atlas_path)
		print("📊 Блоков в атласе: ", atlas_coords.coordinates.size())
		print("📦 PNG файл: ", atlas_coords.get_png_path())
	else:
		print("❌ Атлас не найден по пути: ", atlas_path)
		add_result("ОШИБКА", "Атлас не найден! Запустите AtlasManager.build_atlas()")

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
	
	# Проверяем наличие блока
	if not atlas_coords.coordinates.has(block_name):
		add_result("❌ НЕ НАЙДЕН", "Блок '" + block_name + "' отсутствует в атласе")
		show_suggestions(block_name)
		return
	
	# ЗАГОЛОВОК
	add_result("🎯 БЛОК:", block_name)
	add_separator()
	
	var data = atlas_coords.coordinates[block_name]
	
	# Основная информация
	add_result("📌 Позиция в атласе:", "X: " + str(data.x) + "  Y: " + str(data.y))
	add_result("📏 Размер блока:", str(data.width) + "x" + str(data.height))
	
	# Информация об атласе
	if atlas_coords.atlas_texture:
		add_result("🖼️ Размер атласа:", str(atlas_coords.atlas_texture.get_size().x) + "x" + str(atlas_coords.atlas_texture.get_size().y))
	
	# UV координаты
	var uv = data.uv
	add_result("🔷 UV координаты:", "")
	add_result("   Left (U):", str(uv.left))
	add_result("   Top (V):", str(uv.top))
	add_result("   Width:", str(uv.right - uv.left))
	add_result("   Height:", str(uv.bottom - uv.top))
	
	# Превью блока
	await add_preview_to_results(block_name, data)
	
	add_separator()
	
	# Информация о файлах
	add_result("📁 Файл координат:", atlas_path.get_file())
	add_result("📂 PNG атлас:", atlas_coords.png_filename)
	add_result("📌 Полный путь PNG:", atlas_coords.get_png_path())
	
	# Системная информация
	var real_path = "res://src/assets/textures/atlas/"
	add_result("💻 На диске:", real_path)

func add_preview_to_results(block_name: String, data: Dictionary):
	# Создаем контейнер для превью
	var preview_block = VBoxContainer.new()
	preview_block.add_theme_constant_override("separation", 5)
	
	# Метка
	var label = Label.new()
	label.text = "🖼️ ПРЕВЬЮ БЛОКА:"
	label.add_theme_font_size_override("font_size", 14)
	label.modulate = Color(1, 1, 0.8)
	preview_block.add_child(label)
	
	# Контейнер для изображения
	var image_container = HBoxContainer.new()
	
	# Отступ
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(50, 0)
	image_container.add_child(spacer)
	
	# 🔥 ЗАГРУЗКА ИЗОБРАЖЕНИЯ
	var png_path = atlas_coords.get_png_path()
	var texture = null
	
	if FileAccess.file_exists(png_path):
		var img = Image.load_from_file(png_path)
		if img:
			# Проверяем границы
			if data.x + data.width <= img.get_width() and data.y + data.height <= img.get_height():
				var region_img = Image.create(data.width, data.height, false, img.get_format())
				region_img.blit_rect(img, Rect2i(data.x, data.y, data.width, data.height), Vector2i(0, 0))
				texture = ImageTexture.create_from_image(region_img)
				print("✅ Регион вырезан: ", data.x, ",", data.y, " ", data.width, "x", data.height)
			else:
				print("⚠️ Регион выходит за границы: атлас ", img.get_width(), "x", img.get_height())
	
	if texture:
		var preview = TextureRect.new()
		preview.texture = texture
		preview.custom_minimum_size = Vector2(128, 128)
		preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
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
	else:
		var error_label = Label.new()
		error_label.text = "  ❌ Не удалось загрузить PNG\n     " + png_path
		error_label.modulate = Color(1, 0.3, 0.3)
		error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		image_container.add_child(error_label)
		print("❌ Ошибка загрузки PNG: ", png_path)
	
	preview_block.add_child(image_container)
	
	# Информация о размере
	var size_info = Label.new()
	size_info.text = "   Размер блока: " + str(data.width) + "x" + str(data.height) + " px"
	size_info.add_theme_font_size_override("font_size", 12)
	size_info.modulate = Color(0.8, 0.8, 0.8)
	preview_block.add_child(size_info)
	
	results_container.add_child(preview_block)

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
	if label.begins_with("   "):
		result_label.add_theme_font_size_override("font_size", 12)
		result_label.modulate = Color(0.7, 0.7, 0.7)
	
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
		update_path_display()
