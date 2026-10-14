extends "res://tests/support/check_suite.gd"

## Headless combat checks. Run from the project folder (exit code 0 when everything passes):
##   godot --headless --path . --fixed-fps 60 res://tests/combat_checks.tscn
## Set the environment variable NAV_DIAG=1 to print every physical contact.

const ShipScene := preload("res://src/ships/ship.tscn")
## The weapon's chance at its best distance (85%) over a few dozen shots: allow for chance, but
## catch a broken hit roll.
const MIN_HIT_RATIO := 0.65
const MAX_HIT_RATIO := 0.98


func _ready() -> void:
	await _damage_layers()
	await _duel()
	await _out_of_range()
	await _range_grows_with_class()
	await _hit_chance_by_distance_and_size()
	await _distance_decides_small_against_large()
	await _distance_keys()
	await _intercept_point()
	await _chase()
	await _pirate_meets_armed_ship()
	await _fighters_spread_out()
	await _fighters_repick_when_help_arrives()
	await _fighter_switches_only_to_much_closer()
	await _combat_sandbox_scene()
	await _auto_engage()
	await _credits()
	await _modules()
	await _sounds()
	await _hostile_list()
	_finish()


# --- Scenarios -------------------------------------------------------------------------------

func _damage_layers() -> void:
	_begin("Shield first, then armor, then a wreck with loot")
	var ship := _spawn_ship("Target", Vector3.ZERO, Factions.NEUTRAL)
	var attacker := _spawn_ship("Attacker", Vector3(0, 0, -2000), Factions.PIRATE)
	attacker.get_weapon().enabled = false
	ship.cargo.add(Items.ORE, 10)
	var stats := {"wreck": null}
	ship.destroyed.connect(func(_ship: Ship, wreck: Wreck) -> void: stats.wreck = wreck)

	var shield_hits := int(ship.max_shield)
	var armor_hits := int(ship.max_armor)
	for i in shield_hits:
		ship.take_hit(1.0, attacker)
	_check(ship.shield == 0.0 and ship.armor == ship.max_armor,
			"%d hits empty the shield and leave the armor (%s)" % [shield_hits, ship.get_health_text()])
	for i in armor_hits - 1:
		ship.take_hit(1.0, attacker)
	_check(ship.armor == 1.0 and ship.is_in_space(),
			"%d more hits leave 1 armor (%s)" % [armor_hits - 1, ship.get_health_text()])
	ship.take_hit(1.0, attacker)
	_check(stats.wreck != null, "the %dth hit destroys the ship" % (shield_hits + armor_hits))
	await get_tree().process_frame
	_check(not is_instance_valid(ship), "the ship is gone")
	var wreck := stats.wreck as Wreck
	_check(is_instance_valid(wreck) and wreck.cargo.count(Items.ORE) == 10 and wreck.cargo.count(Items.LOOT_1) > 0,
			"it leaves a wreck with its cargo and loot (%s)" % wreck.cargo.describe())
	_check(wreck.display_name == "Wreck of Target", "the wreck is named after the ship (%s)" % wreck.display_name)
	await _end()


func _duel() -> void:
	_begin("Duel: an armed ship attacks an unarmed one")
	var target := _spawn_ship("Target", Vector3.ZERO, Factions.NEUTRAL)
	target.get_weapon().enabled = false
	var attacker := _spawn_ship("Attacker", Vector3(0, 0, -1200), Factions.PLAYER)
	var stats := {"shots": 0, "hits": 0, "destroyed": false}
	attacker.get_weapon().fired.connect(func(_target: Ship, hit: bool) -> void:
		stats.shots += 1
		if hit:
			stats.hits += 1)
	target.destroyed.connect(func(_ship: Ship, _wreck: Wreck) -> void: stats.destroyed = true)
	# The shield recharges during the fight (Ship.SHIELD_REGEN_FRACTION): that takes more hits.
	var full := target.max_shield + target.max_armor
	var shield := {"last": target.shield, "recharged": 0.0}
	var target_ref := ObjectRef.to(target)
	var watch := func() -> bool:
		var alive := target_ref.resolve() as Ship
		if alive != null:
			shield.recharged += maxf(0.0, alive.shield - shield.last)
			shield.last = alive.shield
		return stats.destroyed
	attacker.give_order(AttackOrder.new(target))

	var time: float = await _simulate(90.0, watch)
	var needed := roundi(full + shield.recharged)
	_check(time > 0.0, "the target was destroyed in %.1f s" % time)
	_check(stats.hits == needed, "it took exactly %d hits: shield + armor + %.0f recharged (%d)"
			% [needed, shield.recharged, stats.hits])
	var ratio := float(stats.hits) / maxf(1.0, stats.shots)
	_check(ratio >= MIN_HIT_RATIO and ratio <= MAX_HIT_RATIO,
			"about %.0f%% of shots hit, as at the best distance (%d of %d, %.0f%%)" % [
			attacker.get_weapon().hit_chance * 100.0, stats.hits, stats.shots, ratio * 100.0])
	await get_tree().physics_frame
	_check(attacker.current_order == null, "the attack order ended with the target")
	_check(attacker.collision_ticks == 0, "no physical contacts (%d ticks)" % attacker.collision_ticks)
	await _end()


