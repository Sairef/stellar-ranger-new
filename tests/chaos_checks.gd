extends "res://tests/support/check_suite.gd"

## Chaos test for references to world objects (see WorldRegistry and ObjectRef).
##
## The home system runs with its traffic, miners and patrols, plus a few pirates, an invasion
## (started at INVASION_TIME), a pirate raid (started at RAID_TIME) and the scavenger (from SCAVENGER_TIME on, wrecks are aged every
## AGING_EVERY seconds until it comes: at any given moment there may be none), while random
## world objects vanish at random moments: ships destroyed or removed outright (docked ones and
## the player's ship included), drones on the way, field rocks (maybe the one a miner is
## working), wrecks and containers, escape pods, and on a schedule one gate and one station.
## Meanwhile the "player" keeps selecting things and giving orders about them (looting too,
## dropping cargo, docking, mining, switching modules on), uses the station while docked (sells,
## repairs, buys modules, upgrades, boards another own ship, undocks), and the camera follows
## random objects. Whatever referred to
## a vanished object must cope: no errors at all, and the system keeps going.
##
## Run from the project folder (exit code 0 when everything passes):
##   godot --headless --path . --fixed-fps 60 res://tests/chaos_checks.tscn

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
const RAID_TIME := 40.0
const SCAVENGER_TIME := 100.0
const AGING_EVERY := 10.0
## The player's ship rarely lives long enough to fly to a station, so every so often it is put
## into one, to use the station from there.
const VISIT_EVERY := 30.0
## The system must still have ships out in space during this many last seconds of the run.
## (Not on the last tick only: by then removals have thinned the system out, and the last
## removal may take the last ship.)
const ALIVE_WINDOW := 30.0
const STATION_REMOVAL_TIME := 150.0
const KINDS: Array[String] = [
	"ship destroyed", "ship removed", "docked ship removed", "drone", "rock", "wreck", "container",
	"player's ship destroyed", "escape pod", "gate", "station",
]

var _rng := RandomNumberGenerator.new()
var _removed := {}  # kind -> count
## Commands the "player" gave while docked, and ships it boarded.
var _station_uses := 0
var _boarded := 0
var _system: Node3D
var _controller: PlayerController
var _camera: OrbitCamera


func _ready() -> void:
	_rng.seed = 2024
	_system = load("res://scenes/systems/home_system.tscn").instantiate()
	var invasion := _system.get_node("Invasion") as Invasion
	invasion.event_seed = 3
	add_child(_system)
	_controller = _system.get_node("PlayerController")
	_camera = _system.get_node("Camera")
	var spawner := _system.get_node("TrafficSpawner") as TrafficSpawner
	var salvage := _system.get_node("SalvageService") as SalvageService
	var raids := _system.get_node("PirateRaids") as PirateRaids
	raids.auto = false
	var raiders_seen := 0
	var next_aging := SCAVENGER_TIME
	for i in PIRATES:
		_spawn_pirate(i + 1)

	var step := 1.0 / Engine.physics_ticks_per_second
	var time := 0.0
	var next_removal := 2.0
	var next_command := 1.0
	var next_visit := VISIT_EVERY
	var late_ships := 0
	var arrivals_at_gate_removal := -1
	var docked_at_removed_station: Array[Ship] = []
	while time < RUN_TIME:
		await get_tree().physics_frame
		time += step
		if time >= next_command:
			next_command += COMMAND_EVERY
			_command()
		if time >= RUN_TIME - ALIVE_WINDOW:
			late_ships = maxi(late_ships, get_tree().get_node_count_in_group(Autopilot.SHIP_GROUP))
		if time >= next_visit:
			next_visit += VISIT_EVERY
			_visit_station()
		if time >= next_removal:
			next_removal = time + _rng.randf_range(REMOVE_EVERY.x, REMOVE_EVERY.y)
			_remove_something()
		if invasion.invaders_arrived == 0 and not invasion.is_running() and time >= INVASION_TIME:
			invasion.start()
		if raids.raids == 0 and time >= RAID_TIME:
			raids.start()
		raiders_seen = maxi(raiders_seen, raids.raiders().size())
		if salvage.scavengers_launched == 0 and time >= next_aging:
			next_aging += AGING_EVERY
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
	_check(_station_uses > 0, "the player used stations (%d commands, %d ships boarded)" % [_station_uses, _boarded])
	_check(invasion.invaders_arrived > 0, "the invasion happened (%d invaders came)" % invasion.invaders_arrived)
	_check(raiders_seen > 0, "the pirate raid happened (up to %d raiders at once)" % raiders_seen)
	_check(salvage.scavengers_launched > 0, "the scavenger went out (%d)" % salvage.scavengers_launched)
	_check(late_ships > 0, "the system keeps going (up to %d ships in space in the last %.0f s)"
			% [late_ships, ALIVE_WINDOW])
	# Last, so that errors in the checks above count too.
	_finish()


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
		"player's ship destroyed": in_space.filter(func(node: Node) -> bool:
			return node == _controller.ship and not (node as Ship).is_pod),
		"escape pod": in_space.filter(func(node: Node) -> bool: return (node as Ship).is_pod),
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
	if kind in ["ship destroyed", "drone", "player's ship destroyed", "escape pod"]:
		(node as Ship).take_hit(1000.0, null)
	else:
		node.queue_free()
	_removed[kind] = _removed.get(kind, 0) + 1


