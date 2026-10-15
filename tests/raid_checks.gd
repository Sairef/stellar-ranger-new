extends "res://tests/support/check_suite.gd"

## Headless checks for pirate raids in the home system (PirateRaids): the warning, pirates coming
## through the gate and prowling the asteroid field, who reacts and who does not (no system-wide
## alert: miners nearby run, patrols hunt, traffic goes on), who is armed (pirates prey on unarmed
## traders and miners), the raiders staying until destroyed (or leaving after a set time), the
## military's answer (a squad from the defense station's Garrison after a delay, another one if
## it is lost, none during an alert) and raids coming on their own, one at a time, never during
## an invasion.
## Run from the project folder (exit code 0 when everything passes):
##   godot --headless --path . --fixed-fps 60 res://tests/raid_checks.tscn

const SystemScene := preload("res://scenes/systems/home_system.tscn")


func _ready() -> void:
	await _who_is_armed()
	await _raid_full_cycle()
	await _raiders_stay()
	await _raiders_leave()
	await _squad_clears_the_field()
	await _squad_lost()
	await _raid_over_while_squad_leaves()
	await _no_squad_during_alert()
	await _raid_over_after_invasion_call()
	await _raids_on_their_own()
	_finish()


## Two small pirates through the west gate, from the warning until they are gone.
func _raid_full_cycle() -> void:
	_begin("A raid: warning, the field is hunted, miners run, patrols come, the survivors leave")
	var system := SystemScene.instantiate() as Node3D
	var raids := system.get_node("PirateRaids") as PirateRaids
	raids.auto = false
	raids.event_seed = 7
	raids.small_pirates = Vector2i(2, 2)
	raids.leader_chance = 0.0
	raids.stay_time = 60.0
	_world.add_child(system)
	var security := system.get_node("SystemSecurity") as SystemSecurity
	var field := system.get_node("AsteroidField") as AsteroidField
	var gate := system.get_node("Gates/WestGate") as Gate
	var miners := get_tree().get_nodes_in_group(MinerRoutine.GROUP)
	var stats := {"miner_docks": 0, "miner_undocks": 0, "alert": false, "outside_hunt": 0,
			"reached_field": false, "patrol_attacks": 0, "over": false}
	for miner in miners:
		(miner as Ship).docked.connect(func(_s: SpaceBody) -> void: stats.miner_docks += 1)
		(miner as Ship).undocked.connect(func(_s: SpaceBody) -> void: stats.miner_undocks += 1)
	raids.raid_over.connect(func() -> void: stats.over = true)

	# Let the miners get to work first.
	await _wait(40.0)
	var announcements := security.announcements
	raids.start(gate)
	_check(security.announcements == announcements + 1 and security.announcement_is_warning
			and "Pirates" in security.announcement, "a warning: %s" % security.announcement)
	stats.miner_docks = 0
	stats.miner_undocks = 0

	var center := field.global_position
	var watch := func() -> void:
		stats.alert = stats.alert or security.alert
		for ship in raids.raiders():
			if center.distance_to(ship.global_position) < raids.hunt_radius:
				stats.reached_field = true
			var target := ship.current_order.get_attack_target() if ship.current_order != null else null
			# A chase that leaves the territory is given up at once (a tick or two of slack).
			if target != null and center.distance_to(target.global_position) > raids.hunt_radius + 50.0:
				stats.outside_hunt += 1
		for node in get_tree().get_nodes_in_group(NpcRoutine.GROUP):
			var patrol := node as Ship
			var target := patrol.current_order.get_attack_target() if patrol.current_order != null else null
			if target != null and target.faction == Factions.PIRATE:
				stats.patrol_attacks += 1
	var arrived := await _simulate(30.0, func() -> bool: return raids.phase == PirateRaids.Phase.HUNTING, watch)
	_check(arrived > 0.0 and raids.raiders().size() == 2,
			"both pirates came through the gate (%d, %.0f s)" % [raids.raiders().size(), arrived])
	var time := await _simulate(400.0, func() -> bool: return stats.over, watch)
	_check(time > 0.0, "the raid is over (%.0f s later)" % time)
	_check(stats.reached_field, "the pirates went to the asteroid field")
	_check(stats.outside_hunt == 0, "they never chased anyone far from the field (%d ticks)" % stats.outside_hunt)
	_check(not stats.alert, "no system-wide alert for pirates")
	_check(stats.miner_docks > 0, "miners ran home (%d docked)" % stats.miner_docks)
	_check(stats.patrol_attacks > 0, "patrols went after the pirates")
	_check(raids.raiders().is_empty() and raids.phase == PirateRaids.Phase.WAITING,
			"no raiders left, waiting for the next raid")
	_check(raids.next_raid_in >= raids.interval.x and raids.next_raid_in <= raids.interval.y,
			"the next one is due in %.0f s" % raids.next_raid_in)
	var undocks_before: int = stats.miner_undocks
	await _wait(30.0)
	_check(stats.miner_undocks > undocks_before, "the miners went back to work")
	await _end()


