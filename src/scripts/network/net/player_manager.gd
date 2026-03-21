class_name PlayerManager
extends Node

## Хранит данные игроков.
## Сервер: только словарь (pos/rot).
## Клиент: + спавнит/удаляет Node3D-модели.

var _remote_scene     : PackedScene = null
var _container        : Node = null
var _players          : Dictionary = {}   # id → { "position", "rotation", "node" }
var _local_player_id  : int = 0
var _local_player_node: Node = null

## Кеш массива id — пересоздаётся только при add/remove
var _ids_cache: Array = []
var _ids_dirty: bool = true


## Вызвать на клиенте, чтобы PlayerManager умел спавнить 3D-модели.
func setup_client(scene: PackedScene, container: Node) -> void:
	_remote_scene = scene
	_container = container


## Добавить игрока (+ спавн ноды на клиенте).
func add_player(id: int, pos: Vector3, rot: Vector3) -> void:
	if id in _players:
		return

	var data := { "position": pos, "rotation": rot, "node": null }

	if _remote_scene and _container:
		var node := _remote_scene.instantiate() as Node3D
		node.name = "Player_%d" % id

		if node is BasePlayer:
			var bp := node as BasePlayer
			bp.is_local = false
			bp.network_id = id

		_container.add_child(node)

		if node.has_method("update_state"):
			node.update_state(pos, rot)

		data["node"] = node

	_players[id] = data
	_ids_dirty = true
	print("[pm] + Игрок %d  (всего: %d)" % [id, _players.size()])


## Удалить игрока (+ удалить ноду).
func remove_player(id: int) -> void:
	if id not in _players:
		return
	var data: Dictionary = _players[id]
	var node_ref: Variant = data.get("node", null)
	if node_ref != null and is_instance_valid(node_ref):
		(node_ref as Node).queue_free()
	_players.erase(id)
	_ids_dirty = true
	print("[pm] − Игрок %d (всего: %d)" % [id, _players.size()])

## Добавить запись игрока БЕЗ спавна ноды.
## Используется ClientWorldRuntimeManager для отложенного спавна.
func add_player_data_only(id: int, pos: Vector3, rot: Vector3) -> void:
	if id in _players:
		return
	_players[id] = { "position": pos, "rotation": rot, "node": null }
	_ids_dirty = true
## Обновить позицию/поворот.
func update_player(id: int, pos: Vector3, rot: Vector3) -> void:
	if id not in _players:
		return
	var data: Dictionary = _players[id]
	data["position"] = pos
	data["rotation"] = rot
	# Нода обновляется только на клиенте, и только если есть.
	# update_state проверяется один раз при add_player, 
	# здесь мы знаем что если node != null, метод есть.
	var node_ref: Variant = data.get("node", null)
	if node_ref != null and is_instance_valid(node_ref):
		(node_ref as Node3D).update_state(pos, rot)


## Получить данные одного игрока.
## ВНИМАНИЕ: возвращает ССЫЛКУ на внутренний Dictionary.
## Не модифицируйте его снаружи (кроме position/rotation через update_player).
func get_player_data(id: int) -> Dictionary:
	return _players.get(id, {})


## Все id игроков — кешированный массив.
## Не модифицируйте возвращённый массив!
func get_all_ids() -> Array:
	if _ids_dirty:
		_ids_cache = _players.keys()
		_ids_dirty = false
	return _ids_cache


## Есть ли такой игрок.
func has_player(id: int) -> bool:
	return id in _players


func set_local_player(id: int, node: Node) -> void:
	_local_player_id = id
	_local_player_node = node


func clear_local_player() -> void:
	_local_player_id = 0
	_local_player_node = null


func get_player_node(id: int) -> Node:
	if id == _local_player_id and _local_player_node != null and is_instance_valid(_local_player_node):
		return _local_player_node

	if id in _players:
		var data: Dictionary = _players[id]
		var node_ref: Variant = data.get("node", null)
		if node_ref != null and is_instance_valid(node_ref):
			return node_ref as Node

	return null


## Очистить всех (при дисконнекте).
func clear() -> void:
	for id: int in _players.keys():
		remove_player(id)
	_ids_cache.clear()
	_ids_dirty = true
