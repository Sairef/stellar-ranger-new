class_name OrbitCamera
extends Camera3D

## EVE-style camera that orbits around a target.
##
## Mouse: right button drag rotates, wheel zooms.
## Keyboard: arrows rotate smoothly while held (Up/Down raise/lower the camera).
## Numpad 4/6/8/2 rotate by exact STEP_DEGREES and numpad +/- zoom by one step:
## handy for repeatable views when debugging, also through simulated input.

@export var target: Node3D
@export var distance := 250.0
@export var min_distance := 30.0
@export var max_distance := 12000.0
## Radians per pixel of mouse movement.
@export var rotate_sensitivity := 0.005
## Radians per second while an arrow key is held.
@export var key_rotate_speed := 1.5
@export var zoom_step := 1.12

## Horizontal angle around the target, in radians.
var yaw := 0.6
## Vertical angle, in radians. Negative means the camera is above the target, looking down.
var pitch := -0.45

const MAX_PITCH := 1.45
const STEP_DEGREES := 15.0

## Arrow keys currently held. Tracked from events rather than polled from Input,
## so it also works for simulated input that bypasses the global Input state.
var _held_keys := {}


func _ready() -> void:
	# Moved in _process from interpolated positions, so it must not be interpolated again.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _notification(what: int) -> void:
	# A key released while the window was unfocused never sends its release event.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_held_keys.clear()


func _unhandled_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null and motion.button_mask & MOUSE_BUTTON_MASK_RIGHT:
		rotate_by(-motion.relative.x * rotate_sensitivity, -motion.relative.y * rotate_sensitivity)
		get_viewport().set_input_as_handled()
		return

	var button := event as InputEventMouseButton
	if button != null and button.pressed:
		if button.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_by(1.0 / zoom_step)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_by(zoom_step)
		return

	var key := event as InputEventKey
	if key == null or key.echo:
		return
	match key.keycode:
		KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN:
			if key.pressed:
				_held_keys[key.keycode] = true
			else:
				_held_keys.erase(key.keycode)
		KEY_KP_4 when key.pressed:
			rotate_by(deg_to_rad(STEP_DEGREES), 0.0)
		KEY_KP_6 when key.pressed:
			rotate_by(-deg_to_rad(STEP_DEGREES), 0.0)
		KEY_KP_8 when key.pressed:
			rotate_by(0.0, -deg_to_rad(STEP_DEGREES))
		KEY_KP_2 when key.pressed:
			rotate_by(0.0, deg_to_rad(STEP_DEGREES))
		KEY_KP_ADD when key.pressed:
			zoom_by(1.0 / zoom_step)
		KEY_KP_SUBTRACT when key.pressed:
			zoom_by(zoom_step)


func _process(delta: float) -> void:
	var horizontal := float(_held_keys.has(KEY_LEFT)) - float(_held_keys.has(KEY_RIGHT))
	var vertical := float(_held_keys.has(KEY_DOWN)) - float(_held_keys.has(KEY_UP))
	if horizontal != 0.0 or vertical != 0.0:
		rotate_by(horizontal * key_rotate_speed * delta, vertical * key_rotate_speed * delta)

	if not is_instance_valid(target):
		return
	var focus := target.get_global_transform_interpolated().origin
	var offset := Basis.from_euler(Vector3(pitch, yaw, 0.0)) * Vector3(0.0, 0.0, distance)
	global_position = focus + offset
	look_at(focus, Vector3.UP)


## Orbits the camera: positive `yaw_delta` goes left around the target,
## positive `pitch_delta` goes down (looking up at the target).
func rotate_by(yaw_delta: float, pitch_delta: float) -> void:
	yaw += yaw_delta
	pitch = clampf(pitch + pitch_delta, -MAX_PITCH, MAX_PITCH)


func zoom_by(factor: float) -> void:
	distance = clampf(distance * factor, min_distance, max_distance)
