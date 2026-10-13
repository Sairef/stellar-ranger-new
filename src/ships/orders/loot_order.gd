class_name LootOrder
extends ShipOrder

## Collect what is in wrecks and containers with the ship's drones (see DroneBay).
##
## Works on a given list of wrecks (Loot: one wreck; the scavenger: the abandoned ones), or on
## everything within `radius` of a point (Loot all: like X4's "collect drops"), including wrecks
## that appear while the order runs, but never containers this ship dropped itself.
## The ship flies toward the nearest wreck no drone is serving yet and sends a drone to every such
## wreck within drone range, then holds position until a drone is free or moves on to the next one.
## Ends when nothing is left and all drones are back, or when the hold is full (`hold_full`).
## Drones still out when the order is replaced come back on their own.

## The ship stops this far (gap, as a fraction of the drone range) from the wreck it heads for.
const STOP_FRACTION := 0.5

## True if the order ended because the hold had no room left.
var hold_full := false

var _targets: Array[ObjectRef] = []
var _area_mode := false
var _center := Vector3.ZERO
var _radius := 0.0
var _started := false
var _done := false
var _heading := ObjectRef.new()
var _left := 0


## Loot the given wrecks and containers.
func _init(wrecks: Array = []) -> void:
	for wreck: Node in wrecks:
		_targets.append(ObjectRef.to(wreck))


## Loot everything within `radius` of `center`, except containers dropped by the looting ship.
static func around(center: Vector3, radius: float) -> LootOrder:
	var order := LootOrder.new()
	order._area_mode = true
	order._center = center
	order._radius = radius
	return order


func get_label() -> String:
	var what := "Looting" if not _area_mode else "Looting all"
	if hold_full:
		return "%s: the hold is full" % what
	if _left == 0 and _started:
		return "%s: drones coming back" % what
	if _targets.size() == 1 and not _area_mode:
		return "Looting %s" % Autopilot.name_of(_targets[0].resolve())
	return "%s (%d left)" % [what, _left]


func get_target() -> Node3D:
	return _heading.resolve()


func update(ship: Ship, _delta: float) -> void:
	var bay: DroneBay = ship.get_drone_bay()
	if bay == null or bay.drones <= 0:
		_done = true
		return
	if not _started:
		_started = true
		bay.out_of_space = false
	var wrecks := _wrecks_left(ship)
	_left = wrecks.size()
	if not wrecks.is_empty() and (bay.out_of_space or bay.room_left() < 1.0):
		hold_full = true
	if hold_full or wrecks.is_empty():
		_done = bay.drones_out().is_empty()
		return
	for wreck in wrecks:
		if bay.available() <= 0:
			break
		if not bay.is_serving(wreck) and _gap(ship, wreck) <= bay.drone_range:
			bay.launch(wreck)


func get_goal(ship: Ship) -> NavGoal:
	var bay: DroneBay = ship.get_drone_bay()
	if bay == null or hold_full:
		return null
	var next: Wreck = null
	var best := INF
	for wreck in _wrecks_left(ship):
		var gap := _gap(ship, wreck)
		if gap < best and not bay.is_serving(wreck):
			best = gap
			next = wreck
	_heading = ObjectRef.to(next)
	var stop := bay.drone_range * STOP_FRACTION
	if next == null or best <= stop:
		return null  # Wait here for the drones.
	var away := (ship.global_position - next.global_position).normalized()
	var point := next.global_position + away * (next.radius + ship.radius + stop)
	return NavGoal.new(point, true, next)


func is_complete(_ship: Ship) -> bool:
	return _done


## Wrecks this order is about that still hold something.
func _wrecks_left(ship: Ship) -> Array[Wreck]:
	var result: Array[Wreck] = []
	if _area_mode:
		for node in ship.get_tree().get_nodes_in_group(Wreck.GROUP):
			var wreck := node as Wreck
			if wreck.global_position.distance_to(_center) <= _radius and not wreck.dropped_by.points_to(ship) \
					and not wreck.cargo.is_empty() and not wreck.is_queued_for_deletion():
				result.append(wreck)
	else:
		for ref in _targets:
			var wreck := ref.resolve() as Wreck
			if wreck != null and not wreck.cargo.is_empty():
				result.append(wreck)
	return result


func _gap(ship: Ship, wreck: Wreck) -> float:
	return ship.global_position.distance_to(wreck.global_position) - wreck.radius - ship.radius
