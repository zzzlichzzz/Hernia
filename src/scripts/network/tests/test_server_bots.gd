extends Control

const SERVER_SCENE := "res://src/scripts/network/ServerMain.tscn"

const MODE_IDLE := 0
const MODE_CIRCLE := 1
const MODE_RANDOM_WALK := 2

@onready var title_label: Label = $CenterContainer/VBoxContainer/Title
@onready var btn_connect: Button = $CenterContainer/VBoxContainer/BtnConnect
@onready var btn_single: Button = $CenterContainer/VBoxContainer/BtnSingle
@onready var btn_server: Button = $CenterContainer/VBoxContainer/BtnServer
@onready var btn_client: Button = $CenterContainer/VBoxContainer/BtnClient
@onready var btn_evil_client: Button = $CenterContainer/VBoxContainer/BtnEvilClient
@onready var btn_exit: Button = $CenterContainer/VBoxContainer/ExitBtn
@onready var vbox: VBoxContainer = $CenterContainer/VBoxContainer

var _runner: BotLoadRunner = null
var _pending_mode: int = MODE_IDLE
var _pending_mode_name: String = "IDLE"

var _count_spin: SpinBox = null
var _status_label: Label = null
var _status_timer: float = 0.0

# ── Кастомный popup ─────────────────────────────
var _popup_overlay: ColorRect = null
var _popup_center: CenterContainer = null
var _popup_panel: PanelContainer = null
var _popup_info_label: Label = null
var _popup_btn_start: Button = null
var _popup_btn_cancel: Button = null


func _ready() -> void:
	_setup_ui()
	_create_bot_settings_popup()

	btn_connect.pressed.connect(_on_btn_connect_pressed)
	btn_single.pressed.connect(_on_btn_idle_pressed)
	btn_server.pressed.connect(_on_btn_server_pressed)
	btn_client.pressed.connect(_on_btn_circle_pressed)
	btn_evil_client.pressed.connect(_on_btn_random_pressed)
	btn_exit.pressed.connect(_on_btn_exit_pressed)


func _process(delta: float) -> void:
	if _runner == null or not is_instance_valid(_runner):
		return

	_status_timer += delta
	if _status_timer >= 0.5:
		_status_timer = 0.0
		_refresh_runner_status()


func _unhandled_input(event: InputEvent) -> void:
	if _popup_overlay != null and _popup_overlay.visible:
		if event is InputEventKey and event.pressed:
			if event.keycode == KEY_ESCAPE:
				_hide_bot_settings_popup()
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
				_on_popup_start_pressed()
				get_viewport().set_input_as_handled()


# ══════════════════════════════════════════════════
#  UI SETUP
# ══════════════════════════════════════════════════

func _setup_ui() -> void:
	title_label.text = "ТЕСТ СЕРВЕРА И БОТОВ"

	btn_single.text = "Запустить IDLE ботов"
	btn_server.text = "Запустить сервер"
	btn_client.text = "Запустить CIRCLE ботов"
	btn_evil_client.text = "Запустить RANDOM WALK ботов"
	btn_exit.text = "Выход"

	_status_label = Label.new()
	_status_label.name = "RunnerStatusLabel"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.text = "Bot runner не запущен"
	_status_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))

	vbox.add_child(_status_label)
	vbox.move_child(_status_label, vbox.get_child_count() - 1)


func _create_bot_settings_popup() -> void:
	# Затемнение фона
	_popup_overlay = ColorRect.new()
	_popup_overlay.name = "BotPopupOverlay"
	_popup_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_popup_overlay.color = Color(0.0, 0.0, 0.0, 0.55)
	_popup_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_popup_overlay.visible = false
	add_child(_popup_overlay)

	# Центровщик
	_popup_center = CenterContainer.new()
	_popup_center.name = "PopupCenter"
	_popup_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_popup_center.mouse_filter = Control.MOUSE_FILTER_STOP
	_popup_overlay.add_child(_popup_center)

	# Панель
	_popup_panel = PanelContainer.new()
	_popup_panel.name = "BotSettingsPanel"
	_popup_panel.custom_minimum_size = Vector2(420, 220)
	_popup_center.add_child(_popup_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_popup_panel.add_child(margin)

	var popup_vbox := VBoxContainer.new()
	popup_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(popup_vbox)

	var popup_title := Label.new()
	popup_title.text = "НАСТРОЙКИ БОТОВ"
	popup_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup_title.add_theme_font_size_override("font_size", 22)
	popup_vbox.add_child(popup_title)

	_popup_info_label = Label.new()
	_popup_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_popup_info_label.text = "Выберите режим и количество ботов."
	popup_vbox.add_child(_popup_info_label)

	var count_label := Label.new()
	count_label.text = "Количество ботов:"
	popup_vbox.add_child(count_label)

	_count_spin = SpinBox.new()
	_count_spin.min_value = 1
	_count_spin.max_value = 500
	_count_spin.step = 1
	_count_spin.value = 25
	_count_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	popup_vbox.add_child(_count_spin)

	var hint_label := Label.new()
	hint_label.text = "Enter — запустить, Esc — отмена"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	popup_vbox.add_child(hint_label)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 12)
	popup_vbox.add_child(button_row)

	_popup_btn_start = Button.new()
	_popup_btn_start.text = "Запустить"
	_popup_btn_start.custom_minimum_size = Vector2(140, 42)
	_popup_btn_start.pressed.connect(_on_popup_start_pressed)
	button_row.add_child(_popup_btn_start)

	_popup_btn_cancel = Button.new()
	_popup_btn_cancel.text = "Отмена"
	_popup_btn_cancel.custom_minimum_size = Vector2(140, 42)
	_popup_btn_cancel.pressed.connect(_on_popup_cancel_pressed)
	button_row.add_child(_popup_btn_cancel)


