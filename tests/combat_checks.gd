extends Node

## Headless combat checks. Run from the project folder (exit code 0 when everything passes):
##   godot --headless --path . --fixed-fps 60 res://tests/combat_checks.tscn
## Set the environment variable NAV_DIAG=1 to print every physical contact.

const ErrorLog := preload("res://tests/support/error_log.gd")
const ShipScene := preload("res://src/ships/ship.tscn")
## 75% over a few dozen shots: allow for chance, but catch a broken hit roll.
const MIN_HIT_RATIO := 0.55
const MAX_HIT_RATIO := 0.95

var _world: Node3D
var _errors := ErrorLog.new()
var _passed := 0
var _failed := 0


func _ready() -> void:
	OS.add_logger(_errors)
	await _damage_layers()
	await _duel()
	await _out_of_range()
	await _pirate_meets_armed_trader()
	await _combat_sandbox_scene()
	await _auto_engage()
	await _faction_credits()
	_check(_errors.errors.is_empty(), "no errors during the run %s" % _errors.errors)
	print("\n%d passed, %d failed" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


# --- Scenarios -------------------------------------------------------------------------------

func _damage_layers() -> void:
	_begin("Shield first, then armor, then a wreck with loot")
	var ship := _spawn_ship("Target", Vector3.ZERO, Factions.NEUTRAL)
	var attacker := _spawn_ship("Attacker", Vector3(0, 0, -2000), Factions.PIRATE)
	attacker.get_weapon().enabled = false
	ship.cargo.add(Items.ORE, 10)
	var stats := {"wreck": null}
	ship.destroyed.connect(func(_ship: Ship, wreck: Wreck) -> void: stats.wreck = wreck)

	for i in 20:
		ship.take_hit(1.0, attacker)
	_check(ship.shield == 0.0 and ship.armor == 10.0,
			"20 hits empty the shield and leave the armor (%s)" % ship.get_health_text())
	for i in 9:
		ship.take_hit(1.0, attacker)
	_check(ship.armor == 1.0 and ship.is_in_space(), "9 more hits leave 1 armor (%s)" % ship.get_health_text())
	ship.take_hit(1.0, attacker)
	_check(stats.wreck != null, "the 30th hit destroys the ship")
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
	attacker.give_order(AttackOrder.new(target))

	var time: float = await _simulate(90.0, func() -> bool: return stats.destroyed)
	_check(time > 0.0, "the target was destroyed in %.1f s" % time)
	_check(stats.hits == 30, "it took exactly 30 hits: 20 shield + 10 armor (%d)" % stats.hits)
	var ratio := float(stats.hits) / maxf(1.0, stats.shots)
	_check(ratio >= MIN_HIT_RATIO and ratio <= MAX_HIT_RATIO,
			"about 75%% of shots hit (%d of %d, %.0f%%)" % [stats.hits, stats.shots, ratio * 100.0])
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


## A pirate hunts an armed trader that has no orders: the trader shoots back on its own.
func _pirate_meets_armed_trader() -> void:
	_begin("Pirate attacks an armed trader")
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
	_check(stats.trader_shots > 0, "the trader fired back without orders (%d shots)" % stats.trader_shots)
	_check(time > 0.0 and stats.losses == 1, "one of them was destroyed in %.1f s" % time)
	for ship in [trader, pirate]:
		if is_instance_valid(ship):
			stats.contacts += ship.collision_ticks
	_check(stats.contacts == 0, "no physical contacts (%d ticks)" % stats.contacts)
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
	_check(player.get_order_label() == "Attack Pirate 1",
			"an attack the player ordered has no note (%s)" % player.get_order_label())
	time = await _simulate(60.0, func() -> bool: return stats.kills > 0)
	_check(time > 0.0, "the player kills the pirate it was ordered to attack (%.1f s)" % time)
	time = await _simulate(30.0, func() -> bool: return _attacking(controller) == second_name)
	_check(time >= 0.0, "then goes after the next hostile its weapon fires at: %s (%.1f s)" % [second_name, time])
	await _end()


## Faction credits (placeholder): every ship that fired at a destroyed enemy shares the reward,
## and the player gets +1, whoever finished the enemy off. A kill the player took no part in
## earns nothing, and neither does shooting down a neutral.
func _faction_credits() -> void:
	_begin("Faction credits: everyone who fired at a destroyed enemy")
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
	var target := ObjectRef.to(pirate)
	var time: float = await _simulate(60.0, func() -> bool: return target.resolve() == null)
	_check(time > 0.0, "the player and an ally shoot the pirate down (%.1f s)" % time)
	_check(shares["You"] == 1 and shares["Ally"] == 1,
			"both of them took part and share the reward (%s)" % shares)
	_check(controller.faction_credits == 1, "the player earned 1 faction credit (%d)" % controller.faction_credits)

	var far := _spawn_ship("Far pirate", player.global_position + Vector3(0, 0, 5000), Factions.PIRATE)
	far.take_hit(100.0, null)
	_check(controller.faction_credits == 1, "a kill the player took no part in earns nothing (%d)"
			% controller.faction_credits)

	var bystander := _spawn_ship("Bystander", player.global_position + Vector3(0, 0, 200), Factions.NEUTRAL)
	bystander.get_weapon().enabled = false
	ally.get_weapon().enabled = false
	player.get_weapon().damage = 10.0
	controller.select(bystander)
	controller.attack_selected()
	target = ObjectRef.to(bystander)
	time = await _simulate(30.0, func() -> bool: return target.resolve() == null)
	_check(time > 0.0 and shares["You"] == 2 and controller.faction_credits == 1,
			"shooting down a neutral earns nothing (%d credits)" % controller.faction_credits)
	await _end()


# --- Helpers ---------------------------------------------------------------------------------

func _begin(title: String) -> void:
	print("\n== %s" % title)
	_world = Node3D.new()
	add_child(_world)


func _end() -> void:
	_world.queue_free()
	_world = null
	# Wrecks and effects live in the current scene, not in the scenario's world.
	for child in get_children():
		if child is Wreck or child is FadingEffect:
			child.queue_free()
	await get_tree().physics_frame


func _spawn_ship(ship_name: String, position: Vector3, faction: StringName) -> Ship:
	var ship := ShipScene.instantiate() as Ship
	ship.display_name = ship_name
	ship.faction = faction
	ship.enter_space(_world, Transform3D(Basis.IDENTITY, position))
	if OS.get_environment("NAV_DIAG") != "":
		ship.collided.connect(func(collider: Object) -> void:
			print("    contact: %s hit %s | %s | speed %.1f" % [ship_name,
					Autopilot.name_of(collider), ship.get_order_label(), ship.speed]))
	return ship


## Name of the ship the player's ship is attacking, or "".
func _attacking(controller: PlayerController) -> String:
	var target := controller.attack_target()
	return Autopilot.name_of(target) if target != null else ""


## Advances the simulation until `done` returns true or `timeout` seconds pass.
## Returns the elapsed time, or -1.0 on timeout.
func _simulate(timeout: float, done: Callable) -> float:
	var step := 1.0 / Engine.physics_ticks_per_second
	var time := 0.0
	while time < timeout:
		await get_tree().physics_frame
		time += step
		if done.call():
			return time
	return -1.0


func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  " + message)
	else:
		_failed += 1
		print("  FAIL  " + message)
