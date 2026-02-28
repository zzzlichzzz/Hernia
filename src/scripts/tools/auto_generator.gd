extends Node
# Автоматический генератор ресурсов
# Запускает по очереди все необходимые скрипты для обновления атласа и библиотеки блоков
# Прикрепите этот скрипт к любой сцене и запустите сцену для генерации

@export var auto_start: bool = true  # Запускать автоматически при загрузке сцены?
@export var debug_mode: bool = true

# Пути к скриптам
const ATLAS_MANAGER_PATH = "res://src/scripts/auto/atlas_manager.gd"
const BLOCKS_REGISTRY_PATH = "res://src/data/blocks/blocks_registry.gd"

func _ready():
	if auto_start:
		start()

func start():
	print("🚀 АВТОГЕНЕРАТОР: Запуск последовательной сборки ресурсов")
	
	var start_time = Time.get_ticks_msec()
	
	# ШАГ 1: Запускаем AtlasManager
	if not _run_atlas_manager():
		print("❌ АВТОГЕНЕРАТОР: Остановлено из-за ошибки в AtlasManager")
		return
	
	# Небольшая пауза между шагами для надежности
	await get_tree().create_timer(0.3).timeout
	
	# ШАГ 2: Запускаем BlockRegistry
	if not _run_blocks_registry():
		print("❌ АВТОГЕНЕРАТОР: Остановлено из-за ошибки в BlockRegistry")
		return
	
	var end_time = Time.get_ticks_msec()
	var elapsed = (end_time - start_time) / 1000.0
	
	print("✅ АВТОГЕНЕРАТОР: Все ресурсы успешно обновлены за %.2f секунд" % elapsed)
	
	# Опционально: закрыть сцену после завершения
	# await get_tree().create_timer(2.0).timeout
	# queue_free()

func _run_atlas_manager() -> bool:
	print("\n📦 ШАГ 1/2: Запуск AtlasManager...")
	
	if not ResourceLoader.exists(ATLAS_MANAGER_PATH):
		print("❌ AtlasManager не найден по пути: ", ATLAS_MANAGER_PATH)
		return false
	
	var atlas_script = load(ATLAS_MANAGER_PATH)
	if not atlas_script:
		print("❌ Не удалось загрузить AtlasManager")
		return false
	
	var atlas_manager = atlas_script.new()
	if not atlas_manager.has_method("build_atlas"):
		print("❌ AtlasManager: метод build_atlas() не найден")
		return false
	
	var result = atlas_manager.build_atlas()
	if result:
		print("✅ AtlasManager успешно выполнен")
		return true
	else:
		print("❌ AtlasManager вернул ошибку")
		return false

func _run_blocks_registry() -> bool:
	print("\n📦 ШАГ 2/2: Запуск BlockRegistry...")
	
	if not ResourceLoader.exists(BLOCKS_REGISTRY_PATH):
		print("❌ BlockRegistry не найден по пути: ", BLOCKS_REGISTRY_PATH)
		return false
	
	var registry_script = load(BLOCKS_REGISTRY_PATH)
	if not registry_script:
		print("❌ Не удалось загрузить BlockRegistry")
		return false
	
	# Создаем экземпляр
	var registry = registry_script.new()
	
	# Проверяем наличие метода _build_library (как в вашем скрипте)
	if registry.has_method("_build_library"):
		registry._build_library()
		print("✅ BlockRegistry._build_library() выполнен")
		return true
	else:
		print("❌ BlockRegistry: метод _build_library не найден")
		return false
