class_name ApproachOrder
extends ShipOrder

## Fly to a target and stay at a given distance from its surface, nose on the target.
## By default the order keeps following the target (even a moving one) until replaced.
## A target that comes closer (flies at the ship or past it) does not make the ship back off:
## turning tail to make room and then turning back looked silly. The ship stays and watches it.
## With `complete_on_arrival` it finishes as soon as the ship gets there; NPC routines use that.
## Ends when the target is gone.

## Extra slack (m) when checking whether the ship has arrived.
const ARRIVE_TOLERANCE := 10.0
const ARRIVE_SPEED := 3.0

## The live target, or null once it is gone.
var target: Node3D:
	get:
		return _target.resolve()
## Desired gap between the ship's hull and the target's surface, in meters.
var distance: float
var complete_on_arrival: bool

var _target: ObjectRef


func _init(p_target: Node3D, p_distance := 50.0, p_complete_on_arrival := false) -> void:
	_target = ObjectRef.to(p_target)
	distance = p_distance
	complete_on_arrival = p_complete_on_arrival


func get_label() -> String:
	return "Approach %s" % Autopilot.name_of(target)


func get_target() -> Node3D:
	return target


func get_goal(ship: Ship) -> NavGoal:
	var node := target
	if node == null:
		return null
	var center := node.global_position
	var away := ship.global_position - center
	if away.length_squared() < 0.01:
		away = ship.global_basis.z
	var stand_off := Autopilot.radius_of(node) + ship.radius + distance
	var goal: NavGoal
	if away.length() < stand_off:
		# Closer than asked (the target came to us): stay put. That is not an arrival, so no
		# parking either: the ship that moves is the one that steers clear.
		goal = NavGoal.new(ship.global_position, false, node)
	else:
		goal = NavGoal.new(center + away.normalized() * stand_off, true, node)
	goal.face_point = center
	return goal


func is_complete(ship: Ship) -> bool:
	if target == null:
		return true
	return complete_on_arrival and has_arrived(ship)


func has_arrived(ship: Ship) -> bool:
	var node := target
	if node == null:
		return false
	var gap := ship.global_position.distance_to(node.global_position) \
			- Autopilot.radius_of(node) - ship.radius
	return gap <= distance + ARRIVE_TOLERANCE and ship.speed < ARRIVE_SPEED
