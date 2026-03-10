class_name PlayerComponent
extends RefCounted

## Базовый компонент игрока (ECS-паттерн).
## Компонент = данные + минимальная логика.
## Наследники переопределяют нужные методы.

var _player: Node = null


## Инициализация. Вызывается из BasePlayer.add_component().
func setup(player: Node) -> void:
	_player = player


## Собрать данные для сети. Возвращает ключи для get_network_state().
func collect_state() -> Dictionary:
	return {}


## Применить данные из сети. data содержит ВСЕ поля пакета.
func apply_state(data: Dictionary) -> void:
	pass


## Вызывается каждый _physics_process.
func process(delta: float, is_local: bool) -> void:
	pass
