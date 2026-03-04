class_name PlayerManager
extends Node
## Хранит данные игроков.
## Сервер: только словарь (pos/rot).
## Клиент: + спавнит/удаляет Node3D-модели.

var _remote_scene : PackedScene = null
var _container    : Node        = null
var _players      : Dictionary  = {}   # id → { "position", "rotation", "node" }


## Вызвать на клиенте, чтобы PlayerManager умел спавнить 3D-модели.
func setup_client(scene: PackedScene, container: Node) -> void:
	_remote_scene = scene
	_container    = container


## Добавить игрока (+ спавн ноды на клиенте).
func add_player(id: int, pos: Vector3, rot: Vector3) -> void:
	if id in _players:
		return
	var data := { "position": pos, "rotation": rot, "node": null }

	if _remote_scene and _container:
		var node := _remote_scene.instantiate() as Node3D
		node.name = "Player_%d" % id
		_container.add_child(node)
		if node.has_method("update_state"):
			node.update_state(pos, rot)
		data["node"] = node

	_players[id] = data
	print("[pm] + Игрок %d  (всего: %d)" % [id, _players.size()])


## Удалить игрока (+ удалить ноду).
func remove_player(id: int) -> void:
	if id not in _players:
		return
	var data: Dictionary = _players[id]
	if data["node"] != null:
		(data["node"] as Node).queue_free()
	_players.erase(id)
	print("[pm] − Игрок %d  (всего: %d)" % [id, _players.size()])


## Обновить позицию/поворот.
func update_player(id: int, pos: Vector3, rot: Vector3) -> void:
	if id not in _players:
		return
	var data: Dictionary = _players[id]
	data["position"] = pos
	data["rotation"] = rot
	if data["node"] != null and (data["node"] as Node).has_method("update_state"):
		(data["node"] as Node3D).update_state(pos, rot)


## Получить данные одного игрока.
func get_player_data(id: int) -> Dictionary:
	if id in _players:
		return _players[id]
	return {}


## Все id игроков.
func get_all_ids() -> Array:
	return _players.keys()


## Есть ли такой игрок.
func has_player(id: int) -> bool:
	return id in _players


## Очистить всех (при дисконнекте).
func clear() -> void:
	for id: int in _players.keys():
		remove_player(id)
