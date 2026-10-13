class_name PlayerRespawner
extends Node

## Debug helper: gives the player a new ship after the old one is gone, through a
## "Respawn player" button on the debug panel. Escape pods will replace this one day.

const PlayerShipScene := preload("res://src/ships/player_ship.tscn")
## Free space needed around the respawn point, in meters.
const CLEARANCE := 60.0

@export var controller: PlayerController
@export var camera: OrbitCamera
@export var debug_panel: DebugPanel
@export var ships_root: Node3D
@export var spawn_point := Vector3.ZERO


func _ready() -> void:
	if debug_panel != null:
		debug_panel.add_action("Respawn player", respawn)


## Gives the player a new ship if the old one is gone. Returns the ship (old or new).
func respawn() -> Ship:
	if controller.has_ship():
		return controller.ship
	var ship := PlayerShipScene.instantiate() as Ship
	ship.enter_space(ships_root, Transform3D(Basis.IDENTITY, _free_point(spawn_point)))
	controller.ship = ship
	camera.target = ship
	return ship


## `point`, or a point above it with nothing (a wreck, a rock, a ship) too close.
func _free_point(point: Vector3) -> Vector3:
	var others := get_tree().get_nodes_in_group(Autopilot.OBSTACLE_GROUP) \
			+ get_tree().get_nodes_in_group(Autopilot.SHIP_GROUP)
	for attempt in 20:
		var blocked := false
		for node in others:
			var other := node as Node3D
			if point.distance_to(other.global_position) < Autopilot.radius_of(other) + CLEARANCE:
				blocked = true
				break
		if not blocked:
			return point
		point += Vector3.UP * CLEARANCE
	return point
