class_name NpcRoutine
extends Node

## A minimal NPC "brain" placed as a child of a Ship.
## It gives the ship orders through the same API the player uses.
##
## PATROL: fly between waypoints forever, pausing at each one.
## ORBIT: circle the first waypoint forever.
## With `defend` set, the ship drops its routine while the system is on alert (SystemSecurity):
## it attacks the nearest hostile, or, before any shows up, waits near where the danger is
## expected (e.g. an activating gate). After the all clear it goes back to its routine.

enum Mode { PATROL, ORBIT }

const GROUP := &"patrols"
## Gap to keep from the expected danger while waiting for it, in meters.
const INTERCEPT_DISTANCE := 400.0

@export var mode := Mode.PATROL
@export var waypoints: Array[NodePath] = []
## Approach distance (PATROL) or orbit distance (ORBIT) from the target's surface, in meters.
@export var distance := 60.0
## Seconds to wait at each patrol waypoint.
@export var pause := 2.0
@export var defend := false

var _ship: Ship
var _next := 0
var _wait := 0.0
var _defending := false


func _ready() -> void:
	_ship = get_parent() as Ship
	_ship.add_to_group(GROUP)


func _physics_process(delta: float) -> void:
	if _ship == null or not _ship.is_in_space():
		return
	if defend and _defend():
		return
	if waypoints.is_empty() or _ship.current_order != null:
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


## Handles the alert. Returns true while the ship is busy defending.
func _defend() -> bool:
	var security := SystemSecurity.of(self)
	if security == null or not security.alert:
		if _defending:
			_defending = false
			_ship.give_order(null)  # Back to the routine.
		return false
	_defending = true
	var order := _ship.current_order
	if order != null and not order.is_interruptible():
		return true
	if order is AttackOrder and not order.is_complete(_ship):
		return true
	var threat := security.nearest_threat(_ship.global_position)
	if threat != null:
		_ship.give_order(AttackOrder.new(threat))
		return true
	var danger := security.danger_near(_ship.global_position)
	var waiting := order is ApproachOrder and (order as ApproachOrder).target == danger
	if danger != null and not waiting:
		_ship.give_order(ApproachOrder.new(danger, INTERCEPT_DISTANCE))
	return true
