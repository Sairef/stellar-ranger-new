class_name CombatSandbox
extends Node3D

## Test bed for combat: the player and one pirate among a few rocks.
## Debug panel buttons spawn more pirates and give the player a new ship after a loss.

const ShipScene := preload("res://src/ships/ship.tscn")
const PIRATE_COLOR := Color(0.9, 0.25, 0.2)
const PLAYER_COLOR := Color(0.3, 0.75, 1.0)
## How far from the player new pirates appear, in meters.
const SPAWN_DISTANCE := 1500.0
## Free space needed around the player's respawn point, in meters.
const RESPAWN_CLEARANCE := 60.0

@export var controller: PlayerController
@export var camera: OrbitCamera
@export var debug_panel: DebugPanel
@export var ships_root: Node3D
@export var player_spawn_point := Vector3.ZERO

var _pirates := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 42
	_pirates = get_tree().get_node_count_in_group(CombatRoutine.GROUP)
	debug_panel.add_action("Spawn pirate", spawn_pirate)
	debug_panel.add_action("Respawn player", respawn_player)


func spawn_pirate() -> Ship:
	_pirates += 1
	var ship := ShipScene.instantiate() as Ship
	ship.name = "Pirate%d" % _pirates
	ship.display_name = "Pirate %d" % _pirates
	ship.faction = Factions.PIRATE
	ship.hull_color = PIRATE_COLOR
	ship.add_child(CombatRoutine.new())
	var center := controller.ship.global_position if controller.has_ship() else player_spawn_point
	var direction := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.15, 0.15), _rng.randf_range(-1, 1))
	direction = direction.normalized()
	ship.enter_space(ships_root, Transform3D(Basis.looking_at(-direction, Vector3.UP),
			center + direction * SPAWN_DISTANCE))
	return ship


## Gives the player a new ship if the old one was destroyed.
func respawn_player() -> void:
	if controller.has_ship():
		return
	var ship := ShipScene.instantiate() as Ship
	ship.display_name = "You"
	ship.faction = Factions.PLAYER
	ship.hull_color = PLAYER_COLOR
	ship.enter_space(ships_root, Transform3D(Basis.IDENTITY, _free_point(player_spawn_point)))
	controller.ship = ship
	camera.target = ship


## `point`, or a point above it with nothing (a wreck, a rock, a ship) too close.
func _free_point(point: Vector3) -> Vector3:
	var others := get_tree().get_nodes_in_group(Autopilot.OBSTACLE_GROUP) \
			+ get_tree().get_nodes_in_group(Autopilot.SHIP_GROUP)
	for attempt in 20:
		var blocked := false
		for node in others:
			var other := node as Node3D
			if point.distance_to(other.global_position) < Autopilot.radius_of(other) + RESPAWN_CLEARANCE:
				blocked = true
				break
		if not blocked:
			return point
		point += Vector3.UP * RESPAWN_CLEARANCE
	return point
