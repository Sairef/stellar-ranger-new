class_name NpcRoutine
extends Node

## A minimal NPC "brain" placed as a child of a Ship.
## It gives the ship orders through the same API the player uses.
##
## PATROL: fly between waypoints forever, pausing at each one.
## ORBIT: circle the first waypoint forever.

enum Mode { PATROL, ORBIT }

@export var mode := Mode.PATROL
@export var waypoints: Array[NodePath] = []
## Approach distance (PATROL) or orbit distance (ORBIT) from the target's surface, in meters.
@export var distance := 60.0
## Seconds to wait at each patrol waypoint.
@export var pause := 2.0

var _ship: Ship
var _next := 0
var _wait := 0.0


func _ready() -> void:
	_ship = get_parent() as Ship


func _physics_process(delta: float) -> void:
	if _ship == null or waypoints.is_empty() or _ship.current_order != null:
		return

	if mode == Mode.ORBIT:
		var center := get_node_or_null(waypoints[0]) as Node3D
		if center != null:
			_ship.give_order(OrbitOrder.new(center, distance))
		return

	_wait -= delta
	if _wait > 0.0:
		return
	var target := get_node_or_null(waypoints[_next]) as Node3D
	_next = (_next + 1) % waypoints.size()
	if target != null:
		_ship.give_order(ApproachOrder.new(target, distance, true))
		_wait = pause
