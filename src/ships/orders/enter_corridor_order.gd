class_name EnterCorridorOrder
extends ShipOrder

## Base for orders that take a ship into a structure through one of its corridors:
## fly to the corridor's holding point, get in line (SpaceBody.waiting_spot()), and when it is
## this ship's turn and the corridor is free, reserve it and fly in.
## Subclasses decide what happens once the ship is inside (_on_inside(): dock, jump...).

enum Phase { TO_HOLD, WAITING, ENTERING, DONE }

## Closer than this to its place in line the ship joins the line, in meters, plus twice its
## radius. Generous: parking may still push the place aside (big ships farther).
const HOLD_REACHED := 80.0
## Closer than this to the inner end the ship counts as inside, in meters.
const INSIDE_REACHED := 6.0
## Speed limit inside corridors, m/s.
const CORRIDOR_SPEED := 40.0
## Speed limit while waiting for the corridor, m/s.
const WAITING_SPEED := 20.0

## The live structure, or null once it is gone (then the order ends).
var structure: SpaceBody:
	get:
		return _structure.resolve() as SpaceBody
var phase := Phase.TO_HOLD
var corridor := -1

var _structure: ObjectRef


func _init(p_structure: SpaceBody) -> void:
	_structure = ObjectRef.to(p_structure)


func get_target() -> Node3D:
	return structure


func update(ship: Ship, _delta: float) -> void:
	var body := structure
	if body == null:
		phase = Phase.DONE
		return
	if corridor < 0:
		corridor = body.nearest_corridor(ship.global_position)
	var points := body.get_corridor(corridor, ship.radius)
	var near_spot := ship.global_position.distance_to(body.waiting_spot(corridor, ship)) \
			< HOLD_REACHED + 2.0 * ship.radius
	if phase == Phase.TO_HOLD and near_spot:
		phase = Phase.WAITING
		body.join_line(corridor, ship, self)
	if phase == Phase.WAITING and body.is_first_in_line(corridor, ship) \
			and body.try_reserve_corridor(corridor, ship, self):
		phase = Phase.ENTERING
		body.leave_line(corridor, ship)
	if phase == Phase.ENTERING and ship.global_position.distance_to(points["inner"]) < INSIDE_REACHED:
		phase = Phase.DONE
		_on_inside(ship, body)


func get_goal(ship: Ship) -> NavGoal:
	var body := structure
	if body == null or phase == Phase.DONE or corridor < 0:
		return null
	var points := body.get_corridor(corridor, ship.radius)
	if phase == Phase.ENTERING:
		# Inside the corridor the structure is not an obstacle: the corridor is known to be clear.
		return NavGoal.new(points["inner"], true, body, CORRIDOR_SPEED)
	# Ships in line move up it slowly, so even big ones never bump into each other.
	return NavGoal.new(body.waiting_spot(corridor, ship), true, null,
			WAITING_SPEED if phase == Phase.WAITING else INF)


func is_complete(_ship: Ship) -> bool:
	return phase == Phase.DONE or structure == null


func is_interruptible() -> bool:
	return phase != Phase.ENTERING


## Override: the ship has reached the inner end of the corridor (which it still holds).
func _on_inside(_ship: Ship, _body: SpaceBody) -> void:
	pass


func _phase_suffix() -> String:
	match phase:
		Phase.WAITING:
			return " (waiting)"
		Phase.ENTERING:
			return " (entering)"
	return ""
