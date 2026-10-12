class_name CombatRoutine
extends Node

## NPC fighter brain, placed as a child of a Ship: hunts the nearest hostile ship within
## detection range and attacks it until one of them is gone.
## With nobody to fight it docks at `home` if it has one (station garrisons), otherwise circles
## `assault_target` if it has one (invaders besieging a station), otherwise waits.
## Gives orders through the same API the player uses.

const GROUP := &"fighters"

@export var detection_range := 3000.0
## Seconds between looks around for a new target.
@export var scan_interval := 1.0

## Station to return to and dock at when there is nobody to fight, or null.
var home: SpaceBody:
	get:
		return _home.resolve() as SpaceBody
	set(value):
		_home = ObjectRef.to(value)
## Object to circle when there is nobody to fight, or null.
var assault_target: Node3D:
	get:
		return _assault.resolve()
	set(value):
		_assault = ObjectRef.to(value)

## Orbit distance around the assault target, in meters.
const SIEGE_DISTANCE := 300.0

var _ship: Ship
var _scan_in := 0.0
var _home := ObjectRef.new()
var _assault := ObjectRef.new()


func _ready() -> void:
	_ship = get_parent() as Ship
	_ship.add_to_group(GROUP)


func _physics_process(delta: float) -> void:
	if not _ship.is_in_space():
		return
	_scan_in -= delta
	if _scan_in > 0.0:
		return
	_scan_in = scan_interval
	var order := _ship.current_order
	if order != null and not order.is_interruptible():
		return
	if order is AttackOrder and not order.is_complete(_ship):
		return
	var target := _nearest_hostile()
	if target != null:
		_ship.give_order(AttackOrder.new(target))
		return
	if order is AttackOrder:
		order = null  # Its target is gone.
	if order != null:
		return  # Already on the way home or besieging.
	if home != null:
		_ship.give_order(DockOrder.new(home))
	elif assault_target != null:
		_ship.give_order(OrbitOrder.new(assault_target, SIEGE_DISTANCE))


func _nearest_hostile() -> Ship:
	var best: Ship = null
	var best_distance := detection_range
	for node in get_tree().get_nodes_in_group(Autopilot.SHIP_GROUP):
		var other := node as Ship
		if other == _ship or not _ship.is_hostile_to(other):
			continue
		var distance := _ship.global_position.distance_to(other.global_position)
		if distance < best_distance:
			best_distance = distance
			best = other
	return best
