extends "res://tests/support/check_suite.gd"

## Checks the game the way it really starts: the home system is part of this test's main scene,
## so it is built while the game boots, before any node is in the tree. (Other suites load
## scenes from scripts later, which hides start-up problems: references set by the scene
## once resolved to nothing because the World registry did not exist yet.)
## Run from the project folder (exit code 0 when everything passes):
##   godot --headless --path . --fixed-fps 60 res://tests/startup_checks.tscn


func _ready() -> void:
	var player := get_node("HomeSystem/Ships/PlayerShip") as Ship
	var controller := get_node("HomeSystem/PlayerController") as PlayerController
	var camera := get_node("HomeSystem/Camera") as OrbitCamera
	_check(controller.ship == player, "the controller knows the player's ship (%s)" % controller.ship)
	_check(controller.has_ship(), "the HUD sees a ship, not 'destroyed'")
	_check(camera.target == player, "the camera follows the player's ship (%s)" % camera.target)
	var miner := get_node("HomeSystem/Ships/PlayerMiner") as Ship
	var trade := get_node("HomeSystem/Stations/HalcyonExchange") as SpaceBody
	_check(miner.is_docked() and miner.docked_at == trade,
			"the player's mining ship waits docked at %s" % Autopilot.name_of(miner.docked_at))
	_check(controller.fleet == [player, miner], "the player owns both ships (%s)" % [controller.fleet])
	for i in 120:
		await get_tree().physics_frame
	_finish()
