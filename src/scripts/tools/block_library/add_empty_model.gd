@tool
extends EditorScript
# Добавляет воздух в библиотеку через прямое редактирование текста

const LIBRARY_PATH = "res://src/data/blocks/voxel_blocky_library.tres"

func _run():
	print("🧪 ТЕСТ: ДОБАВЛЕНИЕ ВОЗДУХА ЧЕРЕЗ РЕДАКТИРОВАНИЕ ТЕКСТА")
	
	# ШАГ 1: Читаем текущее содержимое файла
	print("\n📁 ШАГ 1: Чтение файла")
	var content = _read_file(LIBRARY_PATH)
	if content.is_empty():
		print("❌ Не удалось прочитать файл или файл пуст")
		return
	
	print("✅ Файл прочитан (", content.length(), " символов)")
	
	# ШАГ 2: Извлекаем UID из текущего файла
	var uid = _extract_uid(content)
	if uid:
		print("🔑 Найден UID: ", uid)
	else:
		print("⚠️ UID не найден, будет создан новый")
	
	# ШАГ 3: Создаем новое содержимое с воздухом
	print("\n🔄 ШАГ 2: Создание содержимого с воздухом")
	var new_content = _create_content_with_air(uid)
	print("✅ Новое содержимое создано")
	
	# ШАГ 4: Записываем обратно
	print("\n💾 ШАГ 3: Запись файла")
	if _write_file(LIBRARY_PATH, new_content):
		print("✅ Файл успешно записан")
	else:
		print("❌ Ошибка записи файла")
		return
	
	# ШАГ 5: Проверяем результат
	print("\n🔎 ШАГ 4: Проверка")
	var check_content = _read_file(LIBRARY_PATH)
	if "VoxelBlockyModelEmpty" in check_content and "air" in check_content:
		print("✅ Воздух успешно добавлен в файл")
	else:
		print("⚠️ Воздух не найден в файле")
	
	# ШАГ 6: Обновляем FileSystem
	print("\n🔄 ШАГ 5: Обновление FileSystem")
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()
		print("✅ FileSystem обновлен")

	print("✅ ТЕСТ ЗАВЕРШЕН")

func _read_file(path: String) -> String:
	"""Читает файл и возвращает содержимое"""
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		print("❌ Не удалось открыть файл для чтения: ", path)
		return ""
	
	var content = file.get_as_text()
	file.close()
	return content

func _write_file(path: String, content: String) -> bool:
	"""Записывает содержимое в файл"""
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		print("❌ Не удалось открыть файл для записи: ", path)
		return false
	
	file.store_string(content)
	file.close()
	return true

func _extract_uid(content: String) -> String:
	"""Извлекает UID из содержимого файла"""
	var regex = RegEx.new()
	regex.compile("uid=\"(uid://[^\"]+)\"")
	var result = regex.search(content)
	
	if result:
		return result.get_string(1)
	return ""

func _create_content_with_air(uid: String = "") -> String:
	"""Создает содержимое библиотеки с воздухом"""
	var result = ""
	
	# Заголовок
	result += "[gd_resource type=\"VoxelBlockyLibrary\" format=3"
	if uid and not uid.is_empty():
		result += " uid=\"" + uid + "\""
	result += "]\n\n"
	
	# Подресурс для воздуха
	var air_id = _generate_random_id("VoxelBlockyModelEmpty")
	result += "[sub_resource type=\"VoxelBlockyModelEmpty\" id=\"" + air_id + "\"]\n"
	result += "resource_name = \"air\"\n\n"
	
	# Основной массив моделей
	result += "[resource]\n"
	result += "models = Array[VoxelBlockyModel]([SubResource(\"" + air_id + "\")])\n"
	
	return result

func _generate_random_id(base: String) -> String:
	"""Генерирует случайный ID для подресурса"""
	var chars = "abcdefghijklmnopqrstuvwxyz0123456789"
	var random_part = ""
	for i in range(6):
		random_part += chars[randi() % chars.length()]
	return base + "_" + random_part
