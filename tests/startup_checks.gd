extends Node

## Checks the game the way it really starts: the home system is part of this test's main scene,
## so it is built while the game boots, before any node is in the tree. (Other suites load
## scenes from scripts later, which hides start-up problems: references set by the scene
## once resolved to nothing because the World registry did not exist yet.)
## Run from the project folder (exit code 0 when everything passes):
##   godot --headless --path . --fixed-fps 60 res://tests/startup_checks.tscn

const ErrorLog := preload("res://tests/support/error_log.gd")

var _errors := ErrorLog.new()
var _passed := 0
var _failed := 0


func _ready() -> void:
	OS.add_logger(_errors)
	var player := get_node("HomeSystem/Ships/PlayerShip") as Ship
	var controller := get_node("HomeSystem/PlayerController") as PlayerController
	var camera := get_node("HomeSystem/Camera") as OrbitCamera
	_check(controller.ship == player, "the controller knows the player's ship (%s)" % controller.ship)
	_check(controller.has_ship(), "the HUD sees a ship, not 'destroyed'")
	_check(camera.target == player, "the camera follows the player's ship (%s)" % camera.target)
	for i in 120:
		await get_tree().physics_frame
	_check(_errors.errors.is_empty(), "no errors in the first two seconds %s" % _errors.errors.slice(0, 5))
	print("\n%d passed, %d failed" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  " + message)
	else:
		_failed += 1
		print("  FAIL  " + message)