## Pirates prey on traders and miners: those fly unarmed. Patrols are armed.
func _who_is_armed() -> void:
	_begin("Traders, miners and the player's miner fly unarmed; patrols are armed")
	var system := SystemScene.instantiate() as Node3D
	(system.get_node("PirateRaids") as PirateRaids).auto = false
	_world.add_child(system)
	await _wait(1.0)
	var counts := {"traders": 0, "armed": 0}
	for role: StringName in [TraderRoutine.GROUP, MinerRoutine.GROUP]:
		for node in get_tree().get_nodes_in_group(role):
			counts.traders += 1
			if (node as Ship).is_armed():
				counts.armed += 1
	_check(counts.traders > 4 and counts.armed == 0,
			"none of %d traders and miners is armed (%d)" % [counts.traders, counts.armed])
	var miner := system.get_node("Ships/PlayerMiner") as Ship
	_check(not miner.is_armed() and miner.can_mine(), "the player's mining ship mines and is unarmed")
	var patrols := get_tree().get_nodes_in_group(NpcRoutine.GROUP)
	_check(not patrols.is_empty() and patrols.all(func(ship: Ship) -> bool: return ship.is_armed()),
			"every patrol is armed (%d)" % patrols.size())
	await _end()


## By default raiders do not leave: a field nobody clears stays lost (here no squad comes either).
func _raiders_stay() -> void:
	_begin("By default raiders stay until destroyed")
	var system := SystemScene.instantiate() as Node3D
	var raids := system.get_node("PirateRaids") as PirateRaids
	raids.auto = false
	raids.response_delay = INF
	raids.event_seed = 5
	raids.small_pirates = Vector2i(2, 2)
	raids.leader_chance = 0.0
	_world.add_child(system)
	# Nobody fights: the raiders live as long as the scenario.
	for node in get_tree().get_nodes_in_group(Ship.ALL_SHIPS_GROUP):
		var weapon := (node as Ship).get_weapon()
		if weapon != null:
			weapon.enabled = false
	raids.start(system.get_node("Gates/WestGate") as Gate)
	var arrived: float = await _simulate(30.0, func() -> bool: return raids.phase == PirateRaids.Phase.HUNTING)
	for ship in raids.raiders():
		ship.get_weapon().enabled = false
	_check(arrived > 0.0 and raids.raiders().size() == 2, "two pirates came (%d)" % raids.raiders().size())
	var left: float = await _simulate(240.0, func() -> bool: return raids.phase != PirateRaids.Phase.HUNTING)
	_check(left < 0.0 and raids.raiders().size() == 2,
			"four minutes later they still hunt the field (%d)" % raids.raiders().size())
	await _end()


