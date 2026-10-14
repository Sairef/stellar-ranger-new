class_name CombatRoutine
extends Node

## NPC fighter brain, placed as a child of a Ship: hunts hostile ships within detection range.
## Target score (lower is better): the distance, plus penalties for an unarmed target and for a
## crowded one, already attacked by `max_attackers` other fighters. So the nearest armed target
## that is not crowded comes first, then crowded armed ones, then unarmed ones (drones), and a
## crowded target is still better than none. This spreads a fleet's fire: a ship that flies
## ahead does not draw every enemy at once. Escape pods are never hunted (for now).
## While attacking it looks again every `retarget_interval` seconds and switches when another
## target scores more than `switch_margin` better (help arrived, or a much closer enemy), so it
## does not flip-flop between targets at similar distances.
## With nobody to fight it docks at `home` if it has one (station garrisons), otherwise circles
## `assault_target` if it has one (invaders besieging a station), otherwise waits.
## With a territory (`territory_radius` around `territory_center`: raiders on the asteroid field)
## it hunts only ships inside it, gives up a chase that leaves it, and with nobody to fight roams
## it, flying from one random spot in it to the next.
## leave_through() sends it out of the system: it stops hunting and jumps out through a gate.
## Gives orders through the same API the player uses.

const GROUP := &"fighters"

@export var detection_range := 3000.0
## Seconds between looks around for a new target while not attacking.
@export var scan_interval := 1.0
## A target attacked by this many other fighters is crowded: picked only when nothing better is
## in range.
@export var max_attackers := 3
## Seconds between second thoughts about the current target while attacking.
@export var retarget_interval := 4.0
## How much better (in meters of score) another target must be to switch to it.
@export var switch_margin := 300.0

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
## Center of the area the fighter keeps to (see above).
var territory_center := Vector3.ZERO
## Radius of that area in meters; INF for no territory: hunt anywhere within detection range.
var territory_radius := INF

## Orbit distance around the assault target, in meters.
const SIEGE_DISTANCE := 300.0
## Roaming spots lie within this share of the territory radius from its center.
const ROAM_SHARE := 0.6

var _ship: Ship
var _scan_in := 0.0
var _retarget_in := 0.0
var _home := ObjectRef.new()
var _assault := ObjectRef.new()
var _rng := RandomNumberGenerator.new()
var _leaving := false


func _ready() -> void:
	_ship = get_parent() as Ship
	_ship.add_to_group(GROUP)
	_rng.seed = hash(_ship.display_name)


## Stops hunting for good and jumps out of the system through `gate`.
func leave_through(gate: Gate) -> void:
	_leaving = true
	_ship.give_order(JumpOrder.new(gate))


func is_leaving() -> bool:
	return _leaving


func _physics_process(delta: float) -> void:
	if not _ship.is_in_space() or _leaving:
		return
	_scan_in -= delta
	_retarget_in -= delta
	var order := _ship.current_order
	if order != null and not order.is_interruptible():
		return
	if order is AttackOrder and not order.is_complete(_ship):
		if not _in_territory(order.get_attack_target()):
			_ship.give_order(null)  # The chase left the territory: back to it.
			return
		if _retarget_in <= 0.0:
			_retarget_in = retarget_interval
			_reconsider(order.get_attack_target())
		return
	if _scan_in > 0.0:
		return
	_scan_in = scan_interval
	var target := _best_target(_count_attackers())
	if target != null:
		_attack(target)
		return
	if order is AttackOrder:
		order = null  # Its target is gone.
	if order != null:
		return  # Already on the way home or besieging.
	if home != null:
		_ship.give_order(DockOrder.new(home))
	elif assault_target != null:
		_ship.give_order(OrbitOrder.new(assault_target, SIEGE_DISTANCE))
	elif territory_radius < INF:
		_ship.give_order(MoveToOrder.new(_roaming_spot()))


func _attack(target: Ship) -> void:
	_ship.give_order(AttackOrder.new(target))
	_retarget_in = retarget_interval


## Switches to the best target only if it beats the current one by more than `switch_margin`.
func _reconsider(current: Ship) -> void:
	var attackers := _count_attackers()
	var best := _best_target(attackers)
	if best != null and best != current \
			and _score(best, attackers) < _score(current, attackers) - switch_margin:
		_attack(best)


## The hostile ship within detection range with the lowest score, or null.
func _best_target(attackers: Dictionary[Ship, int]) -> Ship:
	var best: Ship = null
	var best_score := INF
	for node in get_tree().get_nodes_in_group(Autopilot.SHIP_GROUP):
		var other := node as Ship
		if other == _ship or other.is_pod or not _ship.is_hostile_to(other):
			continue
		if _ship.global_position.distance_to(other.global_position) > detection_range \
				or not _in_territory(other):
			continue
		var score := _score(other, attackers)
		if score < best_score:
			best_score = score
			best = other
	return best


## `target` is within the territory, or there is none.
func _in_territory(target: Node3D) -> bool:
	return territory_radius == INF or target == null \
			or territory_center.distance_to(target.global_position) <= territory_radius


## A random spot in the inner part of the territory, flattened like the system, clear of rocks.
func _roaming_spot() -> Vector3:
	var reach := territory_radius * ROAM_SHARE
	var offset := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.2, 0.2), _rng.randf_range(-1, 1))
	var spot := territory_center + offset.limit_length(1.0) * reach
	return Autopilot.push_out_of_obstacles(spot, _ship.radius,
			get_tree().get_nodes_in_group(Autopilot.OBSTACLE_GROUP))


## Lower is better: the distance, plus penalties for an unarmed and for a crowded target.
func _score(target: Ship, attackers: Dictionary[Ship, int]) -> float:
	var score := _ship.global_position.distance_to(target.global_position)
	# Any armed ship in range beats every unarmed one.
	if not target.is_armed():
		score += detection_range * 2.0
	# Others have it covered: any armed target in range that is not crowded comes first.
	if attackers.get(target, 0) >= max_attackers:
		score += detection_range
	return score


## How many other fighters out in space attack each ship right now.
func _count_attackers() -> Dictionary[Ship, int]:
	var counts: Dictionary[Ship, int] = {}
	for node in get_tree().get_nodes_in_group(GROUP):
		var fighter := node as Ship
		if fighter == _ship or not fighter.is_in_space() or fighter.current_order == null:
			continue
		var target := fighter.current_order.get_attack_target()
		if target != null:
			counts[target] = counts.get(target, 0) + 1
	return counts