func _out_of_range() -> void:
	_begin("Hostile ships out of weapon range do not shoot")
	var a := _spawn_ship("A", Vector3.ZERO, Factions.PLAYER)
	var b := _spawn_ship("B", Vector3(0, 0, -2000), Factions.PIRATE)
	var stats := {"shots": 0}
	for ship in [a, b]:
		ship.get_weapon().fired.connect(func(_target: Ship, _hit: bool) -> void: stats.shots += 1)
	await _simulate(5.0, func() -> bool: return false)
	_check(stats.shots == 0, "no shots at 2 km (%d)" % stats.shots)
	await _end()


## Big ships are too slow to chase anyone, so their weapons reach farther (ShipClass).
func _range_grows_with_class() -> void:
	_begin("Weapon range grows with the ship class")
	var ranges: Array[float] = []
	var ships: Array[Ship] = []
	for size: ShipClass.Size in [ShipClass.Size.SMALL, ShipClass.Size.MEDIUM, ShipClass.Size.LARGE]:
		var ship := _spawn_ship(ShipClass.name_of(size), Vector3(1000.0 * ships.size(), 0, 0),
				Factions.PLAYER, size)
		ships.append(ship)
		ranges.append(ship.get_weapon().max_range)
	_check(ranges[0] < ranges[1] and ranges[1] < ranges[2], "small < medium < large %s" % str(ranges))
	var target := _spawn_ship("Target", Vector3.ZERO, Factions.PIRATE)
	target.get_weapon().enabled = false
	var small := ships[0]
	var large := ships[2]
	var gap := (ranges[0] + ranges[2]) * 0.5
	small.global_position = Vector3(0, 0, -(gap + small.radius + target.radius))
	large.global_position = Vector3(0, 0, gap + large.radius + target.radius)
	_check(large.get_weapon().choose_target() == target and small.get_weapon().choose_target() == null,
			"at %.0f m the large ship fires and the small one does not" % gap)
	ships[0].set_ship_class(ShipClass.Size.MEDIUM)
	_check(ships[0].get_weapon().max_range == ranges[1], "an upgrade brings the range of the new class (%.0f)"
			% ships[0].get_weapon().max_range)
	await _end()


func _intercept_point() -> void:
	_begin("Intercept point: where a chase meets its target")
	var target := Vector3(0, 0, -1000)
	var crossing := Autopilot.intercept_point(Vector3.ZERO, 100.0, target, Vector3(60, 0, 0), 60.0)
	var time := crossing.length() / 100.0
	_check(crossing.x > 0.0 and absf(crossing.distance_to(target + Vector3(60, 0, 0) * time)) < 1.0,
			"a crossing target: ahead of it, where both arrive at once (%s)" % crossing)
	var coming := Autopilot.intercept_point(Vector3.ZERO, 100.0, target, Vector3(0, 0, 100), 60.0)
	_check(coming.distance_to(Vector3(0, 0, -500)) < 1.0, "a target as fast, coming at us: halfway (%s)" % coming)
	var fleeing := Autopilot.intercept_point(Vector3.ZERO, 100.0, target, Vector3(0, 0, -100), 60.0)
	_check(fleeing.distance_to(Vector3(0, 0, -2000)) < 1.0,
			"a target as fast, flying away: where it will be by the time we get where it is (%s)" % fleeing)
	var far := Autopilot.intercept_point(Vector3.ZERO, 100.0, target, Vector3(0, 0, -100), 5.0)
	_check(far.distance_to(Vector3(0, 0, -1500)) < 1.0, "never more than max_time ahead (%s)" % far)
	await _end()


## How well a weapon hits depends on where the target is (Weapon.hit_chance_against()): each
## class hits best at its own distance, and big guns hit small ships worse. The HUD shows the same
## numbers the weapons fire with.
func _hit_chance_by_distance_and_size() -> void:
	_begin("Hit chance by distance and target size")
	var small := _spawn_ship("Small", Vector3.ZERO, Factions.PLAYER, ShipClass.Size.SMALL)
	var large := _spawn_ship("Large", Vector3(0, 0, -2000), Factions.PIRATE, ShipClass.Size.LARGE)
	var other_small := _spawn_ship("Other small", Vector3(2000, 0, 0), Factions.PIRATE, ShipClass.Size.SMALL)
	var mine := small.get_weapon()
	var theirs := large.get_weapon()
	var at_gap := func(gap: float) -> void:
		large.global_position = Vector3(0, 0, -(gap + small.radius + large.radius))
	at_gap.call(100.0)
	var close := [mine.hit_chance_against(large), theirs.hit_chance_against(small)]
	at_gap.call(400.0)
	var far := [mine.hit_chance_against(large), theirs.hit_chance_against(small)]
	at_gap.call(600.0)
	var beyond := [mine.hit_chance_against(large), theirs.hit_chance_against(small)]
	print("    small on large / large on small: at 100 m %s, at 400 m %s, at 600 m %s" % [close, far, beyond])
	_check(is_equal_approx(close[0], mine.hit_chance), "close up the small ship hits a large one fully (%.2f)" % close[0])
	_check(close[1] < 0.25, "the large one hardly hits it there (%.2f)" % close[1])
	_check(far[0] < close[0] * 0.6 and far[1] > close[1] * 2.0,
			"at 400 m the small ship hits worse and the large one much better (%s)" % str(far))
	_check(beyond[0] == 0.0 and beyond[1] > 0.0, "at 600 m only the large one reaches (%s)" % str(beyond))
	_check(is_equal_approx(theirs.size_share(small), Weapon.MIN_SIZE_SHARE) and mine.size_share(large) == 1.0,
			"big guns hit a small ship worse, small guns a big ship fully")
	other_small.global_position = Vector3(mine.best_distance() + 2.0 * small.radius, 0, 0)
	_check(is_equal_approx(mine.hit_chance_against(other_small), mine.hit_chance),
			"a ship of the same class at the best distance: the full chance (%.2f)" % mine.hit_chance_against(other_small))
	at_gap.call(150.0)
	var odds := Hud.odds_text(small, large)
	var expected := "You hit %d%%   It hits you %d%%" % [roundi(mine.hit_chance_against(large) * 100.0),
			roundi(theirs.hit_chance_against(small) * 100.0)]
	_check(odds == expected, "the HUD shows the numbers the weapons fire with (%s)" % odds)
	await _end()


