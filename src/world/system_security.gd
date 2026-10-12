class_name SystemSecurity
extends Node

## The star system's view of its own safety: which hostile ships (pirates, invaders) are out in
## space here, and whether the system is on alert. NPC brains ask it how to react (traders
## shelter or flee, miners go home, patrols hunt). One per system scene; find it with of().
##
## The alert starts as soon as a hostile ship shows up, or earlier when someone raises it by hand
## (an activating gate), and is lifted `all_clear_delay` seconds after the last hostile is gone.
## Also carries short announcements for the HUD.

signal alert_started
signal all_clear

const GROUP := &"system_security"
## Hostility is judged from the point of view of the system's ordinary inhabitants.
const LOCAL_FACTION := Factions.NEUTRAL
## How long an announcement stays on screen, in seconds.
const ANNOUNCEMENT_TIME := 6.0

@export var scan_interval := 0.5
## Seconds without hostiles before the alert is lifted.
@export var all_clear_delay := 8.0

var alert := false
var announcement := ""

## Where danger is expected before any hostile is seen (e.g. an activating gate).
var _danger: ObjectRef = ObjectRef.new()
var _scan_in := 0.0
var _quiet_for := 0.0
var _announced_at := -INF


static func of(node: Node) -> SystemSecurity:
	return node.get_tree().get_first_node_in_group(GROUP) as SystemSecurity


func _ready() -> void:
	add_to_group(GROUP)


func _physics_process(delta: float) -> void:
	_scan_in -= delta
	if _scan_in > 0.0:
		return
	_scan_in = scan_interval
	if not threats().is_empty():
		_quiet_for = minf(_quiet_for, 0.0)
		_set_alert(true)
	elif alert:
		_quiet_for += scan_interval
		if _quiet_for >= all_clear_delay:
			_danger = ObjectRef.new()
			_set_alert(false)
			announce("All clear")


## Puts the system on alert before any hostile is seen, for at least `hold` seconds
## (plus the all-clear delay). `danger` is where the trouble will come from.
func raise_alert(danger: Node3D, hold: float) -> void:
	_danger = ObjectRef.to(danger)
	_quiet_for = -hold
	_set_alert(true)


## Hostile ships in space in this system right now.
func threats() -> Array[Ship]:
	var result: Array[Ship] = []
	for node in get_tree().get_nodes_in_group(Autopilot.SHIP_GROUP):
		var ship := node as Ship
		if Factions.are_hostile(LOCAL_FACTION, ship.faction):
			result.append(ship)
	return result


func nearest_threat(point: Vector3) -> Ship:
	var best: Ship = null
	var best_distance := INF
	for ship in threats():
		var distance := point.distance_to(ship.global_position)
		if distance < best_distance:
			best_distance = distance
			best = ship
	return best


## Where the danger is, as seen from `point`: the nearest hostile ship, or the expected source
## of trouble (e.g. an activating gate), or null if there is none.
func danger_near(point: Vector3) -> Node3D:
	var threat := nearest_threat(point)
	return threat if threat != null else _danger.resolve()


func announce(text: String) -> void:
	announcement = text
	_announced_at = Time.get_ticks_msec() / 1000.0


## The latest announcement while it is still fresh, otherwise "".
func current_announcement() -> String:
	var age := Time.get_ticks_msec() / 1000.0 - _announced_at
	return announcement if age < ANNOUNCEMENT_TIME else ""


func _set_alert(value: bool) -> void:
	if value == alert:
		return
	alert = value
	if alert:
		alert_started.emit()
	else:
		all_clear.emit()
