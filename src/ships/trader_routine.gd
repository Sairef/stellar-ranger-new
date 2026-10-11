class_name TraderRoutine
extends Node

## NPC trader brain, placed as a child of a Ship: flies between stations and stays docked at
## each for a while. After visiting at least one station it may leave the system through a gate
## (the ship is gone for good). Gives orders through the same API the player uses.

const GROUP := &"traders"

@export var stations: Array[NodePath] = []
@export var gates: Array[NodePath] = []
## Chance to leave the system after a station visit, 0..1.
@export var leave_chance := 0.3
## Seconds spent docked, random within this range.
@export var dock_time := Vector2(10.0, 25.0)

## Seconds until the ship undocks (while docked).
var undock_in := 0.0

var _ship: Ship
var _rng := RandomNumberGenerator.new()
var _last_station: Node = null
var _visited_station := false


func _ready() -> void:
	_ship = get_parent() as Ship
	_ship.add_to_group(GROUP)
	_rng.seed = hash(_ship.display_name)
	_ship.docked.connect(_on_docked)


func _physics_process(delta: float) -> void:
	if _ship.is_docked():
		undock_in -= delta
		if undock_in <= 0.0:
			_ship.try_undock()
		return
	if _ship.current_order == null:
		_choose_destination()


func _on_docked(station: SpaceBody) -> void:
	_last_station = station
	_visited_station = true
	undock_in = _rng.randf_range(dock_time.x, dock_time.y)


func _choose_destination() -> void:
	if _visited_station and _rng.randf() < leave_chance:
		var gate := _pick(gates) as Gate
		if gate != null:
			_ship.give_order(JumpOrder.new(gate))
			return
	var station := _pick(stations, _last_station) as SpaceBody
	if station != null:
		_ship.give_order(DockOrder.new(station))


## Random node from `paths`, preferring anything but `avoid`.
func _pick(paths: Array[NodePath], avoid: Node = null) -> Node:
	var options: Array[Node] = []
	for path in paths:
		var node := get_node_or_null(path)
		if node != null and node != avoid:
			options.append(node)
	if options.is_empty():
		return avoid
	return options[_rng.randi() % options.size()]