## The point of distance: a small ship beats a large one if it gets close and stays there (its
## default), and loses if it keeps away.
func _distance_decides_small_against_large() -> void:
	await _small_against_large(0.0, "Large")
	await _small_against_large(380.0, "Small")


## A small ship attacks a large one keeping `keep` meters (0: its best distance), the large one
## fights back from its best distance; `loser` must lose.
func _small_against_large(keep: float, loser: String) -> void:
	var how := "at its best distance" if keep == 0.0 else "keeping %.0f m" % keep
	_begin("Distance decides: a small ship attacks a large one %s" % how)
	var small := _spawn_ship("Small", Vector3.ZERO, Factions.PLAYER, ShipClass.Size.SMALL)
	var large := _spawn_ship("Large", Vector3(300, 0, -1500), Factions.PIRATE, ShipClass.Size.LARGE)
	var stats := {"lost": "", "gaps": []}
	for ship in [small, large]:
		ship.destroyed.connect(func(lost: Ship, _wreck: Wreck) -> void: stats.lost = lost.display_name)
	small.give_order(AttackOrder.new(large, keep))
	large.give_order(AttackOrder.new(small))
	var small_ref := ObjectRef.to(small)
	var large_ref := ObjectRef.to(large)
	var time: float = await _simulate(400.0, func() -> bool:
		var a := small_ref.resolve() as Ship
		var b := large_ref.resolve() as Ship
		if a != null and b != null:
			stats.gaps.append(a.global_position.distance_to(b.global_position) - a.radius - b.radius)
		return not stats.lost.is_empty())
	var gaps: Array = stats.gaps
	gaps.sort()
	var median: float = gaps[gaps.size() / 2] if not gaps.is_empty() else 0.0
	_check(time > 0.0 and stats.lost == loser, "the %s ship lost in %.0f s (median gap %.0f m)"
			% [stats.lost.to_lower(), time, median])
	await _end()


## Z / X: the player fights closer or farther. The attack under way changes, later attacks keep
## the distance, and a new ship starts from its weapon's best distance again.
func _distance_keys() -> void:
	_begin("Distance keys: Z closer, X farther")
	var sandbox := load("res://scenes/sandbox/combat_sandbox.tscn").instantiate() as CombatSandbox
	_world.add_child(sandbox)
	var controller := sandbox.controller
	controller.auto_engage = false
	var player := controller.ship
	var weapon := player.get_weapon()
	var pirate := sandbox.get_node("Ships/Pirate1") as Ship
	pirate.get_weapon().enabled = false
	controller.select(pirate)
	controller.attack_selected()
	var order := player.current_order as AttackOrder
	_check(order != null and order.distance == weapon.best_distance(),
			"an attack starts at the weapon's best distance (%.0f m)" % weapon.best_distance())
	var key := InputEventKey.new()
	key.keycode = KEY_X
	key.pressed = true
	get_viewport().push_input(key, true)
	_check(order.distance == weapon.best_distance() + PlayerController.DISTANCE_STEP,
			"X: %.0f m farther (%s)" % [PlayerController.DISTANCE_STEP, order.get_label()])
	for i in 20:
		controller.change_distance(-PlayerController.DISTANCE_STEP)
	_check(order.distance == PlayerController.MIN_DISTANCE, "Z never goes closer than %.0f m (%.0f)"
			% [PlayerController.MIN_DISTANCE, order.distance])
	for i in 20:
		controller.change_distance(PlayerController.DISTANCE_STEP)
	var farthest := weapon.max_range * PlayerController.MAX_REACH
	_check(is_equal_approx(order.distance, farthest), "nor farther than %.0f m (%.0f)" % [farthest, order.distance])
	controller.change_distance(-200.0)
	controller.stop()
	controller.attack_selected()
	var next := player.current_order as AttackOrder
	_check(next != order and is_equal_approx(next.distance, farthest - 200.0),
			"the next attack keeps the chosen distance (%.0f m)" % next.distance)
	controller.orbit_selected()
	var orbit := player.current_order as OrbitOrder
	var before := orbit.distance
	controller.change_distance(PlayerController.DISTANCE_STEP)
	_check(orbit.distance == before + PlayerController.DISTANCE_STEP, "an orbit changes too (%.0f m)" % orbit.distance)
	controller.ship = null
	controller.ship = player
	_check(controller.attack_distance() == weapon.best_distance(),
			"a new ship to fly starts from its weapon's best distance again")
	await _end()


