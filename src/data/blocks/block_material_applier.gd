@tool
extends Node
# Скрипт для применения материала к блокам и обновления путей мешера

var BLOCKS_FOLDER = PathManager.smart("res://src/data/blocks/definitions/")
var MODELS_FOLDER = PathManager.smart("res://src/assets/blocks/")
var MATERIALS_FOLDER = PathManager.smart("res://src/assets/textures/atlas/")
var LIBRARY_PATH = PathManager.smart("res://src/data/blocks/voxel_blocky_library.tres")
var MESHER_PATH = PathManager.smart("res://src/data/blocks/voxel_mesher_blocky.tres")

var debug_mode: bool = true

# Соответствие типов материалов и файлов
var material_files = {
	"opaque": "block_material_opaque.tres",
	"transparent": "block_material_transparent.tres",
	"foliage": "block_material_foliage.tres"
}

func run():
	if debug_mode:
		print("🎨 BLOCK MATERIAL APPLIER: Применение материалов и обновление путей")
	
	# ШАГ 1: Обновляем путь в мешере
	_update_mesher_path()
	
	# ШАГ 2: Читаем файл библиотеки
	var content = _read_file(LIBRARY_PATH)
	if content.is_empty():
		if debug_mode:
			print("❌ Не удалось прочитать файл библиотеки")
		return
	
	if debug_mode:
		print("📄 Файл библиотеки прочитан")
	
	# ШАГ 3: Загружаем все определения блоков
	var definitions = _load_definitions()
	if definitions.is_empty():
		if debug_mode:
			print("⚠️ Нет определений блоков")
	
	# ШАГ 4: Модифицируем содержимое библиотеки
	var modified_content = _modify_library_content(content, definitions)
	
	# ШАГ 5: Сохраняем изменения в библиотеке
	if modified_content != content:
		if _write_file(LIBRARY_PATH, modified_content):
			if debug_mode:
				print("✅ Библиотека обновлена с материалами")
		else:
			if debug_mode:
				print("❌ Ошибка сохранения библиотеки")
	else:
		if debug_mode:
			print("⏭️ Изменений в библиотеке не требуется")

func _update_mesher_path():
	"""Обновляет путь к библиотеке в файле мешера"""
	if debug_mode:
		print("\n🔧 Обновление пути в мешере: ", MESHER_PATH)
	
	# Читаем файл мешера
	var content = _read_file(MESHER_PATH)
	if content.is_empty():
		if debug_mode:
			print("⚠️ Файл мешера не найден или пуст")
		return
	
	if debug_mode:
		print("📄 Файл мешера прочитан")
	
	# Получаем правильный путь к библиотеке
	var correct_library_path = LIBRARY_PATH
	
	# Ищем строку с ext_resource типа VoxelBlockyLibrary
	var lines = content.split("\n")
	var modified_lines = []
	var modified = false
	
	for line in lines:
		if line.begins_with("[ext_resource") and line.find("VoxelBlockyLibrary") != -1:
			# Проверяем, правильный ли уже путь
			if line.find(correct_library_path) == -1:
				# Извлекаем uid и id
				var uid_match = RegEx.new()
				uid_match.compile('uid="([^"]+)"')
				var uid_result = uid_match.search(line)
				
				var id_match = RegEx.new()
				id_match.compile('id="([^"]+)"')
				var id_result = id_match.search(line)
				
				var uid = uid_result.get_string(1) if uid_result else ""
				var id = id_result.get_string(1) if id_result else "1_61eru"
				
				# Создаем новую строку с правильным путем
				var new_line = '[ext_resource type="VoxelBlockyLibrary"'
				if uid != "":
					new_line += ' uid="' + uid + '"'
				new_line += ' path="' + correct_library_path + '" id="' + id + '"]'
				
				modified_lines.append(new_line)
				modified = true
				if debug_mode:
					print("   ✅ Путь обновлен: ", new_line)
			else:
				modified_lines.append(line)
		else:
			modified_lines.append(line)
	
	if modified:
		var new_content = "\n".join(modified_lines)
		if _write_file(MESHER_PATH, new_content):
			if debug_mode:
				print("✅ Файл мешера обновлен")
		else:
			if debug_mode:
				print("❌ Ошибка сохранения файла мешера")
	else:
		if debug_mode:
			print("⏭️ Путь в мешере уже актуален")

