class_name OrbitCamera
extends Camera3D

## EVE-style camera: orbits around a target, rotated with the right mouse button
## and zoomed with the mouse wheel.

@export var target: Node3D
@export var distance := 250.0
@export var min_distance := 30.0
@export var max_distance := 4000.0
## Radians per pixel of mouse movement.
@export var rotate_sensitivity := 0.005
@export var zoom_step := 1.12

## Horizontal angle around the target, in radians.
var yaw := 0.6
## Vertical angle, in radians. Negative looks down at the target.
var pitch := -0.45

const MAX_PITCH := 1.45


func _ready() -> void:
	# Moved in _process from interpolated positions, so it must not be interpolated again.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _unhandled_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null and motion.button_mask & MOUSE_BUTTON_MASK_RIGHT:
		yaw -= motion.relative.x * rotate_sensitivity
		pitch = clampf(pitch - motion.relative.y * rotate_sensitivity, -MAX_PITCH, MAX_PITCH)
		get_viewport().set_input_as_handled()
		return

	var button := event as InputEventMouseButton
	if button != null and button.pressed:
		if button.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(min_distance, distance / zoom_step)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(max_distance, distance * zoom_step)


func _process(_delta: float) -> void:
	if not is_instance_valid(target):
		return
	var focus := target.get_global_transform_interpolated().origin
	var offset := Basis.from_euler(Vector3(pitch, yaw, 0.0)) * Vector3(0.0, 0.0, distance)
	global_position = focus + offset
	look_at(focus, Vector3.UP)
