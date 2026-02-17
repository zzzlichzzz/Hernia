extends RefCounted
# Простой логгер для записи в файл в user://

var log_file: FileAccess
var log_path: String
var enabled: bool = true

func _init(filename: String = "atlas_build_log.txt"):
	log_path = "user://" + filename
	open_log()

func open_log():
	if not enabled:
		return
	
	log_file = FileAccess.open(log_path, FileAccess.WRITE)
	if log_file:
		write_line("=== НАЧАЛО ЛОГА ===")
		write_line("Время: " + Time.get_datetime_string_from_system())
		write_line("")
	else:
		print("❌ НЕ УДАЛОСЬ СОЗДАТЬ ЛОГ-ФАЙЛ: ", log_path)

# 🔥 Переименовано с log() на write_line() чтобы избежать конфликта
func write_line(msg: String):
	print(msg)  # В консоль (если есть)
	if log_file and enabled:
		log_file.store_string(msg + "\n")
		log_file.flush()

func write_raw(msg: String):
	if log_file and enabled:
		log_file.store_string(msg)

func separator(char: String = "=", length: int = 60):
	var line = ""
	for i in range(length):
		line += char
	write_line(line)

func section(title: String):
	separator()
	write_line("🔸 " + title)
	separator()

func success(msg: String):
	write_line("✅ " + msg)

func error(msg: String):
	write_line("❌ " + msg)

func warning(msg: String):
	write_line("⚠️ " + msg)

func info(msg: String):
	write_line("ℹ️ " + msg)

func close():
	if log_file:
		write_line("")
		write_line("=== КОНЕЦ ЛОГА ===")
		log_file.close()
		log_file = null
		print("📝 Лог сохранен в: ", log_path)

func get_log_path() -> String:
	return log_path

func disable():
	enabled = false
	if log_file:
		log_file.close()
		log_file = null

func enable():
	enabled = true
	open_log()
