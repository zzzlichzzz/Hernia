extends Node3D
## Визуальное представление удалённого игрока.


## Обновить позицию и поворот (вызывается из PlayerManager).
func update_state(pos: Vector3, rot: Vector3) -> void:
	global_position = pos
	rotation.y = rot.y
	# rot.x — наклон головы, можно применить к дочернему «Head»,
	# пока просто игнорируем для простоты.
