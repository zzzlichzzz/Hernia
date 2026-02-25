extends Control

@onready var slots_container = $HBoxContainer
var player: Node

func _ready():
	# Поиск игрока
	player = _find_player(get_tree().get_current_scene())
	if player:
		player.hotbar_changed.connect(_on_player_hotbar_changed)
		_initialize_hotbar(player.available_blocks)
	else:
		push_error("Player не найден! Убедитесь, что в сцене есть CharacterBody3D с именем 'Player' или добавьте его в группу 'player'.")

func _find_player(node: Node) -> Node:
	if node is CharacterBody3D:
		return node
	for child in node.get_children():
		var found = _find_player(child)
		if found:
			return found
	return null

func _initialize_hotbar(blocks: Array):
	# Очистка старых слотов
	for child in slots_container.get_children():
		child.queue_free()

	# Создание слотов
	for i in range(blocks.size()):
		var slot = create_slot(blocks[i]["icon"], str(i + 1))
		slots_container.add_child(slot)
		if i == 0:
			set_slot_selected(slot, true)

func create_slot(icon_texture: Texture2D, number_text: String) -> Control:
	var panel = Panel.new()
	panel.size = Vector2(60, 60)
	panel.add_theme_stylebox_override("panel", get_theme_stylebox("panel", "Panel"))

	var texture_rect = TextureRect.new()
	texture_rect.texture = icon_texture
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	texture_rect.size = Vector2(40, 40)
	texture_rect.position = Vector2(10, 10)
	panel.add_child(texture_rect)

	var label = Label.new()
	label.text = number_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.size = Vector2(50, 50)
	label.position = Vector2(5, 5)
	label.add_theme_color_override("font_color", Color.WHITE)
	panel.add_child(label)

	return panel

func set_slot_selected(slot: Control, selected: bool):
	if selected:
		slot.modulate = Color.YELLOW
	else:
		slot.modulate = Color.WHITE

func _on_player_hotbar_changed(active_index: int):
	for i in range(slots_container.get_child_count()):
		var slot = slots_container.get_child(i)
		set_slot_selected(slot, i == active_index)
