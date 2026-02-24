@tool
extends Node
# Инструмент для создания модели блока из определения (для BlockRegistry)

# 🔥 Получаем путь к папке с exe (в редакторе это папка Godot.exe)
var _exe_path = OS.get_executable_path().get_base_dir().path_join("")

# 🔥 ВСЕ ПУТИ ВЕДУТ В ПАПКУ РЯДОМ С EXE
var BLOCKS_DEFINITIONS = _exe_path + "/src/data/blocks/definitions/"
var MODELS_TARGET = _exe_path + "/src/assets/blocks/"
var MODELS_SOURCE = _exe_path + "/src/assets/blocks/models/"

var debug_mode: bool = true

func run():
	if debug_mode:
		print("🧱 BLOCK CREATOR: Запуск создания моделей")
		print("📁 Путь к EXE: ", _exe_path)
		print("📁 BLOCKS_DEFINITIONS: ", BLOCKS_DEFINITIONS)
		print("📁 MODELS_SOURCE: ", MODELS_SOURCE)
		print("📁 MODELS_TARGET: ", MODELS_TARGET)
	
	# Проверяем существование папок
	if not DirAccess.dir_exists_absolute(BLOCKS_DEFINITIONS):
		if debug_mode:
			print("❌ Папка не найдена: ", BLOCKS_DEFINITIONS)
			print("   Убедитесь, что папка src/data/blocks/definitions/ существует рядом с EXE")
		return
	
	# ШАГ 1: Получаем список всех определений блоков
	if debug_mode:
		print("\n📁 ШАГ 1: Поиск определений блоков")
	var definition_files = _find_definition_files()
	if definition_files.is_empty():
		if debug_mode:
			print("❌ Нет файлов определений в: ", BLOCKS_DEFINITIONS)
		return
	
	if debug_mode:
		print("📋 Найдено определений: ", definition_files.size())
	
	var processed = 0
	var skipped = 0
	var errors = 0
	
	# Обрабатываем каждое определение
	for file_path in definition_files:
		var result = _process_definition(file_path)
		match result:
			0:
				processed += 1
			1:
				skipped += 1
			2:
				errors += 1
	
	if debug_mode:
		print("📊 РЕЗУЛЬТАТ:")
		print("   ✅ Обработано: ", processed)
		print("   ⏭️ Пропущено: ", skipped)
		print("   ❌ Ошибок: ", errors)

func _process_definition(file_path: String) -> int:
	"""Обрабатывает один файл определения. Возвращает 0=успех, 1=пропуск, 2=ошибка"""
	if debug_mode:
		print("\n🔧 Обработка: ", file_path.get_file())
	
	# Загружаем определение
	var def_resource = load(file_path)
	if not def_resource or not def_resource is BlockDefinition:
		if debug_mode:
			print("   ❌ Неверный формат определения")
		return 2
	
	var def: BlockDefinition = def_resource
	
	# Проверяем наличие модели
	if def.model == null:
		if debug_mode:
			print("   ⏭️ Модель не выбрана, пропускаем")
		return 1
	
	if debug_mode:
		print("   📦 Блок: ", def.block_name)
	
	# Получаем имя файла из пути модели
	var source_file_name = _get_model_filename_from_path(def.model)
	if source_file_name.is_empty():
		if debug_mode:
			print("   ❌ Не удалось определить имя файла модели")
		return 2
	
	# Формируем полный путь к исходной модели в папке рядом с exe
	var source_model_path = MODELS_SOURCE + source_file_name
	
	if debug_mode:
		print("   🔍 Исходная модель: ", source_model_path)
	
	# Проверяем существование исходной модели
	if not FileAccess.file_exists(source_model_path):
		if debug_mode:
			print("   ❌ Исходная модель не найдена: ", source_model_path)
		return 2
	
	# Определяем целевую модель
	var target_model_name = def.block_name + ".obj"
	var target_model_path = MODELS_TARGET + target_model_name
	
	if debug_mode:
		print("   📁 Целевая модель: ", target_model_path)
	
	# Проверяем, нужно ли копировать
	if FileAccess.file_exists(target_model_path):
		var source_time = FileAccess.get_modified_time(source_model_path)
		var target_time = FileAccess.get_modified_time(target_model_path)
		
		if source_time <= target_time:
			if debug_mode:
				print("   ⏭️ Модель уже актуальна: ", target_model_name)
			return 1
	
	# Создаем папку назначения если нужно
	var target_dir = target_model_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(target_dir):
		DirAccess.make_dir_recursive_absolute(target_dir)
		if debug_mode:
			print("   📁 Создана папка: ", target_dir)
	
	# Копируем модель
	if _copy_file(source_model_path, target_model_path):
		if debug_mode:
			print("   ✅ Модель скопирована: ", target_model_name)
		
		# Обновляем определение с новым путем
		var new_model_path_res = "res://src/assets/blocks/" + target_model_name
		var updated = _update_definition_model(file_path, new_model_path_res)
		
		if updated:
			if debug_mode:
				print("   ✅ Определение обновлено")
			return 0
		else:
			if debug_mode:
				print("   ❌ Ошибка обновления определения")
			return 2
	else:
		if debug_mode:
			print("   ❌ Ошибка копирования")
		return 2