func _load_definitions() -> Dictionary:
	"""Загружает все определения блоков и возвращает словарь имя->определение"""
	var definitions = {}
	var def_files = _find_definition_files()
	
	for file_path in def_files:
		var def_resource = load(file_path)
		if def_resource and def_resource is BlockDefinition:
			definitions[def_resource.block_name] = def_resource
	
	if debug_mode:
		print("📚 Загружено определений: ", definitions.size())
	
	return definitions

func _find_definition_files() -> Array:
	"""Находит все .tres файлы определений блоков"""
	var files = []
	var dir = DirAccess.open(BLOCKS_FOLDER)
	if not dir:
		return files
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres") and file_name != "block_definition.gd":
			files.append(BLOCKS_FOLDER + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	
	return files

func _modify_library_content(content: String, definitions: Dictionary) -> String:
	"""Модифицирует содержимое библиотеки, добавляя материалы для блоков"""
	var lines = content.split("\n")
	var modified_lines = []
	var ext_resources = {}
	var mesh_ext_ids = {}  # mesh_ext_id -> block_name
	var next_ext_id = 1
	var modified = false
	var last_mesh_line_index = -1
	
	# Сначала собираем все существующие ext_resource и находим последний mesh
	for i in range(lines.size()):
		var current_line = lines[i]
		if current_line.begins_with("[ext_resource"):
			var id_match = RegEx.new()
			id_match.compile('id="([^"]+)"')
			var id_result = id_match.search(current_line)
			
			var path_match = RegEx.new()
			path_match.compile('path="([^"]+)"')
			var path_result = path_match.search(current_line)
			
			if id_result and path_result:
				var ext_id = id_result.get_string(1)
				var path = path_result.get_string(1)
				ext_resources[ext_id] = path
				
				# Определяем максимальный ID
				if ext_id.is_valid_int():
					var num = ext_id.to_int()
					if num >= next_ext_id:
						next_ext_id = num + 1
				elif "_" in ext_id:
					var parts = ext_id.split("_")
					if parts[0].is_valid_int():
						var num = parts[0].to_int()
						if num >= next_ext_id:
							next_ext_id = num + 1
				
				# Запоминаем позицию последнего mesh
				if path.ends_with(".obj"):
					last_mesh_line_index = i
					# Извлекаем имя блока из пути
					var block_name = path.get_file().trim_suffix(".obj")
					mesh_ext_ids[ext_id] = block_name
	
	if debug_mode:
		print("🔍 Найдено mesh ресурсов: ", mesh_ext_ids.size())
		print("📌 Последний mesh на строке: ", last_mesh_line_index)
	
	# Проходим по строкам и собираем измененный контент
	var material_ext_ids = {}
	
	# Сначала копируем все строки до последнего mesh
	for i in range(last_mesh_line_index + 1):
		modified_lines.append(lines[i])
	
	# Добавляем материалы для каждого блока
	for mesh_ext_id in mesh_ext_ids:
		var block_name = mesh_ext_ids[mesh_ext_id]
		
		if block_name in definitions:
			var def = definitions[block_name]
			
			# Определяем тип материала
			var material_type = _get_material_type_from_def(def)
			
			# Формируем путь к материалу
			var material_file = material_files.get(material_type, material_files["opaque"])
			var material_path = MATERIALS_FOLDER + material_file
			
			# Проверяем, есть ли уже такой материал
			var material_ext_id = ""
			for ext_id in ext_resources:
				if ext_resources[ext_id] == material_path:
					material_ext_id = ext_id
					break
			
			# Если нет, создаем новый
			if material_ext_id == "":
				material_ext_id = str(next_ext_id) + "_" + _random_string(5)
				next_ext_id += 1
				var ext_line = '[ext_resource type="Material" path="' + material_path + '" id="' + material_ext_id + '"]'
				modified_lines.append(ext_line)
				modified = true
				if debug_mode:
					print("   ✅ Добавлен ext_resource для материала: ", material_ext_id)
	
	# Добавляем остальные строки после последнего mesh
	var line_idx = last_mesh_line_index + 1
	while line_idx < lines.size():
		var current_line = lines[line_idx]
		
		# Модифицируем подресурсы, добавляя material_override
		if current_line.begins_with("[sub_resource type=\"VoxelBlockyModelMesh\""):
			modified_lines.append(current_line)
			
			# Собираем следующие строки до следующего подресурса или [resource]
			var j = line_idx + 1
			var resource_lines = []
			var block_name = ""
			
			while j < lines.size() and not lines[j].begins_with("[sub_resource") and not lines[j].begins_with("[resource]"):
				resource_lines.append(lines[j])
				
				# Ищем resource_name
				if lines[j].begins_with("resource_name = "):
					var name_match = RegEx.new()
					name_match.compile('resource_name = "([^"]+)"')
					var name_result = name_match.search(lines[j])
					if name_result:
						block_name = name_result.get_string(1)
				
				j += 1
			
			# Если нашли имя блока и есть определение
			if block_name != "" and block_name in definitions:
				var def = definitions[block_name]
				
				# Определяем тип материала
				var material_type = _get_material_type_from_def(def)
				
				# Формируем путь к материалу
				var material_file = material_files.get(material_type, material_files["opaque"])
				var material_path = MATERIALS_FOLDER + material_file
				
				# Находим ID материала
				var material_ext_id = ""
				for ext_id in ext_resources:
					if ext_resources[ext_id] == material_path:
						material_ext_id = ext_id
						break
				
				# Если не нашли среди существующих, ищем среди новых
				if material_ext_id == "":
					for mod_line in modified_lines:
						if mod_line.begins_with("[ext_resource") and material_path in mod_line:
							var id_match = RegEx.new()
							id_match.compile('id="([^"]+)"')
							var id_result = id_match.search(mod_line)
							if id_result:
								material_ext_id = id_result.get_string(1)
								break
				
				# Проверяем, есть ли уже material_override в resource_lines
				var has_override = false
				for rl in resource_lines:
					if rl.begins_with("material_override_"):
						has_override = true
						break
				
				if not has_override and material_ext_id != "":
					# Добавляем строку material_override
					resource_lines.insert(0, 'material_override_0 = ExtResource("' + material_ext_id + '")')
					modified = true
					if debug_mode:
						print("   ✅ Добавлен material_override для блока: ", block_name)
			
			# Добавляем все строки ресурса
			for rl in resource_lines:
				modified_lines.append(rl)
			
			# Продолжаем с того места, где остановились
			line_idx = j
		else:
			modified_lines.append(current_line)
			line_idx += 1
	
	if modified:
		return "\n".join(modified_lines)
	else:
		return content

func _get_material_type_from_def(def: BlockDefinition) -> String:
	"""Извлекает тип материала из определения блока"""
	if "material_type" in def and def.get("material_type") != null:
		return def.material_type
	elif "material_type_enum" in def:
		match def.material_type_enum:
			def.MaterialType.OPAQUE:
				return "opaque"
			def.MaterialType.TRANSPARENT:
				return "transparent"
			def.MaterialType.FOLIAGE:
				return "foliage"
	return "opaque"

func _random_string(length: int) -> String:
	"""Генерирует случайную строку заданной длины"""
	var chars = "abcdefghijklmnopqrstuvwxyz"
	var result = ""
	for i in range(length):
		result += chars[randi() % chars.length()]
	return result

func _read_file(path: String) -> String:
	"""Читает файл и возвращает содержимое"""
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return ""
	return file.get_as_text()

func _write_file(path: String, content: String) -> bool:
	"""Записывает содержимое в файл"""
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return false
	file.store_string(content)
	file.close()
	return true
