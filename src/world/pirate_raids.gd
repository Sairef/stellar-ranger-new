class_name PirateRaids
extends Node

## Pirate raids on the asteroid field, now and then. A few pirates come through a random gate
## (the HUD warns), fly to the field and prowl it, hunting whoever is there: miners first of all,
## the player too (CombatRoutine with the field as its territory). They stay until they are
## destroyed (by default; with a finite `stay_time` the ones still alive leave through the nearest
## gate after it): a field nobody clears is lost, its miners stay docked. One raid at a time: the
## next one is due `interval` seconds after the last raider is gone. No raid comes while the system is on alert (an
## invasion). Pirates do not put the system on alert (see SystemSecurity): miners nearby run home,
## patrols hunt them, everyone else goes on.
## With `auto` off raids come only by hand: start(), or the "Pirate raid" button that
## `debug_panel` gets.

signal raid_started
signal raid_over

enum Phase { WAITING, ARRIVING, HUNTING, LEAVING }

const ShipScene := preload("res://src/ships/ship.tscn")
const PIRATE_COLOR := Color(0.9, 0.25, 0.2)
## Seconds to wait before trying again when a raid is due during an alert.
const RETRY_TIME := 10.0

@export var gates: Array[NodePath] = []
@export var field: NodePath
@export var ships_root: NodePath
@export var debug_panel: DebugPanel
## Raids come on their own (see above).
@export var auto := true
## Seconds before the first raid, random within this range.
@export var first_raid := Vector2(90.0, 150.0)
## Seconds from the end of a raid to the next one, random within this range.
@export var interval := Vector2(180.0, 300.0)
## Small pirates in a raid, random within this range (both ends included).
@export var small_pirates := Vector2i(2, 3)
## Chance that a medium pirate leads the raid.
@export_range(0.0, 1.0) var leader_chance := 0.3
## Seconds the raiders stay after the last one came through the gate; INF: until destroyed.
@export var stay_time := INF
## Raiders hunt only ships this close to the field's center, in meters.
@export var hunt_radius := 1500.0
## 0 picks random raids every time; anything else repeats the same ones.
@export var event_seed := 0

var phase := Phase.WAITING
## Raids started so far.
var raids := 0
## Seconds until the next raid (while waiting, with `auto` on).
var next_raid_in := 0.0

## The gate of the current (or last) raid, or null.
var gate: Gate:
	get:
		return _gate.resolve() as Gate

var _gate := ObjectRef.new()
## Pirates still to come through the gate: {"name", "class"}.
var _queue: Array[Dictionary] = []
var _raiders: Array[ObjectRef] = []
var _stay_left := 0.0
var _serial := 0
var _rng := RandomNumberGenerator.new()


## A pirate fighter (not yet in space): hostile to everyone, hunts with a CombatRoutine.
static func create_pirate(display_name: String, size := ShipClass.Size.CUSTOM) -> Ship:
	var ship := ShipScene.instantiate() as Ship
	ship.name = display_name.replace(" ", "")
	ship.display_name = display_name
	ship.faction = Factions.PIRATE
	ship.hull_color = PIRATE_COLOR
	ship.ship_class = size
	var routine := CombatRoutine.new()
	routine.name = "CombatRoutine"
	ship.add_child(routine)
	return ship


func _ready() -> void:
	if event_seed != 0:
		_rng.seed = event_seed
	else:
		_rng.randomize()
	next_raid_in = _rng.randf_range(first_raid.x, first_raid.y)
	if debug_panel != null:
		debug_panel.add_action("Pirate raid", start)


func is_running() -> bool:
	return phase != Phase.WAITING


## Raiders of the current raid still in the system.
func raiders() -> Array[Ship]:
	var result: Array[Ship] = []
	for ref in _raiders:
		var ship := ref.resolve() as Ship
		if ship != null:
			result.append(ship)
	return result


## Starts a raid through `through`, or through a random gate, unless one is going on.
func start(through: Gate = null) -> void:
	if is_running():
		return
	var chosen := through if through != null else _random_gate()
	if chosen == null:
		return
	_gate = ObjectRef.to(chosen)
	_raiders.clear()
	_queue.clear()
	if _rng.randf() < leader_chance:
		_queue.append(_spec(ShipClass.Size.MEDIUM))
	for i in _rng.randi_range(small_pirates.x, small_pirates.y):
		_queue.append(_spec(ShipClass.Size.SMALL))
	phase = Phase.ARRIVING
	raids += 1
	_announce("Pirates jumped in through %s, heading for the asteroid field!" % Autopilot.name_of(chosen),
			true)
	raid_started.emit()


func _physics_process(delta: float) -> void:
	match phase:
		Phase.WAITING:
			if not auto:
				return
			next_raid_in -= delta
			if next_raid_in > 0.0:
				return
			var security := SystemSecurity.of(self)
			if security != null and security.alert:
				next_raid_in = RETRY_TIME
				return
			start()
		Phase.ARRIVING:
			if gate == null:
				_queue.clear()
			if not _queue.is_empty() and _try_arrive(_queue.front()):
				_queue.pop_front()
			if _queue.is_empty():
				phase = Phase.HUNTING
				_stay_left = stay_time
		Phase.HUNTING:
			_stay_left -= delta
			if raiders().is_empty():
				_finish()
			elif _stay_left <= 0.0:
				phase = Phase.LEAVING
				_send_home()
		Phase.LEAVING:
			if raiders().is_empty():
				_finish()
			else:
				_send_home()


func _spec(size: ShipClass.Size) -> Dictionary:
	_serial += 1
	return {"name": "Pirate %d" % _serial, "class": size}


## Brings the next pirate in through the gate. Returns false if the gate throat is busy.
func _try_arrive(spec: Dictionary) -> bool:
	var ship := create_pirate(spec["name"], spec["class"])
	var routine := ship.get_node("CombatRoutine") as CombatRoutine
	var area := get_node_or_null(field) as Node3D
	if area != null:
		routine.territory_center = area.global_position
		routine.territory_radius = hunt_radius
	if not gate.try_receive(ship, get_node(ships_root)):
		ship.free()
		return false
	_raiders.append(ObjectRef.to(ship))
	return true


## Sends every raider that is not on its way out yet to the nearest gate.
func _send_home() -> void:
	for ship in raiders():
		var routine := ship.get_node_or_null(^"CombatRoutine") as CombatRoutine
		if routine == null or (routine.is_leaving() and ship.current_order is JumpOrder):
			continue
		var exit := _nearest_gate(ship.global_position)
		if exit != null:
			routine.leave_through(exit)


func _finish() -> void:
	phase = Phase.WAITING
	next_raid_in = _rng.randf_range(interval.x, interval.y)
	raid_over.emit()


func _gates() -> Array[Gate]:
	var result: Array[Gate] = []
	for path in gates:
		var node := get_node_or_null(path) as Gate
		if node != null:
			result.append(node)
	return result


func _random_gate() -> Gate:
	var options := _gates()
	return options[_rng.randi() % options.size()] if not options.is_empty() else null


func _nearest_gate(point: Vector3) -> Gate:
	var best: Gate = null
	for option in _gates():
		if best == null or point.distance_to(option.global_position) < point.distance_to(best.global_position):
			best = option
	return best


func _announce(text: String, warning := false) -> void:
	var security := SystemSecurity.of(self)
	if security != null:
		security.announce(text, warning)