## The case from a playtest: a large ship goes after a large enemy that fights a small ship and
## flies around with it. The attacker chases it (intercept) and, once there, stays in range.
func _chase() -> void:
	_begin("Chase: a large ship keeps a large enemy in range while it fights someone else")
	var enemy := _spawn_ship("Enemy", Vector3.ZERO, Factions.PIRATE, ShipClass.Size.LARGE)
	var other := _spawn_ship("Other", Vector3(400, 0, 200), Factions.NEUTRAL, ShipClass.Size.SMALL)
	var hunter := _spawn_ship("Hunter", Vector3(0, 0, -2000), Factions.PLAYER, ShipClass.Size.LARGE)
	for ship in [enemy, other, hunter]:
		ship.get_weapon().damage = 0.0
	enemy.give_order(AttackOrder.new(other))
	other.give_order(AttackOrder.new(enemy))
	var order := AttackOrder.new(enemy)
	hunter.give_order(order)
	var stats := {"first": -1.0, "time": 0.0, "in_range": 0.0, "chased": false}
	var step := 1.0 / Engine.physics_ticks_per_second
	await _simulate(90.0, func() -> bool:
		stats.time += step
		stats.chased = stats.chased or order.is_chasing()
		if hunter.get_weapon().in_range(enemy):
			if stats.first < 0.0:
				stats.first = stats.time
			stats.in_range += step
		return false)
	var after: float = 90.0 - stats.first
	print("    first in range at %.1f s, then in range %.1f of %.1f s" % [stats.first, stats.in_range, after])
	_check(stats.chased, "the hunter chased the enemy")
	_check(stats.first > 0.0 and stats.first < 30.0, "it got in range in %.1f s" % stats.first)
	_check(stats.in_range > after * 0.95, "then kept it in range %.0f%% of the time"
			% (stats.in_range / maxf(after, 0.001) * 100.0))
	_check(hunter.collision_ticks == 0, "no physical contacts (%d ticks)" % hunter.collision_ticks)
	await _end()


## A pirate hunts an armed ship that has no orders: it shoots back on its own.
func _pirate_meets_armed_ship() -> void:
	_begin("Pirate attacks an armed ship without orders")
	var trader := _spawn_ship("Trader", Vector3.ZERO, Factions.NEUTRAL)
	var pirate := _spawn_ship("Pirate", Vector3(0, 0, -1500), Factions.PIRATE)
	pirate.add_child(CombatRoutine.new())
	var stats := {"pirate_shots": 0, "trader_shots": 0, "losses": 0, "contacts": 0}
	pirate.get_weapon().fired.connect(func(_t: Ship, _h: bool) -> void: stats.pirate_shots += 1)
	trader.get_weapon().fired.connect(func(_t: Ship, _h: bool) -> void: stats.trader_shots += 1)
	for ship in [trader, pirate]:
		ship.destroyed.connect(func(lost: Ship, _wreck: Wreck) -> void:
			stats.losses += 1
			stats.contacts += lost.collision_ticks)

	var time: float = await _simulate(120.0, func() -> bool: return stats.losses > 0)
	_check(stats.pirate_shots > 0, "the pirate attacked (%d shots)" % stats.pirate_shots)
	_check(stats.trader_shots > 0, "it fired back without orders (%d shots)" % stats.trader_shots)
	_check(time > 0.0 and stats.losses == 1, "one of them was destroyed in %.1f s" % time)
	for ship in [trader, pirate]:
		if is_instance_valid(ship):
			stats.contacts += ship.collision_ticks
	_check(stats.contacts == 0, "no physical contacts (%d ticks)" % stats.contacts)
	await _end()


## Six pirates and two armed ships, one behind the other: without a cap every pirate would pile
## onto the nearer one. They split between the two, at most max_attackers on each.
func _fighters_spread_out() -> void:
	_begin("Fighters spread their fire: at most max_attackers on one target")
	var targets: Array[Ship] = [_spawn_harmless_target("Near", Vector3.ZERO),
			_spawn_harmless_target("Behind", Vector3(0, 0, 400))]
	var limit := 0
	for i in 6:
		var fighter := _spawn_fighter("Pirate %d" % (i + 1), Vector3(150 * i - 375, 0, -1500))
		limit = _routine_of(fighter).max_attackers
	var stats := {"most": 0}
	await _simulate(10.0, func() -> bool:
		stats.most = maxi(stats.most, _attack_counts(targets).max())
		return false)
	var counts := _attack_counts(targets)
	_check(stats.most <= limit, "never more than %d pirates on one target (%d)" % [limit, stats.most])
	_check(counts.min() > 0, "both targets are attacked %s" % str(counts))
	await _end()