## Raiders nobody shoots down stay `stay_time`, then jump out through the nearest gate.
func _raiders_leave() -> void:
	_begin("Raiders still alive after their time leave through the nearest gate")
	var system := SystemScene.instantiate() as Node3D
	var raids := system.get_node("PirateRaids") as PirateRaids
	raids.auto = false
	raids.event_seed = 11
	raids.small_pirates = Vector2i(3, 3)
	raids.leader_chance = 0.0
	raids.stay_time = 20.0
	_world.add_child(system)
	# Nobody fights: the raiders must live to leave.
	for node in get_tree().get_nodes_in_group(Ship.ALL_SHIPS_GROUP):
		var weapon := (node as Ship).get_weapon()
		if weapon != null:
			weapon.enabled = false
	var gate := system.get_node("Gates/WestGate") as Gate
	var jumped := {"count": 0, "gate": ""}
	raids.start(gate)
	var arrived := await _simulate(30.0, func() -> bool: return raids.phase == PirateRaids.Phase.HUNTING)
	for ship in raids.raiders():
		ship.get_weapon().enabled = false
		ship.jumped.connect(func(through: Gate) -> void:
			jumped.count += 1
			jumped.gate = through.display_name)
	_check(arrived > 0.0 and raids.raiders().size() == 3, "three pirates came (%d)" % raids.raiders().size())
	var time := await _simulate(raids.stay_time + 1.0, func() -> bool: return raids.phase == PirateRaids.Phase.LEAVING)
	_check(time > 0.0 and raids.raiders().all(func(ship: Ship) -> bool: return ship.current_order is JumpOrder),
			"after %.0f s every raider heads for a gate" % raids.stay_time)
	time = await _simulate(180.0, func() -> bool: return not raids.is_running())
	_check(time > 0.0 and jumped.count == 3, "all three jumped out (%d, the last through %s, %.0f s)"
			% [jumped.count, jumped.gate, time])
	await _end()


## The defense station answers a raid: after the delay the warning named, a squad (by default 3
## small and 1 medium ship) leaves, hunts the raiders on the field only and docks home once it is
## clear.
func _squad_clears_the_field() -> void:
	_begin("A squad from the defense station clears the field and goes home")
	var system := _raid_system(20.0)
	var raids := system.get_node("PirateRaids") as PirateRaids
	var garrison := Garrison.of(system.get_node("Stations/BastionOutpost"))
	var security := system.get_node("SystemSecurity") as SystemSecurity
	var center := (system.get_node("AsteroidField") as Node3D).global_position
	raids.start(system.get_node("Gates/WestGate") as Gate)
	_check("Bastion Outpost will send a squad in ~1 min" in security.announcement,
			"the warning says when the squad comes: %s" % security.announcement)
	var sent := await _simulate(25.0, func() -> bool: return raids.squads_sent > 0)
	_check(sent >= raids.response_delay - 0.1 and "sends a squad" in security.announcement,
			"it is sent after %.0f s (%.1f s): %s" % [raids.response_delay, sent, security.announcement])
	var squad := ShipClass.sizes(raids.squad_small, raids.squad_medium, 0)
	var out := await _simulate(40.0, func() -> bool: return garrison.ships_launched == squad.size())
	var sizes: Array[ShipClass.Size] = []
	for ship in garrison.ships():
		if ship.is_in_space():
			sizes.append(ship.ship_class)
	sizes.sort()
	_check(out >= 0.0 and sizes == squad, "%d small and %d medium undock (%s)"
			% [raids.squad_small, raids.squad_medium, sizes])
	var stats := {"attacks": 0, "outside": 0, "over": false}
	raids.raid_over.connect(func() -> void: stats.over = true)
	var over := await _simulate(300.0, func() -> bool: return stats.over, func() -> void:
		for ship in garrison.ships():
			var target := ship.current_order.get_attack_target() if ship.current_order != null else null
			if target != null:
				stats.attacks += 1
				if center.distance_to(target.global_position) > raids.hunt_radius + 50.0:
					stats.outside += 1)
	_check(over > 0.0 and stats.attacks > 0, "the squad fought the raiders and the raid is over (%.0f s)" % over)
	_check(stats.outside == 0, "it hunted only on the field (%d ticks outside)" % stats.outside)
	var home := await _simulate(200.0, func() -> bool:
		return garrison.ships().all(func(ship: Ship) -> bool: return ship.is_docked()))
	_check(home > 0.0, "the squad docked back home (%.0f s)" % home)
	_check(raids.squads_sent == 1, "one squad was enough (%d)" % raids.squads_sent)
	await _end()


