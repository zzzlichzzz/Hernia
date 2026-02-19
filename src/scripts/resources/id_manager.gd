extends RefCounted
class_name IDManager
# Минимальная версия - только для генерации уникальных ID

var used_ids: Dictionary = {}
const CHARS = "abcdefghijklmnopqrstuvwxyz0123456789"

func _init(existing_content: String = ""):
	if existing_content:
		_load_existing_ids(existing_content)

func _load_existing_ids(content: String):
	var regex = RegEx.new()
	regex.compile("id=\"([^\"]+)\"")
	
	var pos = 0
	while pos < content.length():
		var result = regex.search(content, pos)
		if not result:
			break
		used_ids[result.get_string(1)] = true
		pos = result.get_end()
	
	print("📊 IDManager: Загружено ", used_ids.size(), " ID")

func generate_model_id() -> String:
	return _generate_unique_id("VoxelBlockyModelMesh")

func generate_empty_id() -> String:
	return _generate_unique_id("VoxelBlockyModelEmpty")

func _generate_unique_id(base: String) -> String:
	for attempt in range(100):
		var random_part = ""
		for i in range(6):
			random_part += CHARS[randi() % CHARS.length()]
		var candidate = base + "_" + random_part
		
		if candidate not in used_ids:
			used_ids[candidate] = true
			return candidate
	
	var fallback = base + "_" + str(Time.get_ticks_usec())
	used_ids[fallback] = true
	return fallback

func get_stats() -> Dictionary:
	return {"used_ids": used_ids.size()}
