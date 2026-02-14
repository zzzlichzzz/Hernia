# Создайте test_lod.gd в корне и запустите
@tool
extends EditorScript

func _run():
	var conv = load("res://src/scripts/tools/atlas_work/convert_png_to_tres.gd").new()
	var lod = load("res://src/scripts/tools/atlas_work/lod_atlas_builder.gd").new()
	conv._run()
	lod._run()
