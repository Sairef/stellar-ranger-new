class_name AttackOrder
extends ShipOrder

## Fight a ship: circle it inside weapon range while the weapons fire on their own.
## Ends when the target is destroyed or leaves space (docks, jumps out).

## Orbit at this fraction of the weapon range, so small drifts do not take it out of range.
const RANGE_FRACTION := 0.6
## Orbit distance for ships without weapons, in meters.
const UNARMED_DISTANCE := 300.0

## The live target, or null once it is gone.
var target: Ship:
	get:
		return _target.resolve() as Ship

var _target: ObjectRef
var _orbit: OrbitOrder


func _init(p_target: Ship) -> void:
	_target = ObjectRef.to(p_target)


func get_label() -> String:
	return "Attack %s" % Autopilot.name_of(target)


func get_target() -> Node3D:
	return target


func get_attack_target() -> Ship:
	return target


func get_goal(ship: Ship) -> NavGoal:
	var enemy := target
	if enemy == null:
		return null
	if _orbit == null:
		var weapon := ship.get_weapon()
		var distance := weapon.max_range * RANGE_FRACTION if weapon != null else UNARMED_DISTANCE
		_orbit = OrbitOrder.new(enemy, distance)
	return _orbit.get_goal(ship)


func is_complete(_ship: Ship) -> bool:
	var enemy := target
	return enemy == null or not enemy.is_in_space()
