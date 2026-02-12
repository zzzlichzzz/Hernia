extends Node2D

@onready var line_edit = $CanvasLayer/Control/VBoxContainer/LineEdit
@onready var results_container = $CanvasLayer/Control/VBoxContainer/ScrollContainer/VBoxContainer
@onready var button = $CanvasLayer/Control/VBoxContainer/Button

# Ссылка на атлас
var atlas_coords: AtlasCoordinates = null

func _ready():
	# Загружаем координаты атласа
	load_atlas_data()
	
	# Подключаем кнопку
	button.pressed.connect(_on_search_pressed)
	
	# Enter тоже работает
	line_edit.text_submitted.connect(_on_search_pressed)
	
	print("✅ Тестовая комната готова!")
	print("📝 Введите название блока (stone, dirt, grass_top и т.д.)")

func load_atlas_data():
	var path = "res://src/assets/textures/atlas/block_coordinates.tres"
	if ResourceLoader.exists(path):
		atlas_coords = load(path)
		print("✅ Атлас загружен: ", path)
	else:
		print("❌ Атлас не найден! Сначала соберите атлас.")
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
	
	var data = atlas_coords.coordinates[block_name]
	
	# ДОБАВЛЯЕМ ВСЕ ДАННЫЕ О БЛОКЕ
	add_result("🎯 БЛОК:", block_name)
	add_result("📌 Позиция:", "X: " + str(data.x) + "  Y: " + str(data.y))
	add_result("📏 Размер:", str(data.width) + "x" + str(data.height))
	add_result("🖼️ Индекс в атласе:", str(data.get("index", "N/A")))
	
	# UV координаты
	var uv = data.uv
	add_result("🔷 UV (нормализованные):", "")
	add_result("   Left:", str(uv.left))
	add_result("   Top:", str(uv.top))
	add_result("   Right:", str(uv.right))
	add_result("   Bottom:", str(uv.bottom))
	
	# UV в пикселях (если известен размер атласа)
	if atlas_coords.atlas_texture:
		var atlas_size = atlas_coords.atlas_texture.get_size()
		add_result("📐 UV в пикселях:", "")
		add_result("   X:", str(data.x) + " px")
		add_result("   Y:", str(data.y) + " px")
		add_result("   Width:", str(data.width) + " px")
		add_result("   Height:", str(data.height) + " px")
		add_result("   Атлас:", str(atlas_size.x) + "x" + str(atlas_size.y) + " px")
	
	# Дополнительная информация
	add_result("⚡ Прямая ссылка:", "AtlasCoordinates.get_uv('" + block_name + "')")
	
	# Показываем пример использования
	add_result("📋 Пример кода:", "")
	add_result("   var uv = AtlasCoordinates.get_uv('" + block_name + "')")
	add_result("   material.set_shader_parameter('block_uv', uv)")

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
		# Показываем первые 5 блоков как пример
		var example_blocks = []
		var i = 0
		for block in atlas_coords.coordinates.keys():
			example_blocks.append(block)
			i += 1
			if i >= 5:
				break
		add_result("📋 Доступные блоки:", ", ".join(example_blocks) + "...")

# ИСПРАВЛЕНО: добавлены значения по умолчанию и тип String
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
