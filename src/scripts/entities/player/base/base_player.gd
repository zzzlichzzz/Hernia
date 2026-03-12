class_name BasePlayer
extends CharacterBody3D

var is_local: bool = false
var network_id: int = 0
var inventory_open: bool = false

var _components: Array[PlayerComponent] = []
var _head: Node3D = null
var _camera: Camera3D = null


func _ready() -> void:
	_head = get_node_or_null("Neck")
	_camera = get_node_or_null("Neck/Camera3D")
	_register_components()
	if is_local:
		_setup_local()
	else:
		_setup_remote()


func _register_components() -> void:
	add_component(HealthComponent.new())


func _setup_local() -> void:
	if _camera:
		_camera.current = true
	set_process_input(true)
	set_process_unhandled_input(true)
	add_to_group("player")


func _setup_remote() -> void:
	if _camera:
		_camera.current = false
	set_process_input(false)
	set_process_unhandled_input(false)


func _input(event: InputEvent) -> void:
	if not is_local:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_apply_mouse_rotation(event.relative)
		get_viewport().set_input_as_handled()


func _apply_mouse_rotation(relative: Vector2) -> void:
	pass


func _physics_process(delta: float) -> void:
	for comp in _components:
		comp.process(delta, is_local)
	if is_local:
		_process_local(delta)
	else:
		_process_remote(delta)


func _process_local(_delta: float) -> void:
	pass


func _process_remote(_delta: float) -> void:
	pass


func add_component(comp: PlayerComponent) -> void:
	comp.setup(self)
	_components.append(comp)


func get_component(type: Variant) -> PlayerComponent:
	for comp in _components:
		if is_instance_of(comp, type):
			return comp
	return null


func has_component(type: Variant) -> bool:
	return get_component(type) != null


func get_network_state() -> Dictionary:
	var state := {
		"position": global_position,
		"rotation": Vector3(
			_head.rotation.x if _head else 0.0,
			rotation.y,
			0.0
		),
	}
	for comp in _components:
		state.merge(comp.collect_state())
	return state


func apply_network_state(peer_id: int, data: Dictionary) -> void:
	if "position" in data:
		global_position = data["position"]
	if "body_yaw" in data:
		rotation.y = data["body_yaw"]
	if "head_pitch" in data and _head:
		_head.rotation.x = data["head_pitch"]
	for comp in _components:
		comp.apply_state(data)


func apply_server_correction(peer_id: int, data: Dictionary) -> void:
	if not is_local:
		return
	if "position" in data:
		global_position = data["position"]
		velocity = Vector3.ZERO
	if "body_yaw" in data:
		rotation.y = data["body_yaw"]
	if "head_pitch" in data and _head:
		_head.rotation.x = data["head_pitch"]
	print("[player] ⚠ Коррекция позиции от сервера")


func update_state(pos: Vector3, rot: Vector3) -> void:
	global_position = pos
	rotation.y = rot.y
	if _head:
		_head.rotation.x = rot.x


func get_health() -> HealthComponent:
	return get_component(HealthComponent) as HealthComponent
