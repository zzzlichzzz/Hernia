@tool
extends EditorScript

func _run():
	if not Engine.is_editor_hint(): return
	EditorInterface.get_resource_filesystem().scan()
	print("Editor refreshed")

static func refresh():
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()
