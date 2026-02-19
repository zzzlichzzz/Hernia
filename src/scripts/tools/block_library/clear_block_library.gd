@tool
extends EditorScript
# Сбрасывает voxel_blocky_library.tres до чистого состояния через текстовое редактирование

const LIBRARY_PATH = "res://src/data/blocks/voxel_blocky_library.tres"

func _run():
	print("🔄 СБРОС БИБЛИОТЕКИ БЛОКОВ ДО ЧИСТОГО СОСТОЯНИЯ")
	
	# ШАГ 1: Проверяем существование файла
	if not FileAccess.file_exists(LIBRARY_PATH):
		print("❌ Файл не существует: ", LIBRARY_PATH)
		return
	
	print("📁 Файл найден: ", LIBRARY_PATH)
	
	# ШАГ 2: Читаем текущее содержимое
	print("\n📖 Чтение текущего содержимого...")
	var content = _read_file(LIBRARY_PATH)
	if content.is_empty():
		print("❌ Файл пуст или не удалось прочитать")
		return
	
	print("✅ Текущее содержимое прочитано (", content.length(), " символов)")
	
	# ШАГ 3: Извлекаем UID из текущего файла
	var uid = _extract_uid(content)
	if uid:
		print("🔑 Найден UID: ", uid)
	else:
		print("⚠️ UID не найден, будет создан новый при сохранении")
	
	# ШАГ 4: Создаем чистое содержимое
	print("\n🧹 Создание чистого содержимого...")
	var clean_content = _create_clean_content(uid)
	print("✅ Чистое содержимое создано")
	
	# ШАГ 5: Записываем обратно
	print("\n💾 Запись чистого содержимого...")
	if _write_file(LIBRARY_PATH, clean_content):
		print("✅ Файл успешно перезаписан")
	else:
		print("❌ Ошибка записи файла")
		return
	
	# ШАГ 6: Проверяем результат
	print("\n🔎 Проверка результата...")
	var new_content = _read_file(LIBRARY_PATH)
	if new_content == clean_content:
		print("✅ Содержимое совпадает с ожидаемым")
	else:
		print("⚠️ Содержимое не совпадает (возможно, Godot изменил формат)")
	
	# ШАГ 7: Обновляем FileSystem в редакторе
	print("\n🔄 Обновление FileSystem...")
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()
		print("✅ FileSystem обновлен")
	
	print("✅ СБРОС ЗАВЕРШЕН")

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
	# Ищем паттерн uid="uid://..."
	var regex = RegEx.new()
	regex.compile("uid=\"(uid://[^\"]+)\"")
	var result = regex.search(content)
	
	if result:
		return result.get_string(1)
	return ""

func _create_clean_content(uid: String = "") -> String:
	"""Создает чистое содержимое для библиотеки"""
	var result = "[gd_resource type=\"VoxelBlockyLibrary\" format=3"
	
	if uid and not uid.is_empty():
		result += " uid=\"" + uid + "\""
	
	result += "]\n\n[resource]"
	
	return result

# Дополнительная функция для отладки: показывает текущее состояние
static func debug_print_library():
	var path = "res://src/data/blocks/voxel_blocky_library.tres"
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		print("\n=== СОДЕРЖИМОЕ БИБЛИОТЕКИ ===\n")
		print(file.get_as_text())
		file.close()
