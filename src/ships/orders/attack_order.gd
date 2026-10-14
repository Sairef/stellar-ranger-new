class_name AttackOrder
extends ShipOrder

## Fight a ship: circle it at `distance` while the weapons fire on their own.
## The distance decides how well both sides hit (Weapon.hit_chance_against()): by default it is
## the weapon's best distance (Weapon.best_distance()), so every class fights where its guns work
## best; the player can change it while the order runs (PlayerController).
## A target that gets well away is chased, not circled: the ship flies straight to where the
## target will be when it gets there (an intercept), so it catches up with a target that flies
## around in a fight. Close enough again, it circles.
## Ends when the target is destroyed or leaves space (docks, jumps out).

## Orbit distance for ships without weapons, in meters.
const UNARMED_DISTANCE := 300.0
## The chase starts when the gap to the target grows beyond this many distances (or near the
## edge of weapon range, CHASE_REACH of it, if that comes first) and ends when it shrinks below
## CHASE_STOP distances.
const CHASE_START := 1.5
const CHASE_STOP := 1.2
const CHASE_REACH := 0.9
## The chase looks this far ahead at most, in seconds (see Autopilot.intercept_point()).
const MAX_LEAD_TIME := 6.0

## The live target, or null once it is gone.
var target: Ship:
	get:
		return _target.resolve() as Ship

## Gap to keep between the hulls while circling, in meters. 0 until set or until the first tick,
## when it becomes the weapon's best distance. Can be changed while the order runs.
var distance := 0.0
## Why this target, shown in the label (e.g. how auto-engage picked it). Empty: no note.
var note := ""

var _target: ObjectRef
var _orbit: OrbitOrder
var _chasing := false


func _init(p_target: Ship, p_distance := 0.0) -> void:
	_target = ObjectRef.to(p_target)
	distance = p_distance


func get_label() -> String:
	var label := "Attack %s" % Autopilot.name_of(target)
	if distance > 0.0:
		label += " at %.0f m" % distance
	return label if note.is_empty() else "%s (%s)" % [label, note]


func get_target() -> Node3D:
	return target


func get_attack_target() -> Ship:
	return target


## True while the target is too far and the ship is catching up with it.
func is_chasing() -> bool:
	return _chasing


func get_goal(ship: Ship) -> NavGoal:
	var enemy := target
	if enemy == null:
		return null
	var weapon := ship.get_weapon()
	if distance <= 0.0:
		distance = weapon.best_distance() if weapon != null else UNARMED_DISTANCE
	var reach := weapon.max_range if weapon != null else INF
	var chase_stop := distance * CHASE_STOP
	var chase_start := maxf(minf(distance * CHASE_START, reach * CHASE_REACH), chase_stop + 1.0)
	var gap := ship.global_position.distance_to(enemy.global_position) - ship.radius - enemy.radius
	if _chasing and gap < chase_stop:
		_chasing = false
	elif not _chasing and gap > chase_start:
		_chasing = true
		# A new orbit when the chase is over: it picks its plane from where the ship flies then.
		_orbit = null
	if _chasing:
		var point := Autopilot.intercept_point(ship.global_position, ship.top_speed(),
				enemy.global_position, enemy.velocity, MAX_LEAD_TIME)
		return NavGoal.new(point, false, enemy)
	if _orbit == null:
		_orbit = OrbitOrder.new(enemy, distance)
	_orbit.distance = distance
	return _orbit.get_goal(ship)


func is_complete(_ship: Ship) -> bool:
	var enemy := target
	return enemy == null or not enemy.is_in_space()
