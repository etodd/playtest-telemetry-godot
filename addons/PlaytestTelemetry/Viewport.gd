@tool
class_name PlaytestTelemetryViewport
extends SubViewportContainer

const MOUSE_LOOK_SPEED: float = 1.0 / 1200.0
var speed: int = 1
var looking: bool = false
var movement: Vector3 = Vector3.ZERO

@onready var camera3D: Camera3D = $SubViewport/Camera3D

func _process(delta: float) -> void:
	if not looking:
		return
	var s: float
	match speed:
		0:
			s = 0.1
		2:
			s = 5.0
		_:
			s = 0.5
	camera3D.position += camera3D.quaternion * (movement * s)

func _gui_input(event: InputEvent) -> void:
	# TODO: handle trackpad gestures
	# TODO: orbiting
	# TODO: proper zoom and camera speed
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			looking = event.is_pressed()
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if looking else Input.MOUSE_MODE_VISIBLE
			accept_event()
	elif event is InputEventMouseMotion:
		if looking:
			camera3D.rotation.y -= event.relative.x * MOUSE_LOOK_SPEED * get_tree().root.content_scale_factor
			camera3D.rotation.x -= event.relative.y * MOUSE_LOOK_SPEED * get_tree().root.content_scale_factor
			camera3D.rotation.x = clamp(camera3D.rotation.x, PI * -0.5, PI * 0.5)
			accept_event()

func _input(event: InputEvent) -> void:
	if not looking:
		return
	if not (event is InputEventKey):
		return
	var code: Key = event.get_keycode()
	if code == Key.KEY_W:
		if event.is_pressed():
			movement.z = -1.0
		else:
			movement.z = max(movement.z, 0.0)
		accept_event()
	elif code == Key.KEY_S:
		if event.is_pressed():
			movement.z = 1.0
		else:
			movement.z = min(movement.z, 0.0)
		accept_event()
	elif code == Key.KEY_A:
		if event.is_pressed():
			movement.x = -1.0
		else:
			movement.x = max(movement.x, 0.0)
		accept_event()
	elif code == Key.KEY_D:
		if event.is_pressed():
			movement.x = 1.0
		else:
			movement.x = min(movement.x, 0.0)
		accept_event()
	elif code == Key.KEY_Q:
		if event.is_pressed():
			movement.y = -1.0
		else:
			movement.y = max(movement.y, 0.0)
		accept_event()
	elif code == Key.KEY_E:
		if event.is_pressed():
			movement.y = 1.0
		else:
			movement.y = min(movement.y, 0.0)
		accept_event()
	elif code == Key.KEY_SHIFT:
		if event.is_pressed():
			speed = max(speed, 2)
		else:
			speed = min(speed, 1)
	elif code == Key.KEY_ALT:
		if event.is_pressed():
			speed = min(speed, 0)
		else:
			speed = max(speed, 1)