## Six pirates on the only target in sight. When a second armed ship shows up next to them,
## some switch to it at their next second thought, leaving at most max_attackers on each.
func _fighters_repick_when_help_arrives() -> void:
	_begin("Fighters re-pick their targets when help arrives")
	var targets: Array[Ship] = [_spawn_harmless_target("Lead", Vector3.ZERO)]
	var routine: CombatRoutine = null
	for i in 6:
		routine = _routine_of(_spawn_fighter("Pirate %d" % (i + 1), Vector3(150 * i - 375, 0, -1500)))
	var limit := routine.max_attackers
	var wait := routine.retarget_interval + routine.scan_interval
	var time: float = await _simulate(3.0, func() -> bool: return _attack_counts(targets)[0] == 6)
	_check(time > 0.0, "all six attack the only target (%.1f s)" % time)

	targets.append(_spawn_harmless_target("Help", Vector3(600, 0, -900)))
	time = await _simulate(wait, func() -> bool:
		var counts := _attack_counts(targets)
		return counts.max() <= limit and counts.min() > 0)
	_check(time > 0.0, "within %.0f s some switch to the newcomer: %s (%.1f s)"
			% [wait, str(_attack_counts(targets)), time])
	var stats := {"most": 0}
	await _simulate(routine.retarget_interval * 2.0, func() -> bool:
		stats.most = maxi(stats.most, _attack_counts(targets).max())
		return false)
	_check(stats.most <= limit and _attack_counts(targets).min() > 0,
			"and they stay spread %s" % str(_attack_counts(targets)))
	await _end()


## A pirate attacking a far target switches to an armed ship that shows up much closer (by more
## than switch_margin), but not to one only a little closer: fighters do not flip-flop.
func _fighter_switches_only_to_much_closer() -> void:
	_begin("A fighter switches only to a much closer target")
	var far := _spawn_harmless_target("Far", Vector3(0, 0, -2800))
	var pirate := _spawn_fighter("Pirate", Vector3.ZERO)
	var routine := _routine_of(pirate)
	var wait := routine.retarget_interval + routine.scan_interval
	var time: float = await _simulate(2.0, func() -> bool: return _target_of(pirate) == far)
	_check(time > 0.0, "the pirate attacks the only target in range (%.1f s)" % time)

	# Off to the side of the pirate's way, so it does not fly into the newcomers.
	var side := Vector3(150, 0, 0)
	var to_pirate := (pirate.global_position - far.global_position).normalized()
	var slightly := _spawn_harmless_target("Slightly closer", far.global_position + to_pirate * 150.0 + side)
	var gain := _distance(pirate, far) - _distance(pirate, slightly)
	time = await _simulate(wait, func() -> bool: return _target_of(pirate) != far)
	_check(time < 0.0, "it keeps its target when another is only %.0f m closer (margin %.0f m)"
			% [gain, routine.switch_margin])

	var much := _spawn_harmless_target("Much closer", pirate.global_position - to_pirate * 800.0 + side)
	gain = _distance(pirate, far) - _distance(pirate, much)
	time = await _simulate(wait, func() -> bool: return _target_of(pirate) == much)
	_check(time > 0.0, "it switches to one %.0f m closer (%.1f s)" % [gain, time])
	await _end()


## The combat test bed scene runs, a fight happens, and the debug buttons work.
func _combat_sandbox_scene() -> void:
	_begin("Combat sandbox scene")
	var sandbox := load("res://scenes/sandbox/combat_sandbox.tscn").instantiate() as CombatSandbox
	_world.add_child(sandbox)
	# Track losses through signals: a lambda must not hold a ship that may be freed.
	var stats := {"losses": 0}
	for ship: Ship in [sandbox.controller.ship, sandbox.get_node("Ships/Pirate1")]:
		ship.destroyed.connect(func(_ship: Ship, _wreck: Wreck) -> void: stats.losses += 1)
	var time: float = await _simulate(120.0, func() -> bool: return stats.losses > 0)
	_check(time > 0.0, "the player and the pirate fought it out in %.1f s" % time)

	sandbox.respawn_player()
	_check(sandbox.controller.has_ship(), "the player has a ship after Respawn player")
	var fighters := get_tree().get_node_count_in_group(CombatRoutine.GROUP)
	sandbox.spawn_pirate()
	_check(get_tree().get_node_count_in_group(CombatRoutine.GROUP) == fighters + 1, "Spawn pirate adds a pirate")
	await _simulate(2.0, func() -> bool: return false)
	await _end()


