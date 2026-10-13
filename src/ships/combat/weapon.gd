class_name Weapon
extends Node

## An auto-firing turret, placed as a child of a Ship.
##
## Fires at the target of the ship's current order (AttackOrder) while it is in range,
## otherwise at the nearest hostile ship in range, so every armed ship defends itself.
## Armed hostiles come first: unarmed ones (drones) are shot only when no threat is in range.
## Every shot hits with `hit_chance` and deals `damage` (shield first, then armor).
## No line-of-sight check yet: shots pass through rocks.

signal fired(target: Ship, hit: bool)

@export var enabled := true
## Max distance between hulls, in meters.
@export var max_range := 600.0
## Seconds between shots.
@export var fire_interval := 0.5
@export_range(0.0, 1.0) var hit_chance := 0.75
@export var damage := 1.0

var _ship: Ship
var _cooldown := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_ship = get_parent() as Ship
	_rng.seed = hash(_ship.display_name) + 1
	# Ships that meet at the same moment should not fire in lockstep.
	_cooldown = _rng.randf_range(0.0, fire_interval)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not enabled or _ship == null or not _ship.is_in_space():
		return
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	var target := choose_target()
	if target == null:
		return  # Stay ready: fire as soon as a target shows up.
	_cooldown = fire_interval
	_fire_at(target)


## The ordered target if it is in range, otherwise the nearest armed hostile in range,
## otherwise the nearest unarmed one, or null.
func choose_target() -> Ship:
	if _ship.current_order != null:
		var ordered := _ship.current_order.get_attack_target()
		if in_range(ordered):
			return ordered
	var best: Ship = null
	var best_score := INF
	for node in get_tree().get_nodes_in_group(Autopilot.SHIP_GROUP):
		var other := node as Ship
		if other == _ship or not _ship.is_hostile_to(other) or not in_range(other):
			continue
		# Any armed ship in range beats every unarmed one.
		var score := _gap_to(other) + (0.0 if other.is_armed() else max_range * 2.0)
		if score < best_score:
			best_score = score
			best = other
	return best


func in_range(target: Variant) -> bool:
	return is_instance_valid(target) and target.is_in_space() and _gap_to(target) <= max_range


func _gap_to(target: Ship) -> float:
	return _ship.global_position.distance_to(target.global_position) - _ship.radius - target.radius


func _fire_at(target: Ship) -> void:
	var hit := _rng.randf() < hit_chance
	CombatEffects.shot(_ship, _ship.get_muzzle_position(), target, hit, _rng)
	fired.emit(target, hit)
	if hit:
		target.take_hit(damage, _ship)
