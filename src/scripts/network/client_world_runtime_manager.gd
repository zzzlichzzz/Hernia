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
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	world_unloaded.emit()


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

	# На случай реконнекта / повторного входа в мир
	if _nam != null:
		_nam.clear_sources()

	if _pm != null:
		_pm.clear_local_player()

	if _local_player != null and is_instance_valid(_local_player):
		_local_player.queue_free()
	_local_player = null

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
	if data["id"] == _my_id:
		return
	_pm.add_player(data["id"], data["position"], data["rotation"])


func _on_player_left(_peer_id: int, body: StreamPeerBuffer) -> void:
	var data := PacketTypes.read_player_left(body)
	_pm.remove_player(data["id"])


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
			continue

		if node.has_method("apply_network_state"):
			node.call("apply_network_state", target_id, entry)


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