## An idle player ship attacks hostiles its weapon opens fire at, but never overrides an order.
func _auto_engage() -> void:
	_begin("Auto-engage: the idle player ship attacks new hostiles")
	var sandbox := load("res://scenes/sandbox/combat_sandbox.tscn").instantiate() as CombatSandbox
	_world.add_child(sandbox)
	var controller := sandbox.controller
	var player := controller.ship
	# Unarmed pirates: the player must survive the whole scenario.
	var pirate := sandbox.get_node("Ships/Pirate1") as Ship
	pirate.get_weapon().enabled = false
	var stats := {"kills": 0}
	pirate.destroyed.connect(func(_ship: Ship, _wreck: Wreck) -> void: stats.kills += 1)
	var first := ObjectRef.to(pirate)
	var time: float = await _simulate(60.0, func() -> bool: return _attacking(controller) == "Pirate 1")
	_check(time > 0.0, "the idle ship attacks the pirate that came into range (%.1f s)" % time)
	_check(Autopilot.name_of(controller.selected) == "Pirate 1", "and selects it, as nothing was selected")
	_check(player.get_order_label().ends_with("(%s)" % PlayerController.AUTO_ENGAGE_NOTE),
			"the order tells why it picked that target (%s)" % player.get_order_label())

	player.give_order(MoveToOrder.new(player.global_position + Vector3(400, 0, 0)))
	await _simulate(2.0, func() -> bool: return false)
	_check(player.current_order is MoveToOrder,
			"an order from the player is never overridden (%s)" % player.get_order_label())

	controller.stop()
	await _simulate(3.0, func() -> bool: return false)
	_check(player.current_order == null and stats.kills == 0
			and Autopilot.name_of(player.get_weapon().choose_target()) == "Pirate 1",
			"after Stop it keeps firing at the pirate but does not go after it (%s)" % player.get_order_label())

	var second := sandbox.spawn_pirate()
	second.get_weapon().enabled = false
	var second_name := second.display_name
	player.get_weapon().damage = 5.0
	controller.select(first.resolve())
	controller.attack_selected()
	_check(player.get_order_label() == "Attack Pirate 1 at %.0f m" % controller.attack_distance(),
			"an attack the player ordered has no note, only the distance (%s)" % player.get_order_label())
	time = await _simulate(60.0, func() -> bool: return stats.kills > 0)
	_check(time > 0.0, "the player kills the pirate it was ordered to attack (%.1f s)" % time)
	time = await _simulate(30.0, func() -> bool: return _attacking(controller) == second_name)
	_check(time >= 0.0, "then goes after the next hostile its weapon fires at: %s (%.1f s)" % [second_name, time])
	await _end()


## Bounties (placeholder): every ship that hit a destroyed enemy gets the full bounty for its
## class, whoever finished it off. Missing earns nothing, and neither does a kill the player took
## no part in or shooting down a neutral.
func _credits() -> void:
	_begin("Bounties: everyone who hit a destroyed enemy, by its class")
	var sandbox := load("res://scenes/sandbox/combat_sandbox.tscn").instantiate() as CombatSandbox
	_world.add_child(sandbox)
	var controller := sandbox.controller
	controller.auto_engage = false
	var player := controller.ship
	var pirate := sandbox.get_node("Ships/Pirate1") as Ship
	pirate.get_weapon().enabled = false
	pirate.global_position = player.global_position + Vector3(0, 0, -300)
	var ally := _spawn_ship("Ally", player.global_position + Vector3(200, 0, -100), Factions.NEUTRAL)
	var shares := {"You": 0, "Ally": 0}
	player.helped_destroy.connect(func(_victim: Ship) -> void: shares["You"] += 1)
	ally.helped_destroy.connect(func(_victim: Ship) -> void: shares["Ally"] += 1)
	var pirate_class := pirate.ship_class
	var target := ObjectRef.to(pirate)
	var time: float = await _simulate(60.0, func() -> bool: return target.resolve() == null)
	_check(time > 0.0, "the player and an ally shoot the pirate down (%.1f s)" % time)
	_check(shares["You"] == 1 and shares["Ally"] == 1,
			"both of them hit it and both get the bounty (%s)" % shares)
	var bounty: int = Bounties.BY_CLASS[pirate_class]
	_check(controller.credits == bounty, "the player earned %d cr (%d)" % [bounty, controller.credits])

	var far := _spawn_ship("Far pirate", player.global_position + Vector3(0, 0, 5000), Factions.PIRATE)
	far.take_hit(100.0, null)
	_check(controller.credits == bounty, "a kill the player took no part in earns nothing (%d)"
			% controller.credits)

	var missed := _spawn_ship("Missed pirate", player.global_position + Vector3(0, 0, -250), Factions.PIRATE,
			ShipClass.Size.SMALL)
	missed.get_weapon().enabled = false
	player.get_weapon().hit_chance = 0.0
	var shots := {"count": 0}
	player.get_weapon().fired.connect(func(_target: Ship, _hit: bool) -> void: shots.count += 1)
	target = ObjectRef.to(missed)
	time = await _simulate(60.0, func() -> bool: return target.resolve() == null)
	_check(time > 0.0 and shots.count > 0 and shares["You"] == 1 and controller.credits == bounty,
			"shooting and missing earns nothing (%d shots, %d cr)" % [shots.count, controller.credits])

	player.get_weapon().hit_chance = 1.0
	player.get_weapon().damage = 10.0
	ally.get_weapon().enabled = false
	var small := _spawn_ship("Small pirate", player.global_position + Vector3(0, 0, -250), Factions.PIRATE,
			ShipClass.Size.SMALL)
	small.get_weapon().enabled = false
	target = ObjectRef.to(small)
	time = await _simulate(30.0, func() -> bool: return target.resolve() == null)
	var small_bounty: int = Bounties.BY_CLASS[ShipClass.Size.SMALL]
	_check(time > 0.0 and controller.credits == bounty + small_bounty,
			"a small pirate pays %d cr (%d)" % [small_bounty, controller.credits])

	var bystander := _spawn_ship("Bystander", player.global_position + Vector3(0, 0, 200), Factions.NEUTRAL)
	bystander.get_weapon().enabled = false
	controller.select(bystander)
	controller.attack_selected()
	target = ObjectRef.to(bystander)
	time = await _simulate(30.0, func() -> bool: return target.resolve() == null)
	_check(time > 0.0 and shares["You"] == 3 and controller.credits == bounty + small_bounty,
			"shooting down a neutral earns nothing (%d credits)" % controller.credits)
	await _end()


