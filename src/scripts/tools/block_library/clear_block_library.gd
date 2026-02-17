@tool
extends EditorScript
# Скрипт для очистки voxel_blocky_library.tres

@export var library_path: String = "res://src/data/blocks/voxel_blocky_library.tres"

func _run():
	print("🧹 Очистка библиотеки блоков...")
	
	# Проверяем существует ли файл
	if not ResourceLoader.exists(library_path):
		print("❌ Библиотека не найдена по пути: ", library_path)
		return
	
	# Загружаем библиотеку
	var library = load(library_path)
	if not library:
		print("❌ Не удалось загрузить библиотеку")
		return
	
	# 🔥 ИСПРАВЛЕНИЕ: используем get_model_count()
	print("📊 Текущее состояние:")
	print("  - Моделей до очистки: ", library.get_model_count())
	
	# 🔥 ПОЛНАЯ ОЧИСТКА - создаем новую библиотеку
	var new_library = VoxelBlockyLibrary.new()
	
	# Сохраняем новую (пустую) библиотеку поверх старой
	var result = ResourceSaver.save(new_library, library_path)
	
	if result == OK:
		print("✅ Библиотека успешно очищена!")
		
		# Перезагружаем чтобы увидеть результат
		var cleared_library = load(library_path)
		print("  - Моделей после очистки: ", cleared_library.get_model_count())
	else:
		print("❌ Ошибка сохранения библиотеки. Код: ", result)
