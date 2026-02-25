@tool
extends EditorScript
# Ручной автозапуск генерации ассетов через EditorScript
# Запуск: Script → Run (или Ctrl+Shift+X)
# Порядок выполнения:
# 1. AtlasManager - сборка атласа и создание материалов
# 2. BlockRegistry - сборка библиотеки блоков

const AtlasManager = preload("res://src/scripts/auto/atlas_manager.gd")
const BlockRegistry = preload("res://src/data/blocks/blocks_registry.gd")

@export var debug_mode: bool = true

func _run():
	print("🚀 АВТОГЕНЕРАТОР: Запуск полной сборки")
	
	var start_time = Time.get_ticks_msec()
	
	# ШАГ 1: Запускаем AtlasManager
	print("\n📦 ШАГ 1/2: AtlasManager - сборка атласа и материалов")
	
	var atlas_manager = AtlasManager.new()
	var result = atlas_manager.build_atlas()
	if result:
		print("✅ AtlasManager.build_atlas() завершил работу")
	else:
		print("⚠️ AtlasManager.build_atlas() вернул false")
	
	# ШАГ 2: Запускаем BlockRegistry
	print("\n📦 ШАГ 2/2: BlockRegistry - сборка библиотеки блоков")
	
	# 🔥 ИСПРАВЛЕНО: создаём экземпляр и вызываем _build_library()
	var block_registry = BlockRegistry.new()
	if block_registry.has_method("_build_library"):
		# Устанавливаем auto_build в true если нужно
		if block_registry.has_method("set"):
			block_registry.set("auto_build", true)
			block_registry.set("debug_mode", debug_mode)
		
		block_registry._build_library()
		print("✅ BlockRegistry._build_library() завершил работу")
	else:
		print("❌ BlockRegistry: метод _build_library не найден")
	
	var end_time = Time.get_ticks_msec()
	var elapsed = (end_time - start_time) / 1000.0
	
	print("✅ АВТОГЕНЕРАЦИЯ ЗАВЕРШЕНА за %.2f секунд" % elapsed)
