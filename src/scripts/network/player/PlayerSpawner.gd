extends Node
const NET_ADMIN = preload("res://src/scripts/network/player/NetAdmin.tscn")

func _ready() -> void:
	NetConnection.on_peer_connected.connect(spawn_player)
	NetClient.handle_local_id_assignment.connect(spawn_player)
	NetClient.handle_remote_id_assignment.connect(spawn_player)
	


func spawn_player(id: int) -> void:
	 # Инициализация тайлмапа
	var player = NET_ADMIN.instantiate()
	player.owner_id = id
	
	call_deferred("add_child", player)
