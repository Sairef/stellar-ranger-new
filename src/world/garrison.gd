class_name Garrison
extends Node

## The military ships of a station, as a child node of it (Bastion Outpost's in the home system).
## They wait docked at full strength (`small`, `medium`, `large`) and are launched on demand:
## all of them against an invasion (launch_all()), or a few against pirates raiding the asteroid
## field (launch(), with the field as their territory: see CombatRoutine). Launched ships leave one
## after another as the ports free up, fight like any other fighter and dock back home when
## nobody is left to fight. The garrison is topped up to full strength before every launch, so
## losses do not carry over (for now).
## This is the one place defenders are made. Not a world object: callers find it on the station
## every time they need it (Garrison.of()) and never keep it, as the station may vanish.

const ShipScene := preload("res://src/ships/ship.tscn")
const DEFENDER_COLOR := Color(0.45, 0.9, 0.45)

## Where new defenders go in the tree (they start docked).
@export var ships_root: NodePath
## Ships of each class at full strength.
@export var small := 5
@export var medium := 2
@export var large := 1
@export var detection_range := 6000.0

## Ships that undocked so far.
var ships_launched := 0

var _ships: Array[ObjectRef] = []
## Docked ships launched, waiting for a free port to leave.
var _queue: Array[ObjectRef] = []
var _serial := 0


## The garrison of `station`, or null if it has none (or there is no station).
static func of(station: Node) -> Garrison:
	if station == null:
		return null
	for child in station.get_children():
		if child is Garrison:
			return child
	return null


## Ships at full strength.
func strength() -> int:
	return small + medium + large


## The garrison's ships, docked or out.
func ships() -> Array[Ship]:
	var result: Array[Ship] = []
	for ref in _ships:
		var ship := ref.resolve() as Ship
		if ship != null:
			result.append(ship)
	return result


## Makes the ships missing from full strength, docked at the station.
func top_up() -> void:
	var station := get_parent() as SpaceBody
	if station == null or station.get_corridor_count() == 0:
		return
	_ships = _ships.filter(func(ref: ObjectRef) -> bool: return ref.resolve() != null)
	var missing := ShipClass.sizes(small, medium, large)
	for ship in ships():
		missing.erase(ship.ship_class)
	for size in missing:
		_create_defender(size, station)


## Launches a docked ship of every class in `sizes` (fewer if the garrison has no more docked),
## to fight within `territory_radius` of `territory_center` (anywhere for INF). Returns the
## ships launched.
func launch(sizes: Array[ShipClass.Size], territory_center := Vector3.ZERO,
		territory_radius := INF) -> Array[ObjectRef]:
	top_up()
	var launched: Array[ObjectRef] = []
	for size in sizes:
		var ship := _docked_ship(size)
		if ship == null:
			continue
		_assign(ship, territory_center, territory_radius)
		var ref := ObjectRef.to(ship)
		_queue.append(ref)
		launched.append(ref)
	return launched


## Launches every ship to fight anywhere (an invasion): the docked ones leave, and the ones
## already out drop the territory they had been given. Returns the ships launched from the
## docks: they are this caller's now (a ship an earlier launch() queued too, so cancelling that
## launch does not keep it home).
func launch_all() -> Array[ObjectRef]:
	top_up()
	var launched: Array[ObjectRef] = []
	for ship in ships():
		_assign(ship, Vector3.ZERO, INF)
		if ship.is_docked():
			_unqueue(ship)
			var ref := ObjectRef.to(ship)
			_queue.append(ref)
			launched.append(ref)
	return launched


## Keeps those of `launched` (what launch() or launch_all() returned) that have not left yet at
## home.
func cancel(launched: Array[ObjectRef]) -> void:
	for ref in launched:
		_queue.erase(ref)


## `ship` is out on a task: in space, or waiting for a port to leave.
func is_out(ship: Ship) -> bool:
	return ship.is_in_space() or is_queued(ship)


## `ship` was launched and waits for a port to leave.
func is_queued(ship: Ship) -> bool:
	for ref in _queue:
		if ref.points_to(ship):
			return true
	return false


## Undocks the launched ships one by one as their ports free up.
func _physics_process(_delta: float) -> void:
	for ref in _queue.duplicate():
		var ship := ref.resolve() as Ship
		if ship == null or not ship.is_docked():
			_queue.erase(ref)
		elif ship.try_undock():
			_queue.erase(ref)
			ships_launched += 1


func _unqueue(ship: Ship) -> void:
	for ref in _queue.duplicate():
		if ref.points_to(ship):
			_queue.erase(ref)


func _docked_ship(size: ShipClass.Size) -> Ship:
	for ship in ships():
		if ship.ship_class == size and ship.is_docked() and not is_queued(ship):
			return ship
	return null


func _assign(ship: Ship, territory_center: Vector3, territory_radius: float) -> void:
	var routine := ship.get_node_or_null(^"CombatRoutine") as CombatRoutine
	if routine != null:
		routine.territory_center = territory_center
		routine.territory_radius = territory_radius


func _create_defender(size: ShipClass.Size, station: SpaceBody) -> void:
	_serial += 1
	var ship := ShipScene.instantiate() as Ship
	ship.name = "Defender%d" % _serial
	ship.display_name = "Defender %d" % _serial
	ship.hull_color = DEFENDER_COLOR
	ship.ship_class = size
	var routine := CombatRoutine.new()
	routine.name = "CombatRoutine"
	routine.detection_range = detection_range
	routine.home = station
	ship.add_child(routine)
	var corridor := _ships.size() % station.get_corridor_count()
	ship.enter_space(get_node(ships_root), Transform3D(Basis.IDENTITY, station.get_corridor(corridor)["inner"]))
	ship.dock_instantly(station, corridor)
	_ships.append(ObjectRef.to(ship))
