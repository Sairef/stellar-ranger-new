class_name EnterCorridorOrder
extends ShipOrder

## Base for orders that take a ship into a structure through one of its corridors:
## fly to the corridor's holding point, wait until the corridor is free, reserve it and fly in.
## Subclasses decide what happens once the ship is inside (_on_inside(): dock, jump...).

enum Phase { TO_HOLD, WAITING, ENTERING, DONE }

## Closer than this to the holding point the ship starts asking for the corridor, in meters.
## Generous, because parking spreads waiting ships around the point.
const HOLD_REACHED := 80.0
## Closer than this to the inner end the ship counts as inside, in meters.
const INSIDE_REACHED := 6.0
## Speed limit inside corridors, m/s.
const CORRIDOR_SPEED := 40.0

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
	var points := body.get_corridor(corridor)
	if phase == Phase.TO_HOLD and ship.global_position.distance_to(points["hold"]) < HOLD_REACHED:
		phase = Phase.WAITING
	if phase == Phase.WAITING and body.try_reserve_corridor(corridor, ship, self):
		phase = Phase.ENTERING
	if phase == Phase.ENTERING and ship.global_position.distance_to(points["inner"]) < INSIDE_REACHED:
		phase = Phase.DONE
		_on_inside(ship, body)


func get_goal(_ship: Ship) -> NavGoal:
	var body := structure
	if body == null or phase == Phase.DONE or corridor < 0:
		return null
	var points := body.get_corridor(corridor)
	if phase == Phase.ENTERING:
		# Inside the corridor the structure is not an obstacle: the corridor is known to be clear.
		return NavGoal.new(points["inner"], true, body, CORRIDOR_SPEED)
	return NavGoal.new(points["hold"])


func is_complete(_ship: Ship) -> bool:
	return phase == Phase.DONE or structure == null


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
