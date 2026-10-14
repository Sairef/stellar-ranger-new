class_name SystemSecurity
extends Node

## The star system's view of its own safety: which hostile ships (pirates, invaders) are out in
## space here, and whether the system is on alert. NPC brains ask it how to react. One per system
## scene; find it with of().
##
## Two levels. The alert is for an invasion: it starts as soon as an invader (ALARM_FACTIONS)
## shows up, or earlier when someone raises it by hand (an activating gate), and is lifted
## `all_clear_delay` seconds after the last invader is gone. On alert the whole system reacts:
## traders shelter or flee, no traffic comes in, miners go home, patrols hunt. Ordinary threats
## (pirates) do not stop the system: only who is close reacts (miners run from a pirate nearby,
## see threat_within()), and patrols hunt any hostile.
## Also carries short announcements for the HUD.

signal alert_started
signal all_clear

const GROUP := &"system_security"
## Hostility is judged from the point of view of the system's ordinary inhabitants.
const LOCAL_FACTION := Factions.NEUTRAL
## Hostiles that put the whole system on alert.
const ALARM_FACTIONS: Array[StringName] = [Factions.INVADER]
## How long an announcement stays on screen, in seconds.
const ANNOUNCEMENT_TIME := 6.0

@export var scan_interval := 0.5
## Seconds without hostiles before the alert is lifted.
@export var all_clear_delay := 8.0

var alert := false
var announcement := ""
## The latest announcement warns of danger (the HUD sounds the alarm for it).
var announcement_is_warning := false
## Announcements made so far, to tell a new one from the last one.
var announcements := 0

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
	if threats().any(func(ship: Ship) -> bool: return ship.faction in ALARM_FACTIONS):
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
	return threat_within(point, INF)


## The nearest hostile ship within `radius` of `point`, or null.
func threat_within(point: Vector3, radius: float) -> Ship:
	var best: Ship = null
	var best_distance := radius
	for ship in threats():
		var distance := point.distance_to(ship.global_position)
		if distance <= best_distance:
			best_distance = distance
			best = ship
	return best


## Where the danger is, as seen from `point`: the nearest hostile ship, or the expected source
## of trouble (e.g. an activating gate), or null if there is none.
func danger_near(point: Vector3) -> Node3D:
	var threat := nearest_threat(point)
	return threat if threat != null else _danger.resolve()


## Shows `text` in the HUD for a while; a `warning` sounds the alarm.
func announce(text: String, warning := false) -> void:
	announcement = text
	announcement_is_warning = warning
	announcements += 1
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
