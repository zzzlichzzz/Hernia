class_name BaseInteraction
extends Node3D

## Базовый модуль взаимодействия с сетевой поддержкой.
##
## Наследники регистрируют действия через _register_actions()
## и реализуют _on_module_ready / _on_remote_action.
## Сетевой код писать НЕ нужно.
##
## Модуль автономен: добавил к игроку — работает,
## убрал — ничего не ломается.

# ══════════════════════════════════════════════════
#  СОСТОЯНИЕ
# ══════════════════════════════════════════════════

var _is_local: bool = true
var _network_id: int = 0
var _nam: NetworkActionManager = null
var _actions_registered: bool = false

# Зарегистрированные действия: { "action_name" → true }
var _registered_actions: Dictionary = {}


# ══════════════════════════════════════════════════
#  LIFECYCLE
# ══════════════════════════════════════════════════

func _ready() -> void:
	_detect_role()

	if not _is_local:
		# Удалённые игроки: полностью выключены.
		# НЕ регистрируют обработчики — иначе перезапишут
		# обработчики локального игрока.
		# Terrain один на всех — только локальный игрок
		# принимает и применяет чужие действия.
		set_process(false)
		set_physics_process(false)
		set_process_input(false)
		set_process_unhandled_input(false)
		return

	_find_and_bind_nam()
	_on_module_ready()


## Определить роль из родителя (BasePlayer).
func _detect_role() -> void:
	var parent = get_parent()
	if parent is BasePlayer:
		_is_local = (parent as BasePlayer).is_local
		_network_id = (parent as BasePlayer).network_id
	else:
		# Нет BasePlayer → одиночная игра
		_is_local = true
		_network_id = 0


## Найти NAM и зарегистрировать обработчики.
func _find_and_bind_nam() -> void:
	if _actions_registered:
		return

	_nam = _find_nam()
	if _nam == null:
		return

	_register_actions()
	_actions_registered = true
	print("✅ %s: мультиплеер подключён" % _get_module_name())


func _find_nam() -> NetworkActionManager:
	var root := get_tree().current_scene
	if root == null:
		return null

	var node := root.get_node_or_null("NetworkActionManager")
	if node is NetworkActionManager:
		return node as NetworkActionManager

	for child in root.get_children():
		if child is NetworkActionManager:
			return child as NetworkActionManager

	return null


# ══════════════════════════════════════════════════
#  ВИРТУАЛЬНЫЕ МЕТОДЫ (переопределяются наследниками)
# ══════════════════════════════════════════════════

## Имя модуля для логов.
func _get_module_name() -> String:
	return "BaseInteraction"


## Вызывается после _ready() ТОЛЬКО для локального игрока.
func _on_module_ready() -> void:
	pass


## Регистрация действий. Наследник вызывает _register_action() здесь.
func _register_actions() -> void:
	pass


## Применить удалённое действие.
func _on_remote_action(action_name: String, peer_id: int, data: Dictionary) -> void:
	pass


# ══════════════════════════════════════════════════
#  СЕТЕВОЙ API (вызывается наследниками)
# ══════════════════════════════════════════════════

## Зарегистрировать действие.
## action_name должен совпадать с packet_name в .tres.
func _register_action(action_name: String) -> void:
	if _nam == null:
		return
	if action_name in _registered_actions:
		return
	_registered_actions[action_name] = true
	_nam.on_action(action_name, _on_packet_received.bind(action_name))


## Отправить действие на сервер.
## args — массив аргументов БЕЗ peer_id (добавляется автоматически).
func _send(action_name: String, args: Array) -> void:
	if _nam == null:
		return
	var full_args := [_network_id]
	full_args.append_array(args)
	_nam.send_action(action_name, full_args)


# ══════════════════════════════════════════════════
#  ВНУТРЕННИЙ ОБРАБОТЧИК
# ══════════════════════════════════════════════════

func _on_packet_received(peer_id: int, data: Dictionary, action_name: String) -> void:
	_on_remote_action(action_name, peer_id, data)


# ══════════════════════════════════════════════════
#  УТИЛИТЫ
# ══════════════════════════════════════════════════

## Проверить открыт ли чат или инвентарь.
func _is_ui_blocking() -> bool:
	var chat = get_tree().get_first_node_in_group("chat")
	if chat and chat.has_method("is_chat_open"):
		if chat.is_chat_open():
			return true

	var player = get_parent()
	if player and "inventory_open" in player:
		if player.inventory_open:
			return true

	return false