## A squad lost while the raiders are still there: another one after the same delay, at full
## strength again.
func _squad_lost() -> void:
	_begin("A lost squad is followed by another after the delay")
	var system := _raid_system(10.0)
	var raids := system.get_node("PirateRaids") as PirateRaids
	var garrison := Garrison.of(system.get_node("Stations/BastionOutpost"))
	var security := system.get_node("SystemSecurity") as SystemSecurity
	# Nobody fights: the raiders must outlive the squad.
	for node in get_tree().get_nodes_in_group(Ship.ALL_SHIPS_GROUP):
		var weapon := (node as Ship).get_weapon()
		if weapon != null:
			weapon.enabled = false
	var squad := raids.squad_small + raids.squad_medium
	raids.start(system.get_node("Gates/WestGate") as Gate)
	await _simulate(50.0, func() -> bool: return garrison.ships_launched == squad)
	_check(garrison.ships_launched == squad, "the first squad is out (%d)" % garrison.ships_launched)
	for ship in garrison.ships():
		if ship.is_in_space():
			ship.take_hit(1000.0, null)
	await _wait(0.5)
	_check(not raids.raiders().is_empty() and "send another squad" in security.announcement,
			"the pirates are still there: %s" % security.announcement)
	var again := await _simulate(20.0, func() -> bool: return raids.squads_sent == 2)
	_check(again >= raids.response_delay - 1.0, "the next squad is sent %.1f s later" % again)
	var out := await _simulate(40.0, func() -> bool: return garrison.ships_launched == 2 * squad)
	_check(out >= 0.0, "%d more ships undock: the garrison was topped up (%d)" % [squad, garrison.ships_launched])
	await _end()


## A raid that ends while the squad is still leaving the station: whoever is still docked stays,
## whoever is out comes back.
func _raid_over_while_squad_leaves() -> void:
	_begin("The raid ends while the squad is leaving")
	var system := _raid_system(5.0)
	var raids := system.get_node("PirateRaids") as PirateRaids
	var garrison := Garrison.of(system.get_node("Stations/BastionOutpost"))
	var launched := {"at_end": -1}
	raids.raid_over.connect(func() -> void: launched.at_end = garrison.ships_launched)
	raids.start(system.get_node("Gates/WestGate") as Gate)
	await _simulate(30.0, func() -> bool:
		return raids.squads_sent > 0 and raids.phase == PirateRaids.Phase.HUNTING)
	for ship in raids.raiders():
		ship.take_hit(1000.0, null)
	var over := await _simulate(2.0, func() -> bool: return launched.at_end >= 0)
	_check(over >= 0.0 and launched.at_end < raids.squad_small + raids.squad_medium,
			"over before the whole squad was out (%d out)" % launched.at_end)
	await _wait(10.0)
	_check(garrison.ships_launched == launched.at_end, "nobody left after that (%d)" % garrison.ships_launched)
	var home := await _simulate(120.0, func() -> bool:
		return garrison.ships().all(func(ship: Ship) -> bool: return ship.is_docked()))
	_check(home >= 0.0, "everyone is docked again (%.0f s)" % home)
	await _end()


## During an alert (an invasion) no squad is sent against a raid; after the all clear it is.
func _no_squad_during_alert() -> void:
	_begin("No squad during an alert, one after the all clear")
	var system := _raid_system(5.0)
	var raids := system.get_node("PirateRaids") as PirateRaids
	var security := system.get_node("SystemSecurity") as SystemSecurity
	var gate := system.get_node("Gates/WestGate") as Gate
	for node in get_tree().get_nodes_in_group(Ship.ALL_SHIPS_GROUP):
		var weapon := (node as Ship).get_weapon()
		if weapon != null:
			weapon.enabled = false
	raids.start(gate)
	security.raise_alert(gate, 15.0)
	var sent := await _simulate(12.0, func() -> bool: return raids.squads_sent > 0)
	_check(sent < 0.0 and security.alert, "none while the alert lasts")
	sent = await _simulate(40.0, func() -> bool: return raids.squads_sent > 0)
	_check(sent > 0.0 and not security.alert, "sent after the all clear (%.0f s later)" % sent)
	await _end()


