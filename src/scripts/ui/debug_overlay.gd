extends CanvasLayer

@export var show_fps: bool = true
@export var show_memory: bool = true
@export var show_cpu: bool = true
@export var show_gpu: bool = true
@export var show_debug_info: bool = true
@export var show_position: bool = true
@export var update_interval: float = 0.5

var _label: Control
var _timer: float = 0.0
var _fps_history: Array = []
var _player: Node3D = null


var _voxel_tool: VoxelTool = null

func _ready():
	layer = 100
	var panel = PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = -220
	panel.offset_top = 5
	panel.offset_right = -5
	panel.offset_bottom = 220
	panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(panel)
	
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.add_theme_color_override("default_color", Color.GREEN)
	_label.add_theme_font_size_override("font_size", 12)
	_label.text = "Initializing..."
	panel.add_child(_label)
	
	get_tree().create_timer(0.5).timeout.connect(_find_player)

func _find_player():
	_player = get_tree().get_first_node_in_group("player")
	if not _player: _player = get_tree().current_scene.get_node_or_null("../Players/LocalPlayer/HumanPlayer")

func _panel_style() -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.1, 0.1, 0.1, 0.85)
	s.border_width_left = 2
	s.border_width_right = 2
	s.border_width_top = 2
	s.border_width_bottom = 2
	s.border_color = Color(0.2, 0.6, 0.2)
	s.corner_radius_top_left = 4
	s.corner_radius_top_right = 4
	s.corner_radius_bottom_left = 4
	s.corner_radius_bottom_right = 4
	return s

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= update_interval:
		_timer = 0.0
		_update_debug_info()
		if _player == null:
			_player = get_tree().current_scene.get_node_or_null("/root/ClientMain/World/Players/LocalPlayer")
			_voxel_tool = get_tree().current_scene.get_node_or_null("/root/ClientMain/World/VoxelTerrain").get_voxel_tool()
			#_voxel_tool.channel = VoxelBuffer.CHANNEL_TYPE
			#_voxel_tool.mode = VoxelTool.MODE_SET

func _update_debug_info() -> void:
	var bc = "[color=#33ff33]"; var wc = "[color=#ffff33]"; var ec = "[color=#ff3333]"; var ic = "[color=#66ccff]"; var cc = "[/color]"
	var text = bc + "┌── DEBUG STATS ──┐" + cc + "\n"
	
	if show_fps:
		var fps = Engine.get_frames_per_second()
		_fps_history.append(fps)
		if _fps_history.size() > 30: _fps_history.pop_front()
		var avg = float(_fps_history.reduce(func(a, b): return a + b, 0)) / _fps_history.size()
		text += (bc if fps >= 50 else wc if fps >= 30 else ec) + "FPS:" + cc + " %d (avg: %.1f)" % [fps, avg] + "\n"
	
	if show_cpu:
		var cpu = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		text += (bc if cpu < 10 else wc if cpu < 20 else ec) + "CPU:" + cc + " %.2f ms" % cpu + "\n"
	
	var ts = Engine.time_scale
	text += (bc if ts >= 1.0 else ec) + "Time:" + cc + " %.2fx" % ts + "\n"
	
	if show_gpu:
		var gpu = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0 * 0.7
		text += (bc if gpu < 12 else wc if gpu < 20 else ec) + "GPU:" + cc + " ~%.2f ms" % gpu + "\n"
	
	if show_memory:
		var mem = Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
		var mem_max = Performance.get_monitor(Performance.MEMORY_STATIC_MAX) / 1048576.0
		var mem_buffer = Performance.get_monitor(Performance.MEMORY_MESSAGE_BUFFER_MAX)
		text += bc + "RAM:" + cc + " %.1f / %.1f MB" % [mem, mem_max] + "\n"
		text += bc + "Memory Buffer:" + cc + " %.1f" % [mem_buffer] + "\n"
		text += bc + "3D Obj:" + cc + " %d" % Performance.get_monitor(Performance.OBJECT_COUNT) + "\n"
	
	text += bc + "├── WORLD ────────┤" + cc + "\n"
	
	if show_position and _player:
		var pos = _player.global_position
		var pos_target = Vector3i(0, 0, 0)
		if _player._camera != null:
			#var positon = _player._get_raycast().get_collider()
			var origin = _player._camera.global_position
			var forward = -_player._camera.global_transform.basis.z.normalized()

			var hit = _voxel_tool.raycast(origin, forward, 10.0)
			if hit:
				pos_target = hit.position

				
		text += ic + "Pos:" + cc + " (%.1f, %.1f, %.1f)" % [pos.x, pos.y, pos.z] + "\n"
		if _player.has_method("get_velocity"):
			var sp = Vector3(_player.get_velocity().x, 0, _player.get_velocity().z).length()
			text += ic + "Speed:" + cc + " %.1f m/s" % sp + "\n"
		text += ic + "Target pos:" + cc + " (%.1f, %.1f, %.1f)" % [pos_target.x, pos_target.y, pos_target.z] + "\n"
	
	if show_debug_info:
		var objs = get_tree().get_node_count()
		text += (bc if objs < 1000 else wc if objs < 5000 else ec) + "Objects:" + cc + " %d" % objs + "\n"
	
	text += bc + "└─────────────────┘" + cc
	_label.text = text
