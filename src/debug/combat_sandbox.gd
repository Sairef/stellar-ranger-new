class_name CombatSandbox
extends Node3D

## Test bed for combat: the player and one pirate among a few rocks.
## A debug panel button spawns more pirates; the PlayerRespawner gives the player a new ship.

const ShipScene := preload("res://src/ships/ship.tscn")
const PIRATE_COLOR := Color(0.9, 0.25, 0.2)
## How far from the player new pirates appear, in meters.
const SPAWN_DISTANCE := 1500.0

@export var controller: PlayerController
@export var debug_panel: DebugPanel
@export var respawner: PlayerRespawner
@export var ships_root: Node3D

var _pirates := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 42
	_pirates = get_tree().get_node_count_in_group(CombatRoutine.GROUP)
	debug_panel.add_action("Spawn pirate", spawn_pirate)


func spawn_pirate() -> Ship:
	_pirates += 1
	var ship := ShipScene.instantiate() as Ship
	ship.name = "Pirate%d" % _pirates
	ship.display_name = "Pirate %d" % _pirates
	ship.faction = Factions.PIRATE
	ship.hull_color = PIRATE_COLOR
	ship.add_child(CombatRoutine.new())
	var center := controller.ship.global_position if controller.has_ship() else respawner.spawn_point
	var direction := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.15, 0.15), _rng.randf_range(-1, 1))
	direction = direction.normalized()
	ship.enter_space(ships_root, Transform3D(Basis.looking_at(-direction, Vector3.UP),
			center + direction * SPAWN_DISTANCE))
	return ship


func respawn_player() -> void:
	respawner.respawn()
