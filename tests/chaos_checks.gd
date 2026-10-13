extends Node

## Chaos test for references to world objects (see WorldRegistry and ObjectRef).
##
## The home system runs with its traffic, miners and patrols, plus a few pirates, an invasion
## (started at INVASION_TIME) and the scavenger (wrecks aged at SCAVENGER_TIME), while random
## world objects vanish at random moments: ships destroyed or removed outright (docked ones and
## the player's ship included), drones on the way, field rocks (maybe the one a miner is
## working), wrecks and containers, and on a schedule one gate and one station. Meanwhile the
## "player" keeps selecting things and giving orders about them (looting too, and dropping
## cargo), and the camera follows random objects. Whatever referred to a vanished object must
## cope: no errors at all, and the system keeps going.
##
## Run from the project folder (exit code 0 when everything passes):
##   godot --headless --path . --fixed-fps 60 res://tests/chaos_checks.tscn

const ErrorLog := preload("res://tests/support/error_log.gd")
const ShipScene := preload("res://src/ships/ship.tscn")
const PlayerShipScene := preload("res://src/ships/player_ship.tscn")

const RUN_TIME := 240.0
const PIRATES := 3
## Seconds between random removals, random within this range.
const REMOVE_EVERY := Vector2(0.5, 3.0)
## Seconds between player commands.
const COMMAND_EVERY := 2.0
const GATE_REMOVAL_TIME := 90.0
const INVASION_TIME := 20.0
const SCAVENGER_TIME := 100.0
const STATION_REMOVAL_TIME := 150.0
const KINDS: Array[String] = [
	"ship destroyed", "ship removed", "docked ship removed", "drone", "rock", "wreck", "container",
	"gate", "station",
]

var _errors := ErrorLog.new()
var _rng := RandomNumberGenerator.new()
var _removed := {}  # kind -> count
var _system: Node3D
var _controller: PlayerController
var _camera: OrbitCamera
var _passed := 0
var _failed := 0


