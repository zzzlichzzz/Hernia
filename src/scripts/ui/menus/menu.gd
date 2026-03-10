extends Control

const GAME_SCENE := "res://src/scenes/world/World.tscn"

func _ready() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.size = Vector2(400, 300)
	vbox.add_theme_constant_override("separation", 20)
	add_child(vbox)
	
	vbox.add_child(_label("HERNIA", 64, Color(0.9, 0.3, 0.3)))
	vbox.add_child(_label("Voxel Game Prototype", 16, Color(0.6, 0.6, 0.6)))
	vbox.add_child(_spacer(40))
	vbox.add_child(_button("Новая игра", Color(0.3, 0.7, 0.3), func(): get_tree().change_scene_to_file(GAME_SCENE)))
	vbox.add_child(_button("Настройки", Color(0.3, 0.5, 0.7), func(): get_tree().change_scene_to_file("res://src/scenes/ui/SettingsMenu.tscn")))
	vbox.add_child(_button("Выход", Color(0.7, 0.3, 0.3), func(): get_tree().quit()))
	vbox.add_child(_label("v0.1.0", 12, Color(0.4, 0.4, 0.4)))

func _spacer(h: int) -> Control:
	var c = Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

func _label(text: String, size: int, color: Color) -> Label:
	var l = Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _button(text: String, color: Color, callback: Callable) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(200, 50)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.add_theme_stylebox_override("normal", _btn_style(color, 0.6))
	btn.add_theme_stylebox_override("hover", _btn_style(color, 0.3))
	btn.add_theme_stylebox_override("pressed", _btn_style(color, 0.7))
	btn.add_theme_font_size_override("font_size", 18)
	btn.pressed.connect(callback)
	return btn

func _btn_style(color: Color, dark: float) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = color.darkened(dark)
	s.border_width_left = 2
	s.border_width_right = 2
	s.border_width_top = 2
	s.border_width_bottom = 2
	s.border_color = color
	s.corner_radius_top_left = 8
	s.corner_radius_top_right = 8
	s.corner_radius_bottom_left = 8
	s.corner_radius_bottom_right = 8
	return s
