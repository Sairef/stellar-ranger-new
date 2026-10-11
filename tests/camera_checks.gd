extends Node

## Headless checks for OrbitCamera keyboard controls. Run from the project folder:
##   godot --headless --path . --fixed-fps 60 res://tests/camera_checks.tscn

const ErrorLog := preload("res://tests/support/error_log.gd")
const STEP := deg_to_rad(OrbitCamera.STEP_DEGREES)
const EPSILON := 0.0001

var _errors := ErrorLog.new()
var _passed := 0
var _failed := 0


func _ready() -> void:
	OS.add_logger(_errors)
	var camera := OrbitCamera.new()
	add_child(camera)

	var yaw := camera.yaw
	var pitch := camera.pitch
	_tap(KEY_KP_4)
	_check(is_equal_approx(camera.yaw, yaw + STEP), "numpad 4 orbits left by 15 degrees")
	_tap(KEY_KP_6)
	_tap(KEY_KP_6)
	_check(is_equal_approx(camera.yaw, yaw - STEP), "numpad 6 orbits right by 15 degrees")
	_tap(KEY_KP_8)
	_check(is_equal_approx(camera.pitch, pitch - STEP), "numpad 8 raises the camera by 15 degrees")
	_tap(KEY_KP_2)
	_check(is_equal_approx(camera.pitch, pitch), "numpad 2 lowers it back")

	for i in 20:
		_tap(KEY_KP_8)
	_check(absf(camera.pitch + OrbitCamera.MAX_PITCH) < EPSILON, "pitch stops at the top limit")

	var distance := camera.distance
	_tap(KEY_KP_SUBTRACT)
	_check(is_equal_approx(camera.distance, distance * camera.zoom_step), "numpad - zooms out one step")
	_tap(KEY_KP_ADD)
	_check(is_equal_approx(camera.distance, distance), "numpad + zooms back in")

	# Holding an arrow rotates smoothly for as long as it is held.
	yaw = camera.yaw
	_send(KEY_LEFT, true)
	for i in 30:
		await get_tree().process_frame
	_send(KEY_LEFT, false)
	var turned := camera.yaw - yaw
	_check(absf(turned - camera.key_rotate_speed * 0.5) < 0.05,
			"holding Left for 0.5 s orbits left by %.2f rad (expected %.2f)" % [turned, camera.key_rotate_speed * 0.5])
	yaw = camera.yaw
	for i in 10:
		await get_tree().process_frame
	_check(is_equal_approx(camera.yaw, yaw), "rotation stops when the arrow is released")

	_check(_errors.errors.is_empty(), "no errors during the run %s" % _errors.errors)
	print("\n%d passed, %d failed" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _tap(keycode: Key) -> void:
	_send(keycode, true)
	_send(keycode, false)


func _send(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = pressed
	get_viewport().push_input(event)


func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  " + message)
	else:
		_failed += 1
		print("  FAIL  " + message)
