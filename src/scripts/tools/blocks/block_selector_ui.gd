extends Label

@export var block_selector_path: NodePath = "../BlockSelector"
@onready var _selector: Node = get_node_or_null(block_selector_path)

func _ready():
	if _selector:
		_selector.block_selected.connect(_on_block_selected)
		_update_text(_selector.get_current_block_id(), _selector.get_current_block_name())

func _on_block_selected(block_id: int, block_name: String):
	_update_text(block_id, block_name)

func _update_text(block_id: int, block_name: String):
	text = "🧱 [%d] %s" % [block_id, block_name]
