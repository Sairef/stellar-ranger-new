class_name ApproachOrder
extends ShipOrder

## Fly to a target and stay at a given distance from its surface.
## By default the order keeps following the target (even a moving one) until replaced.
## With `complete_on_arrival` it finishes as soon as the ship gets there; NPC routines use that.

## Extra slack (m) when checking whether the ship has arrived.
const ARRIVE_TOLERANCE := 10.0
const ARRIVE_SPEED := 3.0

var target: Node3D
## Desired gap between the ship's hull and the target's surface, in meters.
var distance: float
var complete_on_arrival: bool


func _init(p_target: Node3D, p_distance := 50.0, p_complete_on_arrival := false) -> void:
	target = p_target
	distance = p_distance
	complete_on_arrival = p_complete_on_arrival


func get_label() -> String:
	return "Approach %s" % Autopilot.name_of(target)


func get_target() -> Node3D:
	return target


func get_goal(ship: Ship) -> NavGoal:
	var center := target.global_position
	var away := ship.global_position - center
	if away.length_squared() < 0.01:
		away = ship.global_basis.z
	var stand_off := Autopilot.radius_of(target) + ship.radius + distance
	return NavGoal.new(center + away.normalized() * stand_off, true, target)


func is_complete(ship: Ship) -> bool:
	if not is_instance_valid(target):
		return true
	return complete_on_arrival and has_arrived(ship)


func has_arrived(ship: Ship) -> bool:
	var gap := ship.global_position.distance_to(target.global_position) \
			- Autopilot.radius_of(target) - ship.radius
	return gap <= distance + ARRIVE_TOLERANCE and ship.speed < ARRIVE_SPEED
