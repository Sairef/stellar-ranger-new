class_name DroneBay
extends Node

## Cargo drones, placed as a child of a Ship (like Weapon). LootOrder sends them out: each drone
## flies to a wreck or container, loads what fits into the mother ship's free hold space, comes
## back and lands, unloading into the hold (see DroneRoutine).
## Drones are small unarmed ships (Ship.is_drone): they can be shot down and are then lost
## (with their load, in a wreck), but weapons pick armed targets first.

const ShipScene := preload("res://src/ships/ship.tscn")
const DRONE_RADIUS := 2.5

## Drones carried. Lost drones are not replaced (yet).
@export var drones := 3
## How far from the mother ship drones are sent, in meters.
@export var drone_range := 600.0

## Set when a drone had to leave something behind because the hold had no room for it.
## LootOrder resets it when it starts.
var out_of_space := false

var _ship: Ship
var _out: Array[ObjectRef] = []


func _ready() -> void:
	_ship = get_parent() as Ship


## Drones out in space right now.
func drones_out() -> Array[Ship]:
	var result: Array[Ship] = []
	for ref in _out:
		var drone := ref.resolve() as Ship
		if drone != null:
			result.append(drone)
	return result


## Drones ready to launch.
func available() -> int:
	return drones - drones_out().size()


## True if one of the drones is on its way to (or loading from) `wreck`.
func is_serving(wreck: Wreck) -> bool:
	for drone in drones_out():
		var routine := drone.get_node_or_null(^"DroneRoutine") as DroneRoutine
		if routine != null and routine.wreck == wreck:
			return true
	return false


## Pieces the drones out there are carrying back.
func carried() -> int:
	var sum := 0
	for drone in drones_out():
		sum += drone.cargo.total()
	return sum


## Room in the mother ship's hold not yet promised to drones on their way back.
func room_left() -> float:
	return _ship.cargo.room() - carried()


## Sends a drone to `wreck`. Returns it, or null if no drone is available.
func launch(wreck: Wreck) -> Ship:
	if available() <= 0 or wreck == null or not _ship.is_in_space():
		return null
	_out = _out.filter(func(ref: ObjectRef) -> bool: return ref.resolve() != null)
	var drone := ShipScene.instantiate() as Ship
	drone.name = "Drone"
	drone.display_name = "Drone"
	drone.is_drone = true
	drone.faction = _ship.faction
	drone.hull_color = _ship.hull_color.lightened(0.4)
	drone.radius = DRONE_RADIUS
	drone.max_shield = 4.0
	drone.max_armor = 2.0
	drone.max_speed = 150.0
	drone.acceleration = 80.0
	drone.turn_rate = 3.0
	drone.cargo_capacity = INF
	drone.get_weapon().free()  # Unarmed.
	var routine := DroneRoutine.new()
	routine.name = "DroneRoutine"
	routine.mother = _ship
	routine.wreck = wreck
	drone.add_child(routine)
	var heading := wreck.global_position - _ship.global_position
	var up := Vector3.UP if absf(heading.normalized().dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
	drone.enter_space(_ship.get_parent(), Transform3D(Basis.looking_at(heading, up), _ship.global_position))
	drone.speed = minf(_ship.speed, drone.max_speed)
	drone.destroyed.connect(_on_drone_destroyed)
	_out.append(ObjectRef.to(drone))
	return drone


## Called by a drone back at the mother ship: unloads it and takes it in.
func land(drone: Ship) -> void:
	drone.cargo.move_to(_ship.cargo)
	# Whatever did not fit (the hold shrank meanwhile) goes down with the drone: rare enough.
	drone.vanish()


func _on_drone_destroyed(_drone: Ship, _wreck: Wreck) -> void:
	drones = maxi(0, drones - 1)