## Modules run on the ship's energy: the afterburner speeds the ship up for a while, the shield
## booster restores part of the shield at once; they refuse while busy, cooling down or short of
## energy, and the energy recharges by itself.
func _modules() -> void:
	_begin("Modules: the afterburner and the shield booster, on the ship's energy")
	var ship := _spawn_ship("Pilot", Vector3.ZERO, Factions.PLAYER, ShipClass.Size.MEDIUM)
	var burner := Afterburner.new()
	var booster := ShieldBooster.new()
	ship.add_child(burner)
	ship.add_child(booster)
	await get_tree().physics_frame
	_check(ship.energy == ship.max_energy and ship.get_modules() == [burner, booster],
			"full energy, two modules in the order fitted")
	ship.give_order(MoveToOrder.new(Vector3(0, 0, -8000)))
	await _simulate(20.0, func() -> bool: return ship.speed >= ship.max_speed - 0.5)
	_check(ship.activate_module(0) and burner.is_active(), "the afterburner switches on")
	_check(is_equal_approx(ship.energy, ship.max_energy - burner.energy_cost),
			"it takes %.0f energy" % burner.energy_cost)
	var boosted: float = await _simulate(burner.duration,
			func() -> bool: return ship.speed > ship.max_speed * 1.3)
	_check(boosted > 0.0, "the ship flies faster than its normal top speed (%.0f of %.0f m/s after %.1f s)"
			% [ship.speed, ship.max_speed, boosted])
	_check(not ship.activate_module(0), "it cannot be switched on again while active")
	var over: float = await _simulate(burner.duration, func() -> bool: return not burner.is_active())
	_check(over > 0.0 and ship.thrust_boost == 1.0, "after %.0f s it is over" % burner.duration)
	_check(not burner.can_activate() and burner.get_state_text().begins_with("cooldown"),
			"then it cools down (%s)" % burner.get_state_text())
	var slowed: float = await _simulate(10.0, func() -> bool: return ship.speed <= ship.max_speed + 0.5)
	_check(slowed > 0.0, "and the ship slows down to its normal top speed (%.1f s)" % slowed)

	_check(not ship.activate_module(1) and booster.get_state_text() == "not needed",
			"the shield booster refuses a full shield")
	ship.shield = 10.0
	_check(ship.activate_module(1) and is_equal_approx(ship.shield, 10.0 + ship.max_shield * booster.restore),
			"it restores %.0f%% of the shield at once (%.1f)" % [booster.restore * 100.0, ship.shield])
	await _wait(booster.cooldown + 0.1)
	ship.energy = 0.0
	_check(not ship.activate_module(1) and booster.get_state_text().begins_with("needs"),
			"without energy it refuses (%s)" % booster.get_state_text())
	var recharged: float = await _simulate(30.0, func() -> bool: return ship.energy >= booster.energy_cost)
	var expected := booster.energy_cost / ship.energy_recharge
	_check(absf(recharged - expected) < 0.2,
			"the energy recharges by itself (%.0f in %.1f s)" % [booster.energy_cost, recharged])
	await _end()


## Placeholder sounds: every one is synthesized in code, sounds far from the camera are not
## played, and no more than Sfx.MAX_VOICES play at once.
func _sounds() -> void:
	_begin("Sounds: synthesized, only near the camera, capped")
	var names: Array[StringName] = [&"shot", &"hit_shield", &"hit_armor", &"explosion", &"afterburner",
			&"shield_boost", &"alert", &"reward", &"denied"]
	var empty: Array[StringName] = []
	for sound in names:
		var stream := Sfx.stream(sound)
		if stream.get_length() < 0.1 or stream.data.size() < 1000:
			empty.append(sound)
	_check(empty.is_empty(), "every sound has a body (%d sounds; empty: %s)" % [names.size(), empty])
	var camera := Camera3D.new()
	_world.add_child(camera)
	camera.current = true
	Sfx.play_at(_world, &"shot", Vector3(0, 0, -Sfx.MAX_DISTANCE * 2.0))
	_check(get_tree().get_node_count_in_group(Sfx.VOICES_GROUP) == 0, "too far from the camera: silence")
	for i in Sfx.MAX_VOICES + 10:
		Sfx.play_at(_world, &"shot", Vector3(0, 0, -100))
	_check(get_tree().get_node_count_in_group(Sfx.VOICES_GROUP) == Sfx.MAX_VOICES,
			"at most %d at once" % Sfx.MAX_VOICES)
	var done: float = await _simulate(3.0, func() -> bool:
		return get_tree().get_node_count_in_group(Sfx.VOICES_GROUP) == 0)
	_check(done > 0.0, "they are gone once played (%.1f s)" % done)
	await _end()


