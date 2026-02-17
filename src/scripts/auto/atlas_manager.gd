@tool
extends Node

const ExternalPath = preload("res://src/scripts/utils/external_path.gd")

signal atlas_build_started
signal atlas_build_completed(success: bool)
signal atlas_build_failed(error: String)

var is_building: bool = false
var last_build_time: Dictionary = {}

func _enter_tree():
	print("🚀 AtlasManager: Запуск сборки атласа...")
	call_deferred("_auto_build")

func _auto_build():
	await get_tree().process_frame
	build_atlas()

func build_atlas() -> bool:
	if is_building:
		return false
	
	is_building = true
	atlas_build_started.emit()
	print("\n=== СБОРКА АТЛАСА В user:// ===")
	
	# Собираем атлас напрямую из PNG в user://
	var builder = load("res://src/scripts/tools/atlas_work/texture_atlas_builder.gd").new()
	builder._run()
	
	last_build_time = Time.get_datetime_dict_from_system()
	is_building = false
	
	print("=== СБОРКА ЗАВЕРШЕНА ===\n")
	atlas_build_completed.emit(true)
	return true

func get_atlas_path() -> String:
	return "user://atlas/block_coordinates.tres"

func is_atlas_valid() -> bool:
	return ResourceLoader.exists(get_atlas_path()) \
		and FileAccess.file_exists("user://atlas/block_atlas.png")

func get_last_build_time() -> String:
	if last_build_time.is_empty():
		return "Никогда"
	return "%04d-%02d-%02d %02d:%02d:%02d" % [
		last_build_time.year, last_build_time.month, last_build_time.day,
		last_build_time.hour, last_build_time.minute, last_build_time.second
	]