func _ready() -> void:
	OS.add_logger(_errors)
	_rng.seed = 2024
	_system = load("res://scenes/systems/home_system.tscn").instantiate()
	var invasion := _system.get_node("Invasion") as Invasion
	invasion.event_seed = 3
	add_child(_system)
	_controller = _system.get_node("PlayerController")
	_camera = _system.get_node("Camera")
	var spawner := _system.get_node("TrafficSpawner") as TrafficSpawner
	var salvage := _system.get_node("SalvageService") as SalvageService
	var aged := false
	for i in PIRATES:
		_spawn_pirate(i + 1)

	var step := 1.0 / Engine.physics_ticks_per_second
	var time := 0.0
	var next_removal := 2.0
	var next_command := 1.0
	var arrivals_at_gate_removal := -1
	var docked_at_removed_station: Array[Ship] = []
	while time < RUN_TIME:
		await get_tree().physics_frame
		time += step
		if time >= next_command:
			next_command += COMMAND_EVERY
			_command()
		if time >= next_removal:
			next_removal = time + _rng.randf_range(REMOVE_EVERY.x, REMOVE_EVERY.y)
			_remove_something()
		if invasion.invaders_arrived == 0 and not invasion.is_running() and time >= INVASION_TIME:
			invasion.start()
		if not aged and time >= SCAVENGER_TIME:
			aged = true
			salvage.age_wrecks(salvage.abandon_time)
		if arrivals_at_gate_removal < 0 and time >= GATE_REMOVAL_TIME:
			arrivals_at_gate_removal = spawner.arrivals
			_remove(_system.get_node("Gates/EastGate"), "gate")
		if docked_at_removed_station.is_empty() and not _removed.has("station") \
				and time >= STATION_REMOVAL_TIME:
			var station := _system.get_node("Stations/BastionOutpost") as SpaceBody
			# Make sure someone is inside, so the check below is not vacuous.
			var guest := ShipScene.instantiate() as Ship
			guest.display_name = "Guest"
			guest.enter_space(_system.get_node("Ships"),
					Transform3D(Basis.IDENTITY, station.get_corridor(0)["inner"]))
			guest.dock_instantly(station)
			for node in get_tree().get_nodes_in_group(Ship.ALL_SHIPS_GROUP):
				if (node as Ship).docked_at == station:
					docked_at_removed_station.append(node)
			_remove(station, "station")

	print("\nRemoved: %s" % _removed)
	for kind in KINDS:
		_check(_removed.get(kind, 0) > 0, "%s: %d" % [kind, _removed.get(kind, 0)])
	_check(spawner.arrivals > arrivals_at_gate_removal,
			"traders still arrive through the remaining gates (%d after the gate vanished)"
			% (spawner.arrivals - arrivals_at_gate_removal))
	# Untyped on purpose: the array holds freed ships.
	var stuck := docked_at_removed_station.filter(func(ship: Variant) -> bool: return is_instance_valid(ship))
	_check(stuck.is_empty(), "ships docked in the vanished station vanished with it (%d of %d left)"
			% [stuck.size(), docked_at_removed_station.size()])
	_check(invasion.invaders_arrived > 0, "the invasion happened (%d invaders came)" % invasion.invaders_arrived)
	_check(salvage.scavengers_launched > 0, "the scavenger went out (%d)" % salvage.scavengers_launched)
	_check(get_tree().get_node_count_in_group(Autopilot.SHIP_GROUP) > 0,
			"the system keeps going (%d ships in space)" % get_tree().get_node_count_in_group(Autopilot.SHIP_GROUP))
	# Last, so that errors in the checks above count too.
	_check(_errors.errors.is_empty(), "no errors while things vanished (%d): %s" % [
			_errors.errors.size(), _errors.errors.slice(0, 5)])
	print("\n%d passed, %d failed" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


## Removes one random world object of a random kind.
func _remove_something() -> void:
	var in_space := get_tree().get_nodes_in_group(Autopilot.SHIP_GROUP)
	var docked := get_tree().get_nodes_in_group(Ship.ALL_SHIPS_GROUP).filter(
			func(node: Node) -> bool: return (node as Ship).is_docked())
	var rocks := (_system.get_node("AsteroidField") as AsteroidField).get_rocks()
	var wrecks := get_tree().get_nodes_in_group(Wreck.GROUP)
	var options := {
		"ship destroyed": in_space,
		"ship removed": in_space,
		"docked ship removed": docked,
		"drone": get_tree().get_nodes_in_group(DroneRoutine.GROUP),
		"rock": rocks,
		"wreck": wrecks.filter(func(node: Node) -> bool: return not (node as Wreck).is_container),
		"container": wrecks.filter(func(node: Node) -> bool: return (node as Wreck).is_container),
	}
	var kinds := options.keys().filter(func(kind: String) -> bool: return not options[kind].is_empty())
	if kinds.is_empty():
		return
	var kind: String = kinds[_rng.randi() % kinds.size()]
	var candidates: Array = options[kind]
	_remove(candidates[_rng.randi() % candidates.size()], kind)


func _remove(node: Node, kind: String) -> void:
	if not is_instance_valid(node) or node.is_queued_for_deletion():
		return
	if kind == "ship destroyed" or kind == "drone":
		(node as Ship).take_hit(1000.0, null)
	else:
		node.queue_free()
	_removed[kind] = _removed.get(kind, 0) + 1


## The "player": select something, give an order about it, sometimes point the camera at it.
## Gets a new ship when the old one is gone.
func _command() -> void:
	if not _controller.has_ship():
		var ship := PlayerShipScene.instantiate() as Ship
		var where := Vector3(_rng.randf_range(-500, 500), 300, _rng.randf_range(-500, 500))
		ship.enter_space(_system.get_node("Ships"), Transform3D(Basis.IDENTITY, where))
		_controller.ship = ship
		_camera.target = ship
	var candidates := get_tree().get_nodes_in_group(Autopilot.SHIP_GROUP) \
			+ get_tree().get_nodes_in_group(Autopilot.OBSTACLE_GROUP)
	var target := candidates[_rng.randi() % candidates.size()] as Node3D
	_controller.select(target)
	match _rng.randi() % 6:
		0:
			_controller.approach_selected()
		1:
			_controller.orbit_selected()
		2:
			_controller.attack_selected()
		3:
			_controller.loot_selected()
		4:
			_controller.loot_all()
		5:
			var cargo: Cargo = _controller.ship.cargo
			if cargo.is_empty():
				cargo.add(Items.LOOT_1, 1)  # Something to drop.
			_controller.jettison(cargo.items()[0], 1)
	if _rng.randf() < 0.3:
		_camera.target = target


func _spawn_pirate(number: int) -> void:
	var ship := ShipScene.instantiate() as Ship
	ship.display_name = "Pirate %d" % number
	ship.faction = Factions.PIRATE
	ship.hull_color = Color(0.9, 0.25, 0.2)
	ship.add_child(CombatRoutine.new())
	var where := Vector3(_rng.randf_range(-1500, 1500), _rng.randf_range(-200, 200), _rng.randf_range(-1500, 1500))
	ship.enter_space(_system.get_node("Ships"), Transform3D(Basis.IDENTITY, where))


func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  " + message)
	else:
		_failed += 1
		print("  FAIL  " + message)
