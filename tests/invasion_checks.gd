extends Node

## Headless checks for the invasion event in the home system: the whole cycle from the gate
## warming up to the all clear, and how everyone reacts on the way.
## Run from the project folder (exit code 0 when everything passes):
##   godot --headless --path . --fixed-fps 60 res://tests/invasion_checks.tscn

const ErrorLog := preload("res://tests/support/error_log.gd")
const SystemScene := preload("res://scenes/systems/home_system.tscn")

var _errors := ErrorLog.new()
var _passed := 0
var _failed := 0


func _ready() -> void:
	OS.add_logger(_errors)
	await _small_invasion_full_cycle()
	await _default_invasion()
	_check(_errors.errors.is_empty(), "no errors during the run %s" % _errors.errors.slice(0, 5))
	print("\n%d passed, %d failed" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


## Three invaders, a garrison of four: follow the event from start to the all clear and after.
func _small_invasion_full_cycle() -> void:
	print("\n== Small invasion: warm-up, reactions, fight, all clear, back to normal")
	var system := SystemScene.instantiate() as Node3D
	var invasion := system.get_node("Invasion") as Invasion
	invasion.event_seed = 5
	invasion.fighters = 3
	invasion.with_leader = false
	invasion.garrison = 4
	invasion.reinforcement_delay = 10.0
	add_child(system)
	var security := system.get_node("SystemSecurity") as SystemSecurity
	var gate := system.get_node("Gates/EastGate") as Gate

	# Let the traffic get going first.
	await _run(30.0)
	var events := _EventLog.new(self, security, gate)
	invasion.start(gate)
	_check(gate.active and security.alert, "the gate lights up and the system goes on alert at once")
	var finished := {"at": -1.0}
	invasion.finished.connect(func() -> void: finished.at = events.time)
	var miners_at_start := events.miners_in_space()

	while events.time < 300.0 and (finished.at < 0.0 or security.alert):
		await get_tree().physics_frame
		events.tick()
	_check(finished.at > 0.0, "the invasion was repelled (%.0f s after the start)" % finished.at)
	_check(invasion.invaders_arrived == 3, "all 3 invaders came through the gate (%d)" % invasion.invaders_arrived)
	_check(events.first_invader_at >= invasion.warmup_time,
			"the first one came out after the %.0f s warm-up (%.1f s)" % [invasion.warmup_time, events.first_invader_at])
	_check(events.trader_shelters + events.trader_escapes > 0,
			"traders reacted: %d sheltered at stations, %d fled through gates" % [events.trader_shelters, events.trader_escapes])
	_check(events.escapes_through_invaded_gate == 0,
			"nobody fled through the invaded gate once the fleet was coming (%d)" % events.escapes_through_invaded_gate)
	_check(events.sheltered_miners.size() >= miners_at_start,
			"miners out in space ran home and docked (%d of %d)" % [events.sheltered_miners.size(), miners_at_start])
	_check(events.patrol_shots_at_invaders > 0, "patrols fought the invaders (%d shots)" % events.patrol_shots_at_invaders)
	_check(invasion.defenders_launched == 4, "the garrison was launched (%d)" % invasion.defenders_launched)
	_check(not security.alert, "the alert was lifted after the fight")
	_check(events.wrecks() >= 3, "wrecks with loot are left behind (%d)" % events.wrecks())

	# Back to normal.
	var normal := {"miner_undocked": false}
	for miner in get_tree().get_nodes_in_group(MinerRoutine.GROUP):
		(miner as Ship).undocked.connect(func(_s: SpaceBody) -> void: normal.miner_undocked = true)
	await _run(40.0)
	_check(normal.miner_undocked, "after the all clear miners go back to work")
	_check(events.patrols_on_routine(), "patrols are back on their routes")
	_check(events.defenders_docked(), "the garrison is back home")
	_check(events.contacts() == 0, "no physical contacts during the whole event (%d ticks)" % events.contacts())
	system.queue_free()
	await get_tree().physics_frame


## The event as the debug button starts it: default fleet and garrison, random gate.
func _default_invasion() -> void:
	print("\n== Default invasion (as the debug button starts it)")
	var system := SystemScene.instantiate() as Node3D
	var invasion := system.get_node("Invasion") as Invasion
	invasion.event_seed = 11
	add_child(system)
	var button := _find_button(system.get_node("DebugPanel"), "Start invasion")
	_check(button != null, "the debug panel has a Start invasion button")
	await _run(5.0)
	button.pressed.emit()
	_check(invasion.is_running() and button.disabled, "the button starts it and is disabled while it runs")
	await _run(120.0)
	_check(invasion.invaders_arrived == invasion.fighters + 1,
			"the whole fleet came through (%d)" % invasion.invaders_arrived)
	_check(invasion.defenders_launched == invasion.garrison,
			"the whole garrison was launched (%d)" % invasion.defenders_launched)
	system.queue_free()
	await get_tree().physics_frame


func _run(seconds: float) -> void:
	for i in int(seconds * Engine.physics_ticks_per_second):
		await get_tree().physics_frame


func _find_button(root: Node, text: String) -> Button:
	for node in root.find_children("*", "Button", true, false):
		if (node as Button).text == text:
			return node
	return null


func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  " + message)
	else:
		_failed += 1
		print("  FAIL  " + message)


## Watches the ships of the system during an invasion and counts what they do.
class _EventLog:
	var time := 0.0
	var first_invader_at := -1.0
	var trader_shelters := 0
	var trader_escapes := 0
	var escapes_through_invaded_gate := 0
	var sheltered_miners := {}
	var patrol_shots_at_invaders := 0

	var _tree: SceneTree
	var _security: SystemSecurity
	var _gate: Gate
	var _seen := {}  # ship id -> true
	var _contacts := {}  # ship id -> collision ticks

	func _init(owner: Node, security: SystemSecurity, gate: Gate) -> void:
		_tree = owner.get_tree()
		_security = security
		_gate = gate
		tick()

	func tick() -> void:
		time += 1.0 / Engine.physics_ticks_per_second
		for node in _tree.get_nodes_in_group(Ship.ALL_SHIPS_GROUP):
			var ship := node as Ship
			_contacts[ship.object_id] = ship.collision_ticks
			if _seen.has(ship.object_id):
				continue
			_seen[ship.object_id] = true
			_watch(ship)

	func _watch(ship: Ship) -> void:
		if ship.faction == Factions.INVADER and first_invader_at < 0.0:
			first_invader_at = time
		if ship.is_in_group(MinerRoutine.GROUP) and ship.is_docked():
			sheltered_miners[ship.object_id] = true
		ship.docked.connect(func(_station: SpaceBody) -> void:
			if not _security.alert:
				return
			if ship.is_in_group(TraderRoutine.GROUP):
				trader_shelters += 1
			if ship.is_in_group(MinerRoutine.GROUP):
				sheltered_miners[ship.object_id] = true)
		ship.jumped.connect(func(gate: Gate) -> void:
			if not _security.alert:
				return
			trader_escapes += 1
			if gate == _gate and first_invader_at >= 0.0:
				escapes_through_invaded_gate += 1)
		if ship.is_in_group(NpcRoutine.GROUP):
			ship.get_weapon().fired.connect(func(target: Ship, _hit: bool) -> void:
				if target.faction == Factions.INVADER:
					patrol_shots_at_invaders += 1)

	func miners_in_space() -> int:
		var count := 0
		for node in _tree.get_nodes_in_group(MinerRoutine.GROUP):
			if (node as Ship).is_in_space():
				count += 1
		return count

	func patrols_on_routine() -> bool:
		for node in _tree.get_nodes_in_group(NpcRoutine.GROUP):
			if (node as Ship).current_order is AttackOrder:
				return false
		return true

	func defenders_docked() -> bool:
		for node in _tree.get_nodes_in_group(CombatRoutine.GROUP):
			var ship := node as Ship
			if ship.faction != Factions.INVADER and not ship.is_docked():
				return false
		return true

	func wrecks() -> int:
		var count := 0
		for node in _tree.get_nodes_in_group(Autopilot.OBSTACLE_GROUP):
			if node is Wreck:
				count += 1
		return count

	func contacts() -> int:
		var total := 0
		for ticks: int in _contacts.values():
			total += ticks
		return total
