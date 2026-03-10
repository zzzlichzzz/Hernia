class_name HealthComponent
extends PlayerComponent

## Компонент здоровья (заготовка).
## Добавляет "health" в сетевое состояние.
## Готов к работе когда появится .tres с полем health.

signal died()
signal health_changed(old_value: float, new_value: float)

var health: float = 100.0
var max_health: float = 100.0
var is_alive: bool = true


func collect_state() -> Dictionary:
	return { "health": health }


func apply_state(data: Dictionary) -> void:
	if "health" in data:
		var old := health
		health = data["health"]
		is_alive = health > 0.0
		if health != old:
			health_changed.emit(old, health)


func take_damage(amount: float) -> void:
	if not is_alive or amount <= 0.0:
		return
	var old := health
	health = maxf(health - amount, 0.0)
	health_changed.emit(old, health)
	if health <= 0.0:
		is_alive = false
		died.emit()


func heal(amount: float) -> void:
	if not is_alive or amount <= 0.0:
		return
	var old := health
	health = minf(health + amount, max_health)
	health_changed.emit(old, health)


func respawn() -> void:
	health = max_health
	is_alive = true


func get_health_percent() -> float:
	if max_health <= 0.0:
		return 0.0
	return health / max_health
