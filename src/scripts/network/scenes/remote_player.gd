extends Node3D
## Удалённый игрок. Принимает данные автоматически через NAM.


## ═══ СЕТЕВОЙ ИНТЕРФЕЙС ═══
## Вызывается автоматически через bind_receiver.
## peer_id — ID отправителя, data — поля из .tres.
func apply_network_state(peer_id: int, data: Dictionary) -> void:
	global_position = data["position"]
	rotation.y = data["body_yaw"]
	# data["head_pitch"] — можно применить к дочерней ноде Head
