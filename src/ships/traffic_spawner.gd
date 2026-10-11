class_name TrafficSpawner
extends Node

## Keeps the system populated with traders. Some start docked at stations; new ones keep
## arriving through gates, while traders leave through gates on their own (TraderRoutine).
## Counts arrivals and departures for the debug panel.

const ShipScene := preload("res://src/ships/ship.tscn")
const NAMES: Array[String] = [
	"Kestrel", "Heron", "Osprey", "Wren", "Lark", "Finch", "Swift", "Plover", "Ibis",
	"Tern", "Egret", "Shrike", "Merlin", "Petrel", "Avocet", "Dunlin", "Gannet", "Linnet",
]
const COLORS: Array[Color] = [
	Color(0.8, 0.6, 1.0), Color(0.9, 0.8, 0.4), Color(0.85, 0.85, 0.9),
	Color(0.6, 0.85, 0.8), Color(0.95, 0.6, 0.5),
]

@export var stations: Array[NodePath] = []
@export var gates: Array[NodePath] = []
## Node the trader ships are added to. Only traders should live there.
@export var traffic_root: NodePath
@export var max_traders := 14
@export var initial_traders := 8
## Seconds between arrivals through gates, random within this range.
@export var arrival_interval := Vector2(6.0, 15.0)
@export var traffic_seed := 1

var arrivals := 0
var departures := 0

var _rng := RandomNumberGenerator.new()
var _root: Node
var _next_arrival := 0.0
var _serial := 0
var _started := false


func _ready() -> void:
	_rng.seed = traffic_seed
	_root = get_node(traffic_root)
	_next_arrival = _rng.randf_range(2.0, arrival_interval.x)


func _physics_process(delta: float) -> void:
	if not _started:
		# On the first tick rather than in _ready(), when every station is ready.
		_started = true
		_spawn_initial()

	_next_arrival -= delta
	if _next_arrival > 0.0:
		return
	_next_arrival = _rng.randf_range(arrival_interval.x, arrival_interval.y)
	if get_trader_count() >= max_traders:
		return
	var gate := _random_node(gates) as Gate
	var ship := _create_trader()
	if gate == null or not gate.try_receive(ship, _root):
		ship.free()
		_next_arrival = 1.0  # The gate throat is busy: try again soon.
		return
	arrivals += 1


func get_trader_count() -> int:
	return _root.get_child_count()


func _spawn_initial() -> void:
	for i in initial_traders:
		var station := _random_node(stations) as SpaceBody
		var corridor := _rng.randi() % station.get_corridor_count()
		var ship := _create_trader()
		ship.enter_space(_root, Transform3D(Basis.IDENTITY, station.get_corridor(corridor)["inner"]))
		ship.dock_instantly(station, corridor)
		# Stagger the first departures.
		(ship.get_node("TraderRoutine") as TraderRoutine).undock_in = _rng.randf_range(1.0, 20.0)


func _create_trader() -> Ship:
	_serial += 1
	var ship := ShipScene.instantiate() as Ship
	ship.name = "Trader%d" % _serial
	ship.display_name = "%s %d" % [NAMES[_rng.randi() % NAMES.size()], _serial]
	ship.hull_color = COLORS[_rng.randi() % COLORS.size()]
	ship.radius = _rng.randf_range(8.0, 12.0)
	ship.max_speed = _rng.randf_range(70.0, 100.0)
	ship.acceleration = _rng.randf_range(20.0, 30.0)
	ship.turn_rate = _rng.randf_range(0.8, 1.2)

	var routine := TraderRoutine.new()
	routine.name = "TraderRoutine"
	routine.stations = _absolute(stations)
	routine.gates = _absolute(gates)
	ship.add_child(routine)
	ship.jumped.connect(func(_gate: Gate) -> void: departures += 1)
	return ship


func _random_node(paths: Array[NodePath]) -> Node:
	if paths.is_empty():
		return null
	return get_node(paths[_rng.randi() % paths.size()])


## Routines live deep inside ships, so they get absolute paths.
func _absolute(paths: Array[NodePath]) -> Array[NodePath]:
	var result: Array[NodePath] = []
	for path in paths:
		result.append(get_node(path).get_path())
	return result