## The "player": select something, give an order about it, sometimes point the camera at it;
## once on the way to dock, waits until docked; while docked, uses the station. Gets a new ship
## when there is none at all (pod included).
func _command() -> void:
	if _controller.ship == null:
		var ship := PlayerShipScene.instantiate() as Ship
		var where := Vector3(_rng.randf_range(-500, 500), 300, _rng.randf_range(-500, 500))
		ship.enter_space(_system.get_node("Ships"), Transform3D(Basis.IDENTITY, where))
		_controller.ship = ship
		_camera.target = ship
	if _controller.is_docked():
		_use_station()
		return
	if _controller.ship.current_order is DockOrder:
		return
	var candidates := get_tree().get_nodes_in_group(Autopilot.SHIP_GROUP) \
			+ get_tree().get_nodes_in_group(Autopilot.OBSTACLE_GROUP)
	var target := candidates[_rng.randi() % candidates.size()] as Node3D
	_controller.select(target)
	match _rng.randi() % 9:
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
			if not cargo.is_empty():  # An escape pod has no hold.
				_controller.jettison(cargo.items()[0], 1)
		6:
			var stations := get_tree().get_nodes_in_group(Autopilot.OBSTACLE_GROUP).filter(
					func(node: Node) -> bool: return node is Station)
			if not stations.is_empty():
				_controller.select(stations[_rng.randi() % stations.size()])
				_controller.dock_selected()
		7:
			var rocks := (_system.get_node("AsteroidField") as AsteroidField).get_rocks()
			if not rocks.is_empty():
				_controller.select(rocks[_rng.randi() % rocks.size()])
				_controller.mine_selected()
		8:
			_controller.use_module(_rng.randi() % 3)
	if _rng.randf() < 0.3:
		_camera.target = target


## Puts the player's ship into a random station, if it is out in space.
func _visit_station() -> void:
	var stations := get_tree().get_nodes_in_group(Autopilot.OBSTACLE_GROUP).filter(
			func(node: Node) -> bool: return node is Station)
	if _controller.has_ship() and not stations.is_empty():
		_controller.ship.dock_instantly(stations[_rng.randi() % stations.size()])


## Docked: sell, repair, upgrade, buy a module, board another own ship docked here, or undock.
func _use_station() -> void:
	_controller.credits += 1000
	_station_uses += 1
	match _rng.randi() % 6:
		0:
			_controller.sell_cargo()
		1:
			_controller.repair_ship()
		2:
			_controller.upgrade_ship()
		3:
			var here := _controller.ships_here()
			if not here.is_empty():
				_controller.board(here[_rng.randi() % here.size()])
				_boarded += 1
		4:
			_controller.undock()
		5:
			var types := StationServices.modules()
			_controller.buy_module(types[_rng.randi() % types.size()])


func _spawn_pirate(number: int) -> void:
	var ship := PirateRaids.create_pirate("Pirate %d" % number)
	var where := Vector3(_rng.randf_range(-1500, 1500), _rng.randf_range(-200, 200), _rng.randf_range(-1500, 1500))
	ship.enter_space(_system.get_node("Ships"), Transform3D(Basis.IDENTITY, where))
