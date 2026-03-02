extends CanvasLayer

# Настройки отображения
@export var show_fps: bool = true
@export var show_memory: bool = true
@export var show_debug_info: bool = true
@export var show_position: bool = true
@export var update_interval: float = 0.5  # Обновление каждые 0.5 секунд

var _label: Label
var _timer: float = 0.0
var _fps_history: Array = []
var _player: Node3D = null
var _timer_node: Timer = null

func _ready():
	# Создаём слой для отладки
	layer = 100
	
	# Создаём контейнер (справа сверху)
	var panel = PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = -220
	panel.offset_top = 5
	panel.offset_right = -5
	panel.offset_bottom = 150
	panel.add_theme_stylebox_override("panel", _create_panel_style())
	add_child(panel)
	
	# Создаём метку
	_label = Label.new()
	_label.add_theme_color_override("font_color", Color.GREEN)
	_label.add_theme_font_size_override("font_size", 12)
	_label.text = "Initializing..."
	panel.add_child(_label)
	
	# Создаём таймер для поиска игрока
	_timer_node = Timer.new()
	_timer_node.wait_time = 0.5
	_timer_node.one_shot = true
	_timer_node.timeout.connect(_find_player)
	add_child(_timer_node)
	_timer_node.start()

func _find_player():
	_player = get_tree().get_first_node_in_group("player")
	if not _player:
		# Пробуем найти через текущую сцену
		var scene = get_tree().current_scene
		if scene:
			_player = scene.get_node_or_null("Player")
	if not _player:
		# Пробуем найти любой CharacterBody3D
		_player = get_tree().get_first_node_in_group("player")

func _create_panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.3, 0.3, 0.3)
	return style

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= update_interval:
		_timer = 0.0
		_update_debug_info()

func _update_debug_info() -> void:
	var text = ""
	
	# FPS
	if show_fps:
		var fps = Engine.get_frames_per_second()
		_fps_history.append(fps)
		if _fps_history.size() > 30:
			_fps_history.pop_front()
		
		var avg_fps = 0
		for f in _fps_history:
			avg_fps += f
		avg_fps = avg_fps / _fps_history.size()
		
		var color = Color.GREEN if fps >= 50 else Color.YELLOW if fps >= 30 else Color.RED
		text += "FPS: %d (avg: %.1f)\n" % [fps, avg_fps]
	
	# Память
	if show_memory:
		var mem = Performance.get_monitor(Performance.MEMORY_STATIC) / 1024.0 / 1024.0
		var mem_total = Performance.get_monitor(Performance.MEMORY_STATIC_MAX) / 1024.0 / 1024.0
		text += "Memory: %.1f MB / %.1f MB\n" % [mem, mem_total]
	
	# Позиция игрока
	if show_position and _player:
		var pos = _player.global_position
		text += "Position: (%.1f, %.1f, %.1f)\n" % [pos.x, pos.y, pos.z]
		
		# Скорость игрока
		if _player.has_method("get_velocity"):
			var vel = _player.get_velocity()
			var speed = Vector3(vel.x, 0, vel.z).length()
			text += "Speed: %.1f m/s\n" % speed
	
	# Количество объектов
	if show_debug_info:
		text += "Objects: %d\n" % get_tree().get_node_count()
	
	_label.text = text
