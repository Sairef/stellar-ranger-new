extends Node

## Headless checks for picking objects with the mouse (PlayerController.pick()).
## Run from the project folder:
##   godot --headless --path . --fixed-fps 60 res://tests/picking_checks.tscn

const ErrorLog := preload("res://tests/support/error_log.gd")
const ShipScene := preload("res://src/ships/ship.tscn")
const GateScene := preload("res://src/world/gate.tscn")
const StationScene := preload("res://src/world/station.tscn")

var _errors := ErrorLog.new()
var _passed := 0
var _failed := 0


func _ready() -> void:
	OS.add_logger(_errors)
	# The camera sits at the origin looking down -Z.
	var camera := Camera3D.new()
	camera.far = 60000.0
	add_child(camera)
	camera.current = true
	var player := _add(ShipScene, Vector3(0, 0, 200)) as Ship
	var controller := PlayerController.new()
	controller.ship = player
	controller.camera = camera
	add_child(controller)

	# Bug report: aiming at a gate across the system selected a trader in between.
	var gate := _add(GateScene, Vector3(0, 0, -6000))
	var trader := _add(ShipScene, Vector3(20, 0, -1500))
	# A small ship parked in front of a big station must stay clickable.
	var station := _add(StationScene, Vector3(-600, 0, -2000))
	var parked := _add(ShipScene, Vector3(-480, -40, -1700))
	await get_tree().process_frame

	var gate_px := camera.unproject_position(gate.global_position)
	var trader_px := camera.unproject_position(trader.global_position)
	var station_px := camera.unproject_position(station.global_position)
	var parked_px := camera.unproject_position(parked.global_position)
	_check(gate_px.distance_to(trader_px) < PlayerController.PICK_RADIUS,
			"precondition: the trader's click halo covers the gate (%.0f px apart)" % gate_px.distance_to(trader_px))
	_check(controller.pick(gate_px) == gate, "a click on the distant gate selects the gate")
	_check(controller.pick(trader_px) == trader, "a click on the trader selects the trader")
	_check(controller.pick(station_px) == station, "a click on the station selects the station")
	_check(controller.pick(parked_px) == parked, "a click on a ship in front of the station selects the ship")
	_check(controller.pick(parked_px + Vector2(8, 0)) == parked,
			"a click 8 px off that ship still selects the ship, not the station behind")
	_check(controller.pick(Vector2(5, 5)) == null, "a click on empty space selects nothing")

	# Bug report: the selected ship got destroyed and the game crashed on the selection ring.
	# A freed object compares equal to null, so only is_same() shows it is really cleared.
	controller.select(trader)
	(trader as Ship).take_hit(1000.0, player)
	for i in 3:
		await get_tree().process_frame
	_check(is_same(controller.selected, null), "a destroyed selection is cleared (%s)" % controller.selected)

	_check(_errors.errors.is_empty(), "no errors during the run %s" % _errors.errors)
	print("\n%d passed, %d failed" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _add(scene: PackedScene, position: Vector3) -> Node3D:
	var node := scene.instantiate() as Node3D
	add_child(node)
	node.global_position = position
	return node


func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  " + message)
	else:
		_failed += 1
		print("  FAIL  " + message)