## The squad is still leaving the ports when an invasion calls the whole garrison out, and then
## the raid ends: the raid's cancel keeps none of them home, they are the invasion's now.
func _raid_over_after_invasion_call() -> void:
	_begin("A raid ends after an invasion called its squad: everyone still leaves")
	var system := _raid_system(5.0)
	var raids := system.get_node("PirateRaids") as PirateRaids
	var invasion := system.get_node("Invasion") as Invasion
	invasion.reinforcement_delay = 0.0
	invasion.warmup_time = 600.0  # No invaders needed: only the call matters.
	var garrison := Garrison.of(system.get_node("Stations/BastionOutpost"))
	for node in get_tree().get_nodes_in_group(Ship.ALL_SHIPS_GROUP):
		var weapon := (node as Ship).get_weapon()
		if weapon != null:
			weapon.enabled = false
	raids.start(system.get_node("Gates/WestGate") as Gate)
	await _simulate(30.0, func() -> bool:
		return raids.squads_sent > 0 and raids.phase == PirateRaids.Phase.HUNTING)
	invasion.start()
	for ship in raids.raiders():
		ship.take_hit(1000.0, null)
	var queued := garrison.ships().filter(func(ship: Ship) -> bool: return ship.is_docked() and garrison.is_queued(ship))
	await _simulate(3.0, func() -> bool: return not raids.is_running())
	_check(not raids.is_running() and not queued.is_empty(),
			"the raid is over while %d of the garrison wait for a port" % queued.size())
	var all_out := await _simulate(150.0, func() -> bool: return garrison.ships_launched >= garrison.strength())
	_check(all_out > 0.0, "the whole garrison left against the invasion (%d of %d)"
			% [garrison.ships_launched, garrison.strength()])
	await _end()


## The home system with raids by hand only (two small pirates, no leader) and a squad due
## `response_delay` seconds after a raid starts.
func _raid_system(response_delay: float) -> Node3D:
	var system := SystemScene.instantiate() as Node3D
	var raids := system.get_node("PirateRaids") as PirateRaids
	raids.auto = false
	raids.event_seed = 13
	raids.small_pirates = Vector2i(2, 2)
	raids.leader_chance = 0.0
	raids.response_delay = response_delay
	_world.add_child(system)
	return system


## With `auto` on, a raid comes when due, the next one only after it is over, and none during an
## invasion. The debug button starts one by hand.
func _raids_on_their_own() -> void:
	_begin("Raids come on their own, one at a time, not during an invasion")
	var system := SystemScene.instantiate() as Node3D
	var raids := system.get_node("PirateRaids") as PirateRaids
	raids.event_seed = 3
	raids.first_raid = Vector2(5.0, 5.0)
	_world.add_child(system)
	_check(raids.auto and not raids.is_running(), "waiting for the first raid")
	var time := await _simulate(10.0, func() -> bool: return raids.is_running())
	_check(time > 4.0 and raids.raids == 1, "it came when due (%.1f s)" % time)
	raids.start()
	_check(raids.raids == 1, "no second raid while one is going on")
	# Shoot every raider down as soon as it comes out of the gate.
	var over := await _simulate(30.0, func() -> bool: return not raids.is_running(), func() -> void:
		for ship in raids.raiders():
			ship.take_hit(1000.0, null))
	_check(over > 0.0, "the raid is over once every raider is gone (%.1f s)" % over)

	var invasion := system.get_node("Invasion") as Invasion
	invasion.start()
	raids.next_raid_in = 0.0
	await _wait(1.0)
	_check(not raids.is_running() and raids.next_raid_in > 0.0,
			"a raid due during an invasion waits (%.0f s)" % raids.next_raid_in)
	await _end()

	_begin("The debug panel starts a raid")
	system = SystemScene.instantiate() as Node3D
	raids = system.get_node("PirateRaids") as PirateRaids
	raids.auto = false
	_world.add_child(system)
	var button: Button = null
	for node in system.find_children("*", "Button", true, false):
		if (node as Button).text == "Pirate raid":
			button = node
	_check(button != null, "there is a Pirate raid button")
	if button != null:
		button.pressed.emit()
	_check(raids.is_running(), "it starts a raid")
	await _end()
