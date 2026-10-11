class_name AttackOrder
extends ShipOrder

## Fight a ship: circle it inside weapon range while the weapons fire on their own.
## Ends when the target is destroyed or leaves space (docks, jumps out).

## Orbit at this fraction of the weapon range, so small drifts do not take it out of range.
const RANGE_FRACTION := 0.6
## Orbit distance for ships without weapons, in meters.
const UNARMED_DISTANCE := 300.0

var target: Ship
var _orbit: OrbitOrder


func _init(p_target: Ship) -> void:
	target = p_target


func get_label() -> String:
	return "Attack %s" % Autopilot.name_of(target)


func get_target() -> Node3D:
	return target


func get_attack_target() -> Ship:
	return target if is_instance_valid(target) else null


func get_goal(ship: Ship) -> NavGoal:
	if _orbit == null:
		var weapon := ship.get_weapon()
		var distance := weapon.max_range * RANGE_FRACTION if weapon != null else UNARMED_DISTANCE
		_orbit = OrbitOrder.new(target, distance)
	return _orbit.get_goal(ship)


func is_complete(_ship: Ship) -> bool:
	return not is_instance_valid(target) or not target.is_in_space()
