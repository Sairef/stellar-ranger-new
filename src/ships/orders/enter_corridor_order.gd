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

var structure: SpaceBody
var phase := Phase.TO_HOLD
var corridor := -1


func _init(p_structure: SpaceBody) -> void:
	structure = p_structure


func get_target() -> Node3D:
	return structure


func update(ship: Ship, _delta: float) -> void:
	if not is_instance_valid(structure):
		phase = Phase.DONE
		return
	if corridor < 0:
		corridor = structure.nearest_corridor(ship.global_position)
	var points := structure.get_corridor(corridor)
	if phase == Phase.TO_HOLD and ship.global_position.distance_to(points["hold"]) < HOLD_REACHED:
		phase = Phase.WAITING
	if phase == Phase.WAITING and structure.try_reserve_corridor(corridor, ship, self):
		phase = Phase.ENTERING
	if phase == Phase.ENTERING and ship.global_position.distance_to(points["inner"]) < INSIDE_REACHED:
		phase = Phase.DONE
		_on_inside(ship)


func get_goal(_ship: Ship) -> NavGoal:
	if phase == Phase.DONE or corridor < 0:
		return null
	var points := structure.get_corridor(corridor)
	if phase == Phase.ENTERING:
		# Inside the corridor the structure is not an obstacle: the corridor is known to be clear.
		return NavGoal.new(points["inner"], true, structure, CORRIDOR_SPEED)
	return NavGoal.new(points["hold"])


func is_complete(_ship: Ship) -> bool:
	return phase == Phase.DONE


## Override: the ship has reached the inner end of the corridor (which it still holds).
func _on_inside(_ship: Ship) -> void:
	pass


func _phase_suffix() -> String:
	match phase:
		Phase.WAITING:
			return " (waiting)"
		Phase.ENTERING:
			return " (entering)"
	return ""