func _get_model_filename_from_path(model_resource) -> String:
	"""Извлекает имя файла из ресурса модели"""
	if model_resource == null:
		return ""
	
	var path = ""
	if model_resource.has_method("get_resource_path"):
		path = model_resource.get_resource_path()
	elif model_resource is ArrayMesh and model_resource.resource_path != "":
		path = model_resource.resource_path
	
	if path.is_empty():
		return ""
	
	return path.get_file()

func _find_definition_files() -> Array:
	"""Находит все .tres файлы определений блоков"""
	var files = []
	var dir = DirAccess.open(BLOCKS_DEFINITIONS)
	if not dir:
		if debug_mode:
			print("⚠️ Папка не найдена: ", BLOCKS_DEFINITIONS)
		return files
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres") and file_name != "block_definition.gd":
			files.append(BLOCKS_DEFINITIONS + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	
	return files

func _copy_file(source: String, target: String) -> bool:
	"""Копирует файл из source в target"""
	var src_file = FileAccess.open(source, FileAccess.READ)
	if not src_file:
		if debug_mode:
			print("   ❌ Не удалось прочитать: ", source)
		return false
	
	var data = src_file.get_buffer(src_file.get_length())
	var dst_file = FileAccess.open(target, FileAccess.WRITE)
	if not dst_file:
		if debug_mode:
			print("   ❌ Не удалось создать: ", target)
		return false
	
	dst_file.store_buffer(data)
	return true

func _update_definition_model(def_path: String, new_model_path: String) -> bool:
	"""Обновляет ссылку на модель в файле определения"""
	var content = _read_file(def_path)
	if content.is_empty():
		return false
	
	var lines = content.split("\n")
	var updated_lines = []
	var ext_resources = {}
	var model_ext_id = ""
	
	# Компилируем регулярные выражения
	var id_regex = RegEx.new()
	id_regex.compile('id="([^"]+)"')
	
	var path_regex = RegEx.new()
	path_regex.compile('path="([^"]+)"')
	
	var ext_regex = RegEx.new()
	ext_regex.compile('ExtResource\\(\\"([^"]+)\\"\\)')
	
	# Сначала собираем все внешние ресурсы
	for line in lines:
		if line.begins_with("[ext_resource"):
			var id_result = id_regex.search(line)
			var path_result = path_regex.search(line)
			
			if id_result and path_result:
				ext_resources[path_result.get_string(1)] = id_result.get_string(1)
	
	# Ищем какой ID используется для model
	for line in lines:
		if line.begins_with("model = "):
			var ext_result = ext_regex.search(line)
			if ext_result:
				model_ext_id = ext_result.get_string(1)
	
	# Если нашли ID, удаляем старый ext_resource и добавляем новый
	if model_ext_id != "":
		# Фильтруем строки, удаляя старый ext_resource
		for line in lines:
			var skip = false
			if line.begins_with("[ext_resource") and line.find(model_ext_id) != -1:
				skip = true
			if not skip:
				updated_lines.append(line)
		
		# Добавляем новый ext_resource в начало
		var new_ext = '[ext_resource type="ArrayMesh" path="' + new_model_path + '" id="' + model_ext_id + '"]'
		updated_lines.insert(1, new_ext)
		
		var new_content = "\n".join(updated_lines)
		return _write_file(def_path, new_content)
	
	return false

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

# Метод для установки пути к exe (если нужно передать извне)
func set_exe_path(path: String):
	_exe_path = path
	BLOCKS_DEFINITIONS = _exe_path + "/src/data/blocks/definitions/"
	MODELS_TARGET = _exe_path + "/src/assets/blocks/"
	MODELS_SOURCE = _exe_path + "/src/assets/blocks/models/"
