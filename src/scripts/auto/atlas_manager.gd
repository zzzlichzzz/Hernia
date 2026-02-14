@tool
extends Node

signal atlas_build_started
signal atlas_build_completed(success: bool)

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
	print("\n=== СБОРКА АТЛАСА ===")
	
	# 1. Конвертируем PNG → TRES
	var converter = load("uid://d0t12g4uuj2pl")
	if converter:
		var c = converter.new()
		c.target_folder = "res://src/assets/textures/blocks/"
		c.include_subfolders = true
		c.delete_png_after_conversion = false
		c._run()
	
	# 2. Собираем атлас
	var builder = load("uid://dsf2sjlbrik45")
	if builder:
		var b = builder.new()
		b.blocks_folder = "res://src/assets/textures/blocks/"
		b.output_folder = "res://src/assets/textures/atlas/"
		b.delete_source_textures = true
		b.allow_mixed_sizes = true
		b._run()
	
	last_build_time = Time.get_datetime_dict_from_system()
	is_building = false
	
	print("=== СБОРКА ЗАВЕРШЕНА ===\n")
	atlas_build_completed.emit(true)
	return true

static func build() -> bool:
	var manager = Engine.get_main_loop().root.get_node_or_null("/root/AtlasManager")
	if manager:
		return manager.build_atlas()
	print("❌ AtlasManager не найден!")
	return false

func is_atlas_valid() -> bool:
	return ResourceLoader.exists("res://src/assets/textures/atlas/block_atlas.tres") \
		and ResourceLoader.exists("res://src/assets/textures/atlas/block_coordinates.tres")

func get_last_build_time() -> String:
	if last_build_time.is_empty():
		return "Никогда"
	return "%04d-%02d-%02d %02d:%02d:%02d" % [
		last_build_time.year, last_build_time.month, last_build_time.day,
		last_build_time.hour, last_build_time.minute, last_build_time.second
	]
