class_name Weapon
extends Node

## An auto-firing turret, placed as a child of a Ship.
##
## Fires at the target of the ship's current order (AttackOrder) while it is in range,
## otherwise at the nearest hostile ship in range, so every armed ship defends itself.
## Armed hostiles come first: unarmed ones (drones) are shot only when no threat is in range.
## Escape pods are never picked (for now).
## Every shot hits with hit_chance_against() and deals `damage` (shield first, then armor).
## The chance depends on where the target is, so the distance a fight is fought at is a decision:
## - Distance: the full `hit_chance` within the best band (`best_from`..`best_to`, the gap between
##   hulls), less closer in (down to `close_share` of it right next to the target: big guns
##   cannot follow a target that close) and farther out (down to `far_share` at `max_range`),
##   nothing beyond `max_range`. Each ship class has its own band (ShipClass.WEAPON_BANDS).
## - Size: a target smaller than the shooter is harder to hit, by the square root of the ratio of
##   their radii, but never below MIN_SIZE_SHARE.
## The HUD shows the same number the weapon fires with.
## No line-of-sight check yet: shots pass through rocks.

signal fired(target: Ship, hit: bool)

## A target this much smaller than the shooter is no harder to hit (see above).
const MIN_SIZE_SHARE := 0.5

@export var enabled := true
## Max distance between hulls, in meters.
@export var max_range := 600.0
## Seconds between shots.
@export var fire_interval := 0.5
## Hit chance within the best band, against a target the shooter's size or bigger.
@export_range(0.0, 1.0) var hit_chance := 0.85
## The best band: gaps between hulls with the full hit chance, in meters.
@export var best_from := 250.0
@export var best_to := 450.0
## Share of the hit chance left right next to the target, and at max_range.
@export_range(0.0, 1.0) var close_share := 0.2
@export_range(0.0, 1.0) var far_share := 0.4
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
		if other == _ship or other.is_pod or not _ship.is_hostile_to(other) or not in_range(other):
			continue
		# Any armed ship in range beats every unarmed one.
		var score := _gap_to(other) + (0.0 if other.is_armed() else max_range * 2.0)
		if score < best_score:
			best_score = score
			best = other
	return best


func in_range(target: Variant) -> bool:
	return is_instance_valid(target) and target.is_in_space() and _gap_to(target) <= max_range


## Chance that a shot at `target` hits right now (see above), 0 when it is out of range.
func hit_chance_against(target: Ship) -> float:
	if not in_range(target):
		return 0.0
	return hit_chance_at(_gap_to(target), target)


## Chance that a shot at `target` would hit from `gap` meters between hulls: a forecast for a
## distance the ships are not at yet (0 beyond max_range).
func hit_chance_at(gap: float, target: Ship) -> float:
	return hit_chance * distance_share(gap) * size_share(target)


## Share of the hit chance left at `gap` meters between hulls.
func distance_share(gap: float) -> float:
	if gap > max_range:
		return 0.0
	if gap < best_from:
		return lerpf(close_share, 1.0, gap / best_from)
	if gap <= best_to:
		return 1.0
	return lerpf(1.0, far_share, (gap - best_to) / maxf(max_range - best_to, 1.0))


## Share of the hit chance left against a target of this size.
func size_share(target: Ship) -> float:
	return clampf(sqrt(target.radius / _ship.radius), MIN_SIZE_SHARE, 1.0)


## The gap to keep from a target to hit it best (the middle of the best band), in meters.
func best_distance() -> float:
	return (best_from + best_to) * 0.5


func _gap_to(target: Ship) -> float:
	return _ship.global_position.distance_to(target.global_position) - _ship.radius - target.radius


func _fire_at(target: Ship) -> void:
	var hit := _rng.randf() < hit_chance_against(target)
	CombatEffects.shot(_ship, _ship.get_muzzle_position(), target, hit, _rng)
	fired.emit(target, hit)
	if hit:
		target.note_hit_by(_ship)
		target.take_hit(damage, _ship)
