class_name ServerWorldStateManager
extends Node

## Отвечает за серверное состояние мира.
## Сейчас:
## - chameleon sync
## - chameleon paint
## - block break
##
## Подготовлено под будущее разделение по world_id.

const DEFAULT_WORLD_ID := "default_world"

var _net: NetworkManager = null

## world_id -> { Vector3i -> int(source_block_id) }
var _world_chameleons: Dictionary = {}

## peer_id -> world_id
var _player_worlds: Dictionary = {}


func setup(net: NetworkManager) -> void:
	_net = net


func attach_player_to_world(peer_id: int, world_id: String) -> void:
	var wid := world_id if world_id != "" else DEFAULT_WORLD_ID
	_player_worlds[peer_id] = wid
	_ensure_world_exists(wid)


func detach_player(peer_id: int) -> void:
	_player_worlds.erase(peer_id)


func set_player_world(peer_id: int, world_id: String) -> void:
	attach_player_to_world(peer_id, world_id)


func get_player_world(peer_id: int) -> String:
	return _player_worlds.get(peer_id, DEFAULT_WORLD_ID)


func send_initial_sync(peer_id: int, world_id: String = "") -> void:
	if _net == null:
		return

	var wid := world_id if world_id != "" else get_player_world(peer_id)
	var state: Dictionary = _get_world_chameleon_state(wid)
	if state.is_empty():
		return

	var body := PacketTypes.write_chameleon_sync_body(state)
	_net.send_fragmented_to_peer(
		peer_id,
		PacketTypes.CHAMELEON_SYNC,
		body,
		0,
		ENetPacketPeer.FLAG_RELIABLE
	)


func handle_chameleon_paint(peer_id: int, data: Dictionary) -> void:
	var wid := get_player_world(peer_id)
	_ensure_world_exists(wid)

	var pos := Vector3i(data["block_position"])
	var block_id: int = data["source_block_id"]

	var world_state: Dictionary = _world_chameleons[wid]
	world_state[pos] = block_id
	_world_chameleons[wid] = world_state


func handle_block_break(peer_id: int, data: Dictionary) -> void:
	var wid := get_player_world(peer_id)
	_ensure_world_exists(wid)

	var pos := Vector3i(data["block_position"])

	var world_state: Dictionary = _world_chameleons[wid]
	world_state.erase(pos)
	_world_chameleons[wid] = world_state


func get_world_chameleon_state(world_id: String) -> Dictionary:
	var wid := world_id if world_id != "" else DEFAULT_WORLD_ID
	return _get_world_chameleon_state(wid).duplicate(true)


func clear() -> void:
	_world_chameleons.clear()
	_player_worlds.clear()


# ══════════════════════════════════════════════════
#  INTERNAL
# ══════════════════════════════════════════════════

func _ensure_world_exists(world_id: String) -> void:
	if world_id not in _world_chameleons:
		_world_chameleons[world_id] = {}


func _get_world_chameleon_state(world_id: String) -> Dictionary:
	_ensure_world_exists(world_id)
	return _world_chameleons[world_id]
