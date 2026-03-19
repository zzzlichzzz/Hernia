class_name ClientWorldRuntimeManager
extends Node

signal world_ready(my_id: int)
signal world_unloaded()

var _net: NetworkManager = null
var _pm: PlayerManager = null
var _nam: NetworkActionManager = null

var _player_scene: PackedScene = null
var _remote_player_scene: PackedScene = null
var _player_container: Node = null

var _local_player: CharacterBody3D = null
var _my_id: int = 0

# ══════════════════════════════════════════════════
#  ОТЛОЖЕННЫЙ СПАВН REMOTE ИГРОКОВ
# ══════════════════════════════════════════════════

## Очередь спавна: не спавним все 99 сцен за 1 кадр
var _spawn_queue: Array[Dictionary] = []
## Сколько сцен спавнить за один _process (подбирается под FPS)
const SPAWNS_PER_FRAME := 3

## Буфер снапшотов для ещё не заспавненных нод.
## target_id → последний entry (Dictionary)
## Когда нода заспавнится — применяем сохранённый снапшот.
var _pending_snapshots: Dictionary = {}


func setup(
	net: NetworkManager,
	pm: PlayerManager,
	nam: NetworkActionManager,
	player_scene: PackedScene,
	remote_player_scene: PackedScene,
	player_container: Node
) -> void:
	_net = net
	_pm = pm
	_nam = nam

	_player_scene = player_scene
	_remote_player_scene = remote_player_scene
	_player_container = player_container

	_pm.setup_client(_remote_player_scene, _player_container)
	_register_network_handlers()


func get_my_id() -> int:
	return _my_id


func get_local_player() -> CharacterBody3D:
	return _local_player


func on_connection_lost() -> void:
	clear_world()


func clear_world() -> void:
	if _nam != null:
		_nam.clear_sources()

	if _pm != null:
		_pm.clear_local_player()

	if _local_player != null and is_instance_valid(_local_player):
		_local_player.queue_free()
	_local_player = null

	if _pm != null:
		_pm.clear()

	_my_id = 0
	_spawn_queue.clear()
	_pending_snapshots.clear()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	world_unloaded.emit()


# ══════════════════════════════════════════════════
#  PROCESS — отложенный спавн
# ══════════════════════════════════════════════════

func _process(_delta: float) -> void:
	if _spawn_queue.is_empty():
		return

	var spawned := 0
	while not _spawn_queue.is_empty() and spawned < SPAWNS_PER_FRAME:
		var entry: Dictionary = _spawn_queue.pop_front()
		var id: int = entry["id"]
		var pos: Vector3 = entry["position"]
		var rot: Vector3 = entry["rotation"]

		# Проверяем что игрок ещё актуален (мог отключиться пока ждал)
		if not _pm.has_player(id):
			continue

		# Проверяем что нода ещё не была создана (дубль-защита)
		var existing_node := _pm.get_player_node(id)
		if existing_node != null:
			continue

		# Спавним ноду
		var node := _remote_player_scene.instantiate() as Node3D
		node.name = "Player_%d" % id

		if node is BasePlayer:
			var bp := node as BasePlayer
			bp.is_local = false
			bp.network_id = id

		_player_container.add_child(node)

		if node.has_method("update_state"):
			node.update_state(pos, rot)

		# Обновляем данные в PlayerManager
		_pm.get_player_data(id)["node"] = node

		# Применяем накопленный снапшот если есть
		if id in _pending_snapshots:
			var snap: Dictionary = _pending_snapshots[id]
			if node is BasePlayer:
				(node as BasePlayer).apply_network_state(id, snap)
			_pending_snapshots.erase(id)

		spawned += 1


# ══════════════════════════════════════════════════
#  SETUP
# ══════════════════════════════════════════════════

func _register_network_handlers() -> void:
	_net.register_handler(PacketTypes.WELCOME, _on_welcome)
	_net.register_handler(PacketTypes.PLAYER_JOINED, _on_player_joined)
	_net.register_handler(PacketTypes.PLAYER_LEFT, _on_player_left)
	_net.register_handler(PacketTypes.CHAMELEON_SYNC, _on_chameleon_sync)
	_net.register_handler(PacketTypes.PLAYER_SNAPSHOT_BATCH, _on_player_snapshot_batch)


# ══════════════════════════════════════════════════
#  WORLD BOOTSTRAP
# ══════════════════════════════════════════════════

func _on_welcome(_peer_id: int, body: StreamPeerBuffer) -> void:
	var data := PacketTypes.read_welcome(body)

	_my_id = data["id"]
	_net.set_my_id(_my_id)

	if _nam != null:
		_nam.clear_sources()

	if _pm != null:
		_pm.clear_local_player()

	if _local_player != null and is_instance_valid(_local_player):
		_local_player.queue_free()
	_local_player = null

	_spawn_queue.clear()
	_pending_snapshots.clear()

	_local_player = _player_scene.instantiate() as CharacterBody3D
	_local_player.name = "LocalPlayer"

	if _local_player is BasePlayer:
		(_local_player as BasePlayer).is_local = true
		(_local_player as BasePlayer).network_id = _my_id

	_player_container.add_child(_local_player)
	_pm.set_local_player(_my_id, _local_player)

	_local_player.global_position = data["position"]
	_local_player.rotation.y = data["rotation"].y

	_nam.auto_bind_source(_local_player, _my_id)

	world_ready.emit(_my_id)


# ══════════════════════════════════════════════════
#  REMOTE PLAYERS / REPLICATION
# ══════════════════════════════════════════════════

func _on_player_joined(_peer_id: int, body: StreamPeerBuffer) -> void:
	var data := PacketTypes.read_player_joined(body)
	var id: int = data["id"]
	if id == _my_id:
		return

	# Регистрируем данные сразу (has_player работает мгновенно)
	# Но ноду спавним через очередь
	if _pm.has_player(id):
		return

	var pos: Vector3 = data["position"]
	var rot: Vector3 = data["rotation"]

	# Добавляем запись БЕЗ ноды (нода будет через очередь)
	_pm.add_player_data_only(id, pos, rot)

	# Ставим в очередь на спавн
	_spawn_queue.append({
		"id": id,
		"position": pos,
		"rotation": rot,
	})


func _on_player_left(_peer_id: int, body: StreamPeerBuffer) -> void:
	var data := PacketTypes.read_player_left(body)
	var id: int = data["id"]
	_pending_snapshots.erase(id)
	_pm.remove_player(id)


func _on_player_snapshot_batch(_peer_id: int, body: StreamPeerBuffer) -> void:
	var entries := PacketTypes.read_player_snapshot_batch(body)
	if entries.is_empty():
		return

	for entry: Dictionary in entries:
		var target_id: int = int(entry.get("peer_id", 0))
		if target_id == _my_id:
			continue

		var node := _pm.get_player_node(target_id)

		if node == null or not is_instance_valid(node):
			# Нода ещё не заспавнена — сохраняем последний снапшот
			_pending_snapshots[target_id] = entry
			continue

		# Прямой вызов вместо has_method + call
		if node is BasePlayer:
			(node as BasePlayer).apply_network_state(target_id, entry)


# ══════════════════════════════════════════════════
#  WORLD SYNC
# ══════════════════════════════════════════════════

func _on_chameleon_sync(_peer_id: int, body: StreamPeerBuffer) -> void:
	var entries := PacketTypes.read_chameleon_sync(body)
	if entries.is_empty():
		return

	var cham := ChameleonManager.get_instance()
	if cham:
		cham.batch_paint_by_block_ids(entries)
		print("[client] Хамелеоны синхронизированы: %d блоков" % entries.size())
