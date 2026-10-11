class_name CombatRoutine
extends Node

## NPC fighter brain, placed as a child of a Ship: hunts the nearest hostile ship within
## detection range and attacks it until one of them is gone. Otherwise it waits.
## Gives orders through the same API the player uses.

const GROUP := &"fighters"

@export var detection_range := 3000.0
## Seconds between looks around for a new target.
@export var scan_interval := 1.0

var _ship: Ship
var _scan_in := 0.0


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
	if _ship.current_order is AttackOrder and not _ship.current_order.is_complete(_ship):
		return
	var target := _nearest_hostile()
	if target != null:
		_ship.give_order(AttackOrder.new(target))


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
