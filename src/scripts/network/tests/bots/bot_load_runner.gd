class_name BotLoadRunner
extends Node

## Запускает пачку bot-клиентов для нагрузочного теста.
## Может быть запущен как отдельная сцена ИЛИ как дочерний Node внутри test menu.

@export var address: String = "127.0.0.1"
@export var port: int = 9999

@export_range(1, 500, 1) var bot_count: int = 20
@export_range(0.0, 2.0, 0.01) var connect_interval: float = 0.05
@export_range(0.0, 5.0, 0.01) var initial_delay: float = 0.25
@export_range(0.0, 30.0, 0.1) var movement_start_delay: float = 5.0

@export var auth_token: String = "my_game_v1"

## 0 = IDLE, 1 = CIRCLE, 2 = RANDOM_WALK
@export_range(0, 2, 1) var bot_mode: int = BotVirtualPlayer.Mode.CIRCLE

@export_range(0.5, 10.0, 0.5) var log_interval: float = 2.0

var _bots: Array[BotClient] = []
var _ready_count: int = 0
var _disconnect_count: int = 0
var _log_timer: float = 0.0
var _started: bool = false


func _ready() -> void:
	start_runner()


func start_runner() -> void:
	if _started:
		return
	_started = true

	print("[bot-runner] starting %d bots → %s:%d mode=%s" % [
		bot_count, address, port, _mode_name(bot_mode)
	])

	for i in range(bot_count):
		var bot := BotClient.new()
		bot.name = "BotClient_%03d" % i

		var delay := initial_delay + float(i) * connect_interval
		bot.setup(address, port, i, bot_mode, delay, auth_token, movement_start_delay)

		bot.bot_ready.connect(_on_bot_ready)
		bot.bot_disconnected.connect(_on_bot_disconnected)

		add_child(bot)
		_bots.append(bot)


func shutdown_runner() -> void:
	for bot in _bots:
		if bot != null and is_instance_valid(bot):
			bot.shutdown_bot()
			bot.queue_free()

	_bots.clear()
	_ready_count = 0
	_disconnect_count = 0
	_started = false


func get_status_snapshot() -> Dictionary:
	var active: int = 0
	for bot in _bots:
		if bot != null and is_instance_valid(bot) and bot.is_ready_for_test():
			active += 1

	return {
		"active": active,
		"total": bot_count,
		"ready_events": _ready_count,
		"disconnects": _disconnect_count,
		"mode": _mode_name(bot_mode),
	}


func _process(delta: float) -> void:
	_log_timer += delta
	if _log_timer >= log_interval:
		_log_timer = 0.0
		_print_status()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		shutdown_runner()
		get_tree().quit()


func _on_bot_ready(_peer_id: int) -> void:
	_ready_count += 1


func _on_bot_disconnected(_peer_id: int) -> void:
	_disconnect_count += 1


func _print_status() -> void:
	var status := get_status_snapshot()
	print("[bot-runner] active=%d/%d  ready_events=%d  disconnects=%d  mode=%s" % [
		status["active"],
		status["total"],
		status["ready_events"],
		status["disconnects"],
		status["mode"],
	])


func _mode_name(mode_value: int) -> String:
	match mode_value:
		BotVirtualPlayer.Mode.IDLE:
			return "IDLE"
		BotVirtualPlayer.Mode.CIRCLE:
			return "CIRCLE"
		BotVirtualPlayer.Mode.RANDOM_WALK:
			return "RANDOM_WALK"
		_:
			return "UNKNOWN"
