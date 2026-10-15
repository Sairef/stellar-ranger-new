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
## The military answers: `response_delay` seconds after a raid starts (the warning says when),
## the defense station's Garrison sends a squad (`squad_small` + `squad_medium` ships) to clear
## the field, and docks it home once the field is clear. If the squad is lost or comes home with
## raiders still there, another one follows after the same delay. Not during an alert: then the
## whole garrison is out anyway. So a raid nobody fights costs the field for a few minutes, and a
## pilot who joins the squad (or beats it to the field) gets the bounties.
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
## The station whose Garrison answers raids; none: nobody does.
@export var defense_station: NodePath
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
## Seconds from the start of a raid (or the loss of a squad) to the squad's launch; INF: never.
@export var response_delay := 120.0
## Ships of each class in a squad.
@export var squad_small := 3
@export var squad_medium := 1
## 0 picks random raids every time; anything else repeats the same ones.
@export var event_seed := 0

var phase := Phase.WAITING
## Raids started so far.
var raids := 0
## Seconds until the next raid (while waiting, with `auto` on).
var next_raid_in := 0.0
## Squads the defense station sent against raids so far.
var squads_sent := 0
## Seconds until the next squad is sent (INF while none is due).
var response_in := INF

## The gate of the current (or last) raid, or null.
var gate: Gate:
	get:
		return _gate.resolve() as Gate

var _gate := ObjectRef.new()
## Pirates still to come through the gate: {"name", "class"}.
var _queue: Array[Dictionary] = []
var _raiders: Array[ObjectRef] = []
## The squad out against the current raid (empty while none is).
var _squad: Array[ObjectRef] = []
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
	_squad.clear()
	response_in = response_delay if _garrison() != null else INF
	var text := "Pirates jumped in through %s, heading for the asteroid field!" % Autopilot.name_of(chosen)
	if response_in < INF:
		text += " %s will send a squad in %s." % [_station_name(), _minutes(response_in)]
	_announce(text, true)
	raid_started.emit()


func _physics_process(delta: float) -> void:
	if is_running():
		_update_response(delta)
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
	var garrison := _garrison()
	if garrison != null:
		garrison.cancel(_squad)  # The ones still docked stay home; the rest come back by themselves.
	_squad.clear()
	response_in = INF
	next_raid_in = _rng.randf_range(interval.x, interval.y)
	raid_over.emit()


## Sends a squad when it is due, and starts the wait for the next one once it is lost or home.
func _update_response(delta: float) -> void:
	var garrison := _garrison()
	if garrison == null or (response_in == INF and _squad.is_empty()):
		return
	if not _squad.is_empty():
		for ref in _squad:
			var ship := ref.resolve() as Ship
			if ship != null and garrison.is_out(ship):
				return
		_squad.clear()
		response_in = response_delay
		_announce("Pirates still hold the asteroid field: %s will send another squad in %s."
				% [_station_name(), _minutes(response_in)])
		return
	response_in -= delta
	var security := SystemSecurity.of(self)
	# Not while nobody is there (still to come through the gate, or the last one just died).
	if response_in > 0.0 or (security != null and security.alert) or raiders().is_empty():
		return
	var area := get_node_or_null(field) as Node3D
	var center := area.global_position if area != null else Vector3.ZERO
	_squad = garrison.launch(ShipClass.sizes(squad_small, squad_medium, 0), center, hunt_radius)
	if _squad.is_empty():
		response_in = RETRY_TIME
		return
	squads_sent += 1
	response_in = INF
	_announce("%s sends a squad to the asteroid field" % _station_name())


func _garrison() -> Garrison:
	return Garrison.of(get_node_or_null(defense_station)) if response_delay < INF else null


func _station_name() -> String:
	return Autopilot.name_of(get_node_or_null(defense_station))


## "~3 min" for 180 seconds (at least a minute).
static func _minutes(seconds: float) -> String:
	return "~%d min" % maxi(1, roundi(seconds / 60.0))


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
