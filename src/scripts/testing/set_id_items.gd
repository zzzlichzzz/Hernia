extends Control


@onready var button = $Button
@onready var container_1 = $box_container/container_1
@onready var container_2 = $box_container/container_2
@onready var box_container = $box_container

@onready var example_panel = $box_container/container_1/PanelContainer
@onready var example_string_id = $box_container/container_2/string_id

@onready var ids: Item_Id_Registry = load("res://src/data/items/tres_build/temp/temp.tres")
@onready var items: ItemLibrary = load("res://src/data/items/item_library.tres")

var errors: Dictionary[String, int]

func _ready() -> void:
	
	ids.test_check_blocks(items.getArray("block_item"))
	ids.test_check_items(items.getArray("consumble_item"))
	

	errors = ids.errors
	
	if errors.size() != 0:
		for i in errors.keys():
			var string_id = LineEdit.new()
			var panel = PanelContainer.new()
			panel = example_panel.duplicate()
			string_id = example_string_id.duplicate()
			
			var label: Label = panel.get_child(1)
			label.text = str(errors.get(i))
			string_id.set_text(i)
			
			container_1.add_child(panel)
			container_2.add_child(string_id)
	
	container_1.remove_child(example_panel)
	container_2.remove_child(example_string_id)
	
	button.pressed.connect(save)
	
	
func save() -> void:
	pass
