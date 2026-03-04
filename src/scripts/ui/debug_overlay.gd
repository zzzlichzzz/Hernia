extends CanvasLayer

# Настройки отображения
@export var show_fps: bool = true
@export var show_memory: bool = true
@export var show_cpu: bool = true
@export var show_gpu: bool = true
@export var show_debug_info: bool = true
@export var show_position: bool = true
@export var update_interval: float = 0.5  # Обновление каждые 0.5 секунд

var _label: Control
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
	panel.offset_bottom = 220
	panel.add_theme_stylebox_override("panel", _create_panel_style())
	add_child(panel)
	
	# Создаём метку
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_following = false
	_label.add_theme_color_override("default_color", Color.GREEN)
	_label.add_theme_font_size_override("font_size", 12)
	_label.text = "Initializing..."
	panel.add_child(_label)
	
	# Созуём таймер для поиска игрока
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
	style.bg_color = Color(0.1, 0.1, 0.1, 0.85)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.2, 0.6, 0.2)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= update_interval:
		_timer = 0.0
		_update_debug_info()

func _update_debug_info() -> void:
	var text = ""
	var border_color = "[color=#33ff33]"  # Ярко-зелёный
	var warn_color = "[color=#ffff33]"    # Жёлтый
	var error_color = "[color=#ff3333]"   # Красный
	var info_color = "[color=#66ccff]"   # Голубой
	var close_color = "[/color]"
	
	# ═══════════════════════════════════════════
	text += border_color + "┌── DEBUG STATS ──┐" + close_color + "\n"
	
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
		
		var fps_color = border_color if fps >= 50 else warn_color if fps >= 30 else error_color
		text += fps_color + "FPS:" + close_color + " %d" % fps
		text += " (avg: %.1f)" % avg_fps + "\n"
	
	# CPU
	if show_cpu:
		var cpu_usage = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0  # в мс
		var cpu_color = border_color if cpu_usage < 10 else warn_color if cpu_usage < 20 else error_color
		text += cpu_color + "CPU:" + close_color + " %.2f ms" % cpu_usage + "\n"
	
	# Задержка (time scale)
	var time_scale = Engine.time_scale
	var time_color = border_color if time_scale >= 1.0 else error_color
	text += time_color + "Time:" + close_color + " %.2fx" % time_scale + "\n"
	
	# GPU (время кадра)
	if show_gpu:
		# Используем косвенный метод - общее время кадра минус время процессора
		var frame_time = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		var gpu_time = frame_time * 0.7  # Примерная оценка
		var gpu_color = border_color if gpu_time < 12 else warn_color if gpu_time < 20 else error_color
		text += gpu_color + "GPU:" + close_color + " ~%.2f ms" % gpu_time + "\n"
	
	# VRAM / Рендеринг
	if show_memory:
		var mem = Performance.get_monitor(Performance.MEMORY_STATIC) / 1024.0 / 1024.0
		var mem_total = Performance.get_monitor(Performance.MEMORY_STATIC_MAX) / 1024.0 / 1024.0
		
		text += border_color + "RAM:" + close_color + " %.1f / %.1f MB" % [mem, mem_total] + "\n"
		# Количество 3D-объектов
		var object_count = Performance.get_monitor(Performance.OBJECT_COUNT)
		text += border_color + "3D Obj:" + close_color + " %d" % object_count + "\n"
	
	# ═══════════════════════════════════════════
	text += border_color + "├── WORLD ────────┤" + close_color + "\n"
	
	# Позиция игрока
	if show_position and _player:
		var pos = _player.global_position
		text += info_color + "Pos:" + close_color + " (%.1f, %.1f, %.1f)" % [pos.x, pos.y, pos.z] + "\n"
		
		# Скорость игрока
		if _player.has_method("get_velocity"):
			var vel = _player.get_velocity()
			var speed = Vector3(vel.x, 0, vel.z).length()
			text += info_color + "Speed:" + close_color + " %.1f m/s" % speed + "\n"
	
	# Количество объектов
	if show_debug_info:
		var objects = get_tree().get_node_count()
		var nodes_color = border_color if objects < 1000 else warn_color if objects < 5000 else error_color
		text += nodes_color + "Objects:" + close_color + " %d" % objects + "\n"
	
	# ═══════════════════════════════════════════
	text += border_color + "└─────────────────┘" + close_color + ""
	
	_label.text = text
