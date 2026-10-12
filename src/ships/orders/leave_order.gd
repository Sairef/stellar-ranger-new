class_name LeaveOrder
extends ShipOrder

## Fly out of a structure along a corridor: after undocking, or after arriving through a gate.
## The structure is not an obstacle on the way out; the corridor is released at its outer end.
## `lane` shifts the whole way out sideways, so several ships can come out of a gate side by
## side (an invasion fleet does not queue for the throat). Ends at once if the structure is gone.

## Closer than this to the end of the lane the ship counts as out, in meters.
const OUT_REACHED := 20.0

## The live structure, or null once it is gone.
var structure: SpaceBody:
	get:
		return _structure.resolve() as SpaceBody
var corridor: int
## Global offset of this ship's lane from the corridor axis.
var lane: Vector3

var _structure: ObjectRef
var _done := false


func _init(p_structure: SpaceBody, p_corridor: int, p_lane := Vector3.ZERO) -> void:
	_structure = ObjectRef.to(p_structure)
	corridor = p_corridor
	lane = p_lane


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
	if ship.global_position.distance_to(_exit_point(body)) < OUT_REACHED:
		_done = true
		body.release_corridor(corridor, ship)


func get_goal(_ship: Ship) -> NavGoal:
	var body := structure
	if _done or body == null:
		return null
	return NavGoal.new(_exit_point(body), false, body, EnterCorridorOrder.CORRIDOR_SPEED)


func is_complete(_ship: Ship) -> bool:
	return _done or structure == null


func is_interruptible() -> bool:
	return false


func _exit_point(body: SpaceBody) -> Vector3:
	return body.get_corridor(corridor)["outer"] + lane
