extends "res://tests/support/check_suite.gd"

## Headless checks for pirate raids in the home system (PirateRaids): the warning, pirates coming
## through the gate and prowling the asteroid field, who reacts and who does not (no system-wide
## alert: miners nearby run, patrols hunt, traffic goes on), who is armed (pirates prey on unarmed
## traders and miners), the raiders staying until destroyed (or leaving after a set time), and
## raids coming on their own, one at a time, never during an invasion.
## Run from the project folder (exit code 0 when everything passes):
##   godot --headless --path . --fixed-fps 60 res://tests/raid_checks.tscn

const SystemScene := preload("res://scenes/systems/home_system.tscn")


func _ready() -> void:
	await _who_is_armed()
	await _raid_full_cycle()
	await _raiders_stay()
	await _raiders_leave()
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


## By default raiders do not leave: a field nobody clears stays lost.
func _raiders_stay() -> void:
	_begin("By default raiders stay until destroyed")
	var system := SystemScene.instantiate() as Node3D
	var raids := system.get_node("PirateRaids") as PirateRaids
	raids.auto = false
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
