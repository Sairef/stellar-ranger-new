class_name TraderRoutine
extends Node

## NPC trader brain, placed as a child of a Ship: flies between stations and stays docked at
## each for a while. After visiting at least one station it may leave the system through a gate
## (the ship is gone for good). Gives orders through the same API the player uses.
##
## On alert (SystemSecurity) a trader in space either runs for the nearest station to shelter,
## or flees the system through the gate farthest from the danger; a docked trader stays docked
## until the all clear. Corridor manoeuvres are finished first.

const GROUP := &"traders"

@export var stations: Array[NodePath] = []
@export var gates: Array[NodePath] = []
## Chance to leave the system after a station visit, 0..1.
@export var leave_chance := 0.3
## Seconds spent docked, random within this range.
@export var dock_time := Vector2(10.0, 25.0)
## Chance to flee the system rather than shelter at a station when an alert starts, 0..1.
@export var flee_chance := 0.4

## Seconds until the ship undocks (while docked).
var undock_in := 0.0

var _ship: Ship
var _rng := RandomNumberGenerator.new()
var _last_station := ObjectRef.new()
var _visited_station := false
## Already reacting to the current alert.
var _reacted := false


func _ready() -> void:
	_ship = get_parent() as Ship
	_ship.add_to_group(GROUP)
	_rng.seed = hash(_ship.display_name)
	_ship.docked.connect(_on_docked)


func _physics_process(delta: float) -> void:
	var security := SystemSecurity.of(self)
	var alert := security != null and security.alert
	if _ship.is_docked():
		if not alert:
			undock_in -= delta
			if undock_in <= 0.0:
				_ship.try_undock()
		return
	if alert:
		_react(security)
		return
	_reacted = false
	if _ship.current_order == null:
		_choose_destination()


## Shelter at the nearest station or flee through the safest gate, once per alert.
func _react(security: SystemSecurity) -> void:
	var order := _ship.current_order
	if _reacted and order != null:
		return  # Already sheltering or fleeing.
	if order != null and not order.is_interruptible():
		return  # Finish the corridor first.
	_reacted = true
	var danger := security.danger_near(_ship.global_position)
	var danger_point := danger.global_position if danger != null else _ship.global_position
	if _rng.randf() < flee_chance:
		var gate := _safest_gate(danger_point)
		if gate != null:
			_ship.give_order(JumpOrder.new(gate))
			return
	var station := _nearest(stations)
	if station != null:
		_ship.give_order(DockOrder.new(station))


## The gate far from the danger and not too far from the ship.
func _safest_gate(danger_point: Vector3) -> Gate:
	var best: Gate = null
	var best_score := -INF
	for path in gates:
		var gate := get_node_or_null(path) as Gate
		if gate == null:
			continue
		var score := gate.global_position.distance_to(danger_point) \
				- 0.5 * gate.global_position.distance_to(_ship.global_position)
		if score > best_score:
			best_score = score
			best = gate
	return best


func _nearest(paths: Array[NodePath]) -> SpaceBody:
	var best: SpaceBody = null
	var best_distance := INF
	for path in paths:
		var node := get_node_or_null(path) as SpaceBody
		if node == null:
			continue
		var distance := node.global_position.distance_to(_ship.global_position)
		if distance < best_distance:
			best_distance = distance
			best = node
	return best


func _on_docked(station: SpaceBody) -> void:
	_last_station = ObjectRef.to(station)
	_visited_station = true
	undock_in = _rng.randf_range(dock_time.x, dock_time.y)


func _choose_destination() -> void:
	if _visited_station and _rng.randf() < leave_chance:
		var gate := _pick(gates) as Gate
		if gate != null:
			_ship.give_order(JumpOrder.new(gate))
			return
	var station := _pick(stations, _last_station.resolve()) as SpaceBody
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
