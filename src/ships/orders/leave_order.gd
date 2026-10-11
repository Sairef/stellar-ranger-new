class_name LeaveOrder
extends ShipOrder

## Fly out of a structure along a corridor: after undocking, or after arriving through a gate.
## The structure is not an obstacle on the way out; the corridor is released at its outer end.
## Ends at once if the structure is gone.

## Closer than this to the outer end the ship counts as out, in meters.
const OUT_REACHED := 20.0

## The live structure, or null once it is gone.
var structure: SpaceBody:
	get:
		return _structure.resolve() as SpaceBody
var corridor: int

var _structure: ObjectRef
var _done := false


func _init(p_structure: SpaceBody, p_corridor: int) -> void:
	_structure = ObjectRef.to(p_structure)
	corridor = p_corridor


func get_label() -> String:
	return "Leaving %s" % Autopilot.name_of(structure)


func get_target() -> Node3D:
	return structure


func update(ship: Ship, _delta: float) -> void:
	if _done:
		return
	var body := structure
	if body == null:
		_done = true
		return
	if ship.global_position.distance_to(body.get_corridor(corridor)["outer"]) < OUT_REACHED:
		_done = true
		body.release_corridor(corridor, ship)


func get_goal(_ship: Ship) -> NavGoal:
	var body := structure
	if _done or body == null:
		return null
	var outer: Vector3 = body.get_corridor(corridor)["outer"]
	return NavGoal.new(outer, false, body, EnterCorridorOrder.CORRIDOR_SPEED)


func is_complete(_ship: Ship) -> bool:
	return _done or structure == null
