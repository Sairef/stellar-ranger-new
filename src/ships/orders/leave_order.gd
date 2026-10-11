class_name LeaveOrder
extends ShipOrder

## Fly out of a structure along a corridor: after undocking, or after arriving through a gate.
## The structure is not an obstacle on the way out; the corridor is released at its outer end.

## Closer than this to the outer end the ship counts as out, in meters.
const OUT_REACHED := 20.0

var structure: SpaceBody
var corridor: int

var _done := false


func _init(p_structure: SpaceBody, p_corridor: int) -> void:
	structure = p_structure
	corridor = p_corridor


func get_label() -> String:
	return "Leaving %s" % Autopilot.name_of(structure)


func get_target() -> Node3D:
	return structure


func update(ship: Ship, _delta: float) -> void:
	if _done:
		return
	if not is_instance_valid(structure):
		_done = true
		return
	if ship.global_position.distance_to(structure.get_corridor(corridor)["outer"]) < OUT_REACHED:
		_done = true
		structure.release_corridor(corridor, ship)


func get_goal(_ship: Ship) -> NavGoal:
	if _done:
		return null
	var outer: Vector3 = structure.get_corridor(corridor)["outer"]
	return NavGoal.new(outer, false, structure, EnterCorridorOrder.CORRIDOR_SPEED)


func is_complete(_ship: Ship) -> bool:
	return _done