func _refresh_runner_status() -> void:
	if _runner == null or not is_instance_valid(_runner):
		_status_label.text = "Bot runner не запущен"
		return

	var s: Dictionary = _runner.get_status_snapshot()
	_status_label.text = "Bot runner: mode=%s  active=%d/%d  ready=%d  disconnects=%d" % [
		s.get("mode", "UNKNOWN"),
		int(s.get("active", 0)),
		int(s.get("total", 0)),
		int(s.get("ready_events", 0)),
		int(s.get("disconnects", 0)),
	]


# ══════════════════════════════════════════════════
#  BUTTONS
# ══════════════════════════════════════════════════

func _on_btn_connect_pressed() -> void:
		print("Подключение к серверу...")
		get_tree().change_scene_to_file("res://src/scripts/network/ClientMain.tscn")

func _on_btn_idle_pressed() -> void:
	_open_bot_settings(MODE_IDLE, "IDLE", 25)


func _on_btn_server_pressed() -> void:
	print("Запуск сервера...")
	var err := get_tree().change_scene_to_file(SERVER_SCENE)
	if err != OK:
		push_error("Не удалось открыть сцену сервера: %s" % error_string(err))


func _on_btn_circle_pressed() -> void:
	_open_bot_settings(MODE_CIRCLE, "CIRCLE", 25)


func _on_btn_random_pressed() -> void:
	_open_bot_settings(MODE_RANDOM_WALK, "RANDOM_WALK", 25)


func _on_btn_exit_pressed() -> void:
	if _runner != null and is_instance_valid(_runner):
		_runner.shutdown_runner()
		_runner.queue_free()
		_runner = null

	get_tree().quit()


# ══════════════════════════════════════════════════
#  POPUP FLOW
# ══════════════════════════════════════════════════

func _open_bot_settings(mode_value: int, mode_name: String, default_count: int) -> void:
	_pending_mode = mode_value
	_pending_mode_name = mode_name
	_count_spin.value = default_count

	_popup_info_label.text = "Режим: %s\nВведите количество ботов и нажмите «Запустить»." % mode_name
	_set_main_menu_visible(false)
	_popup_overlay.visible = true
	_count_spin.grab_focus()


func _hide_bot_settings_popup() -> void:
	_popup_overlay.visible = false
	_set_main_menu_visible(true)


func _on_popup_start_pressed() -> void:
	var count := int(_count_spin.value)
	_hide_bot_settings_popup()
	_start_bot_runner(count, _pending_mode)


func _on_popup_cancel_pressed() -> void:
	_hide_bot_settings_popup()


# ══════════════════════════════════════════════════
#  BOT LAUNCH
# ══════════════════════════════════════════════════

func _start_bot_runner(count: int, mode_value: int) -> void:
	if _runner != null and is_instance_valid(_runner):
		_runner.shutdown_runner()
		_runner.queue_free()
		_runner = null

	_runner = BotLoadRunner.new()
	_runner.name = "BotLoadRunner"

	_runner.address = "127.0.0.1"
	_runner.port = 9999
	_runner.bot_count = count
	_runner.bot_mode = mode_value
	_runner.auth_token = "my_game_v1"
	_runner.initial_delay = 0.2
	_runner.connect_interval = _suggest_connect_interval(count)
	_runner.log_interval = 2.0

	add_child(_runner)

	_status_timer = 0.0
	_refresh_runner_status()

	print("[menu] Bot runner started: mode=%s count=%d connect_interval=%.3f" % [
		_pending_mode_name,
		count,
		_runner.connect_interval,
	])


func _suggest_connect_interval(count: int) -> float:
	if count <= 10:
		return 0.10
	if count <= 25:
		return 0.08
	if count <= 50:
		return 0.06
	if count <= 100:
		return 0.05
	if count <= 200:
		return 0.04
	if count <= 500:
		return 0.03
	return 0.02

func _set_main_menu_visible(visible: bool) -> void:
	btn_single.visible = visible
	btn_server.visible = visible
	btn_client.visible = visible
	btn_evil_client.visible = visible
	btn_exit.visible = visible