## The list of hostile ships shows all of them however many, nearest first, and whom each one
## attacks; a click on a row selects that ship.
func _hostile_list() -> void:
	_begin("Hostile list: every hostile ship, nearest first")
	var sandbox := load("res://scenes/sandbox/combat_sandbox.tscn").instantiate() as CombatSandbox
	_world.add_child(sandbox)
	var controller := sandbox.controller
	controller.auto_engage = false
	var player := controller.ship
	for i in 11:
		var raider := _spawn_ship("Raider %d" % (i + 1),
				player.global_position + Vector3(150 * i - 750, 0, 2000 + 100 * i), Factions.PIRATE)
		raider.get_weapon().enabled = false
	var list: HostileList = null
	for node in sandbox.find_children("*", "", true, false):
		if node is HostileList:
			list = node
	list.refresh()
	var rows := list.rows()
	var hostiles := list.hostiles()
	_check(rows.size() == 12 and hostiles.size() == 12, "all 12 hostiles are listed (%d rows)" % rows.size())
	var nearest_first := true
	for i in range(1, hostiles.size()):
		var from := player.global_position
		nearest_first = nearest_first \
				and from.distance_to(hostiles[i - 1].global_position) <= from.distance_to(hostiles[i].global_position)
	_check(nearest_first, "nearest first")
	var ninth := hostiles[8]
	rows[8].select(0)
	_check(controller.selected == ninth, "a click on the ninth row selects it (%s)"
			% Autopilot.name_of(controller.selected))

	var attacker := ObjectRef.to(sandbox.get_node("Ships/Pirate1"))
	var time: float = await _simulate(60.0, func() -> bool:
		list.refresh()
		for row in list.rows():
			if row.get_text(0) == "Pirate 1" and row.get_text(HostileList.COLUMN_ATTACKING) == "YOU":
				return true
		return false)
	_check(time > 0.0 and attacker.resolve() != null, "the pirate attacking the player says YOU (%.1f s)" % time)
	_check(controller.selected == ninth, "the selection stays on its row while the list refreshes")
	await _end()


# --- Helpers ---------------------------------------------------------------------------------

func _spawn_ship(ship_name: String, position: Vector3, faction: StringName,
		size := ShipClass.Size.CUSTOM) -> Ship:
	var ship := ShipScene.instantiate() as Ship
	ship.display_name = ship_name
	ship.faction = faction
	ship.ship_class = size
	ship.enter_space(_world, Transform3D(Basis.IDENTITY, position))
	if OS.get_environment("NAV_DIAG") != "":
		ship.collided.connect(func(collider: Object) -> void:
			print("    contact: %s hit %s | %s | speed %.1f" % [ship_name,
					Autopilot.name_of(collider), ship.get_order_label(), ship.speed]))
	return ship


## A pirate fighter (with a CombatRoutine) whose weapon is off, so target picking scenarios run
## without losses.
func _spawn_fighter(ship_name: String, position: Vector3) -> Ship:
	var ship := _spawn_ship(ship_name, position, Factions.PIRATE)
	ship.get_weapon().enabled = false
	ship.add_child(CombatRoutine.new())
	return ship


## A ship pirates hunt that shoots back harmlessly: its weapon is on, so it counts as armed.
func _spawn_harmless_target(ship_name: String, position: Vector3) -> Ship:
	var ship := _spawn_ship(ship_name, position, Factions.NEUTRAL)
	ship.get_weapon().damage = 0.0
	return ship


func _routine_of(ship: Ship) -> CombatRoutine:
	for child in ship.get_children():
		if child is CombatRoutine:
			return child
	return null


## The ship `ship` is attacking, or null.
func _target_of(ship: Ship) -> Ship:
	return ship.current_order.get_attack_target() if ship.current_order != null else null


## How many fighters attack each of `targets`, in the same order.
func _attack_counts(targets: Array[Ship]) -> Array[int]:
	var counts: Array[int] = []
	for target in targets:
		var count := 0
		for node in get_tree().get_nodes_in_group(CombatRoutine.GROUP):
			if _target_of(node as Ship) == target:
				count += 1
		counts.append(count)
	return counts


func _distance(a: Node3D, b: Node3D) -> float:
	return a.global_position.distance_to(b.global_position)


## Name of the ship the player's ship is attacking, or "".
func _attacking(controller: PlayerController) -> String:
	var target := controller.attack_target()
	return Autopilot.name_of(target) if target != null else ""
