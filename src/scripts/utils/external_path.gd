extends RefCounted
# Утилита для работы с папкой mods - МАКСИМАЛЬНО ПРОСТАЯ ВЕРСИЯ

static func get_path() -> String:
	
	# ДЛЯ РЕДАКТОРА - жесткий путь, который точно работает
	if Engine.is_editor_hint():
		return "user://atlas/"
	
	# ДЛЯ ЭКСПОРТА - папка mods рядом с exe
	var mods_path = OS.get_executable_path().get_base_dir().path_join("mods")
	return mods_path.path_join("")
