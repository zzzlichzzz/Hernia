@tool
extends EditorScript
# Просто обновляет FileSystem в редакторе

func _run():
	print("🔄 ОБНОВЛЕНИЕ РЕДАКТОРА")
	
	if not Engine.is_editor_hint():
		print("❌ Скрипт работает только в редакторе")
		return
	
	# Обновляем файловую систему
	print("📁 Сканирование FileSystem...")
	EditorInterface.get_resource_filesystem().scan()
	print("✅ Готово!")
	
	# Маленькая пауза для визуального эффекта
	
	print("\n✨ Редактор обновлен")

# Еще более простая версия (без await)
static func refresh():
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()
		print("🔄 Редактор обновлен")
