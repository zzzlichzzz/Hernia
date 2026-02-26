@tool
extends EditorScript

func _run():
	print("═══ ДИАГНОСТИКА МЕШЕЙ ═══")
	
	var paths = [
		"res://src/assets/blocks/models/cube.obj",
		"res://src/assets/blocks/models/multi_surface_cube.obj"
	]
	
	for path in paths:
		if not ResourceLoader.exists(path):
			print("❌ Не найден: ", path)
			continue
		
		var mesh = load(path) as Mesh
		if mesh == null:
			print("❌ Не удалось загрузить: ", path)
			continue
		
		print("\n📐 ", path.get_file())
		print("   Тип: ", mesh.get_class())
		print("   Surfaces: ", mesh.get_surface_count())
		
		for i in mesh.get_surface_count():
			var arrays = mesh.surface_get_arrays(i)
			var vertex_count = 0
			if arrays[Mesh.ARRAY_VERTEX] != null:
				vertex_count = arrays[Mesh.ARRAY_VERTEX].size()
			
			var mat = mesh.surface_get_material(i)
			var mat_name = "none"
			if mat:
				mat_name = mat.resource_name if mat.resource_name != "" else str(mat)
			
			print("   Surface ", i, ": vertices=", vertex_count, " material=", mat_name)
	
	print("\n═══ ГОТОВО ═══")
