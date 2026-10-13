extends Node

## Headless navigation scenarios for the autopilot.
##
## Run from the project folder (exit code 0 when everything passes):
##   godot --headless --path . --fixed-fps 60 res://tests/nav_scenarios.tscn
## --fixed-fps disables real-time sync, so a minute of flight takes a fraction of a second.
## Set the environment variable NAV_DIAG=1 to also print every physical contact (what hit what),
## near misses between ships and every order change in the traffic scenarios.

const ErrorLog := preload("res://tests/support/error_log.gd")
const ShipScene := preload("res://src/ships/ship.tscn")
const AsteroidScene := preload("res://src/world/asteroid.tscn")
const StationScene := preload("res://src/world/station.tscn")
const GateScene := preload("res://src/world/gate.tscn")

## Physics keeps hulls from overlapping, so a ship scraping along a rock shows a gap of ~0.
## "Never touched" therefore means a clearly positive gap.
const MIN_GAP := 1.0

var _world: Node3D
var _errors := ErrorLog.new()
var _passed := 0
var _failed := 0


func _ready() -> void:
	OS.add_logger(_errors)
	await _detour_around_big_asteroid(Vector3.ZERO)
	await _detour_around_big_asteroid(Vector3(0, 12, 0))
	await _detour_around_big_asteroid(Vector3(0, 0, -25))
	await _detour_through_cluster()
	await _head_on()
	await _crossing()
	await _orbit_holds_distance()
	await _orbit_ship_next_to_asteroid(Vector3(103, 0, 300), Vector3.LEFT, "from the side", true)
	await _orbit_ship_next_to_asteroid(Vector3(-300, 0, 0), Vector3.RIGHT, "from behind the rock")
	await _move_into_asteroid()
	await _busy_traffic()
	await _through_asteroid_field()
	await _dock_and_undock()
	await _shared_docking_port()
	await _jump_through_gate(Vector3(200, 50, -900), "from the front")
	await _jump_through_gate(Vector3(300, 0, 900), "from behind")
	await _gate_arrival()
	await _target_leaves_the_system()
	await _approach_ship_flying_past()
	await _miner_cycle()
	await _home_system_soak()
	_check(_errors.errors.is_empty(), "no errors during the run %s" % _errors.errors)
	print("\n%d passed, %d failed" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


# --- Scenarios -------------------------------------------------------------------------------

## The basic case: three asteroids on one line, the middle one is big.
## A ship next to the first one must reach the third one by flying around the middle one.
func _detour_around_big_asteroid(start_offset: Vector3) -> void:
	_begin("Detour A -> C around big B, start offset %s" % start_offset)
	_spawn_asteroid("A", Vector3(-700, 0, 0), 35)
	var big := _spawn_asteroid("B", Vector3.ZERO, 90)
	var goal := _spawn_asteroid("C", Vector3(700, 0, 0), 35)
	var ship := _spawn_ship("Tester", Vector3(-610, 0, 0) + start_offset, Vector3.RIGHT)
	ship.give_order(ApproachOrder.new(goal, 50.0, true))

	var stats := {"gap": INF}
	var probe := func() -> void:
		stats.gap = minf(stats.gap, _gap(ship, big))
	var time: float = await _simulate(60.0, func() -> bool: return ship.current_order == null, probe)

	_check(time > 0.0, "arrived at C in %.1f s" % time)
	_check(stats.gap > MIN_GAP, "never touched B (closest hull gap %.1f m)" % stats.gap)
	_check(ship.collision_ticks == 0, "no physical contacts (%d ticks)" % ship.collision_ticks)
	await _end()


## The tangent around the first blocker leads straight into a second rock.
func _detour_through_cluster() -> void:
	_begin("Detour around a cluster of rocks")
	var rocks: Array[Asteroid] = [
		_spawn_asteroid("B1", Vector3(0, 0, 0), 70),
		_spawn_asteroid("B2", Vector3(40, 0, 150), 60),
		_spawn_asteroid("B3", Vector3(-30, 20, -140), 55),
	]
	var goal := _spawn_asteroid("C", Vector3(700, 0, 0), 35)
	var ship := _spawn_ship("Tester", Vector3(-600, 0, 0), Vector3.RIGHT)
	ship.give_order(ApproachOrder.new(goal, 50.0, true))

	var stats := {"gap": INF}
	var probe := func() -> void:
		for rock in rocks:
			stats.gap = minf(stats.gap, _gap(ship, rock))
	var time: float = await _simulate(60.0, func() -> bool: return ship.current_order == null, probe)

	_check(time > 0.0, "arrived at C in %.1f s" % time)
	_check(stats.gap > MIN_GAP, "never touched the cluster (closest hull gap %.1f m)" % stats.gap)
	_check(ship.collision_ticks == 0, "no physical contacts (%d ticks)" % ship.collision_ticks)
	await _end()


## Two ships fly straight at each other to swap places.
func _head_on() -> void:
	_begin("Head-on: two ships swap places")
	var east := _spawn_ship("East", Vector3(-400, 0, 0), Vector3.RIGHT)
	var west := _spawn_ship("West", Vector3(400, 0, 0), Vector3.LEFT)
	east.give_order(MoveToOrder.new(Vector3(400, 0, 0)))
	west.give_order(MoveToOrder.new(Vector3(-400, 0, 0)))
	await _expect_no_traffic_accident([east, west], 30.0)


## Two ships cross paths at a right angle and would meet exactly in the middle.
func _crossing() -> void:
	_begin("Crossing: two ships meet at a right angle")
	var a := _spawn_ship("A", Vector3(-400, 0, 0), Vector3.RIGHT)
	var b := _spawn_ship("B", Vector3(0, 0, -400), Vector3.BACK)
	a.give_order(MoveToOrder.new(Vector3(400, 0, 0)))
	b.give_order(MoveToOrder.new(Vector3(0, 0, 400)))
	await _expect_no_traffic_accident([a, b], 30.0)


func _orbit_holds_distance() -> void:
	_begin("Orbit keeps its distance")
	var center := _spawn_asteroid("B", Vector3.ZERO, 90)
	var ship := _spawn_ship("Tester", Vector3(0, 0, 300), Vector3.RIGHT)
	ship.give_order(OrbitOrder.new(center, 100.0))
	var expected := center.radius + ship.radius + 100.0

	# Let the ship settle into the orbit, then measure.
	await _simulate(15.0, func() -> bool: return false, func() -> void: pass)
	var stats := {"min": INF, "max": 0.0}
	var probe := func() -> void:
		var r := ship.global_position.distance_to(center.global_position)
		stats.min = minf(stats.min, r)
		stats.max = maxf(stats.max, r)
	await _simulate(20.0, func() -> bool: return false, probe)

	_check(stats.min > expected * 0.85 and stats.max < expected * 1.15,
			"radius stays within 15%% of %.0f m (%.0f .. %.0f m)" % [expected, stats.min, stats.max])
	_check(ship.collision_ticks == 0, "no physical contacts (%d ticks)" % ship.collision_ticks)
	await _end()


## Bug report: orbiting a ship parked next to an asteroid made the orbiting ship scrape the rock,
## because the orbit stayed in the plane the ship had been flying in. The orbit must tilt instead.
func _orbit_ship_next_to_asteroid(start: Vector3, facing: Vector3, title: String,
		natural_plane_blocked := false) -> void:
	_begin("Orbit a ship parked next to an asteroid, " + title)
	var rock := _spawn_asteroid("Rock", Vector3.ZERO, 35)
	var parked := _spawn_ship("Parked", Vector3(103, 0, 0), Vector3.LEFT)
	var ship := _spawn_ship("Tester", start, facing)
	var orbit_radius := parked.radius + ship.radius + 100.0
	if natural_plane_blocked:
		var natural := (start - parked.global_position).cross(facing).normalized()
		var clearance := Autopilot.circle_clearance(parked.global_position, natural, orbit_radius,
				ship.radius, [rock])
		_check(clearance < 0.0, "precondition: the flat orbit cuts the rock's bubble (%.0f m)" % clearance)
	ship.give_order(OrbitOrder.new(parked, 100.0))

	var stats := {"gap": INF, "min": INF, "max": 0.0}
	var settle := func() -> void:
		stats.gap = minf(stats.gap, _gap(ship, rock))
	await _simulate(25.0, func() -> bool: return false, settle)
	var measure := func() -> void:
		stats.gap = minf(stats.gap, _gap(ship, rock))
		var r := ship.global_position.distance_to(parked.global_position)
		stats.min = minf(stats.min, r)
		stats.max = maxf(stats.max, r)
	await _simulate(20.0, func() -> bool: return false, measure)

	_check(stats.gap > MIN_GAP, "never touched the rock (closest hull gap %.1f m)" % stats.gap)
	_check(stats.min > orbit_radius * 0.85 and stats.max < orbit_radius * 1.15,
			"orbit radius stays within 15%% of %.0f m (%.0f .. %.0f m)" % [orbit_radius, stats.min, stats.max])
	_check(ship.collision_ticks == 0, "no physical contacts (%d ticks)" % ship.collision_ticks)
	await _end()


## A clicked point can end up inside a rock. The ship must stop next to it, not scrape it.
func _move_into_asteroid() -> void:
	_begin("Move to a point inside an asteroid")
	var rock := _spawn_asteroid("Rock", Vector3.ZERO, 60)
	var ship := _spawn_ship("Tester", Vector3(-400, 0, 0), Vector3.RIGHT)
	ship.give_order(MoveToOrder.new(Vector3(10, 0, 0)))

	var stats := {"gap": INF}
	var probe := func() -> void:
		stats.gap = minf(stats.gap, _gap(ship, rock))
	await _simulate(30.0, func() -> bool: return false, probe)

	_check(stats.gap > MIN_GAP, "never touched the rock (closest hull gap %.1f m)" % stats.gap)
	_check(ship.speed < 3.0, "came to a stop next to the rock (speed %.1f m/s)" % ship.speed)
	_check(ship.collision_ticks == 0, "no physical contacts (%d ticks)" % ship.collision_ticks)
	await _end()


## Soak test: a small version of the sandbox with patrols in both directions and an orbiter.
func _busy_traffic() -> void:
	_begin("Busy traffic: patrols both ways plus an orbiter, 90 s")
	var a := _spawn_asteroid("A", Vector3(-700, 0, 0), 35)
	var b := _spawn_asteroid("B", Vector3.ZERO, 90)
	var c := _spawn_asteroid("C", Vector3(700, 0, 0), 35)
	var ships: Array[Ship] = [
		_spawn_ship("P1", Vector3(-620, 0, 30), Vector3.RIGHT),
		_spawn_ship("P2", Vector3(620, 0, -30), Vector3.LEFT),
		_spawn_ship("P3", Vector3(-640, 40, -60), Vector3.RIGHT),
		_spawn_ship("P4", Vector3(640, -30, 60), Vector3.LEFT),
		_spawn_ship("Orbiter", Vector3(0, 0, 220), Vector3.RIGHT),
	]
	_add_routine(ships[0], NpcRoutine.Mode.PATROL, [c, a])
	_add_routine(ships[1], NpcRoutine.Mode.PATROL, [a, c])
	_add_routine(ships[2], NpcRoutine.Mode.PATROL, [c, a])
	_add_routine(ships[3], NpcRoutine.Mode.PATROL, [a, c])
	_add_routine(ships[4], NpcRoutine.Mode.ORBIT, [b])
	await _expect_no_traffic_accident(ships, 90.0, [a, b, c], false)


## Rocks in a field are spaced so the ship can thread between them instead of going around.
func _through_asteroid_field() -> void:
	_begin("Fly straight through an asteroid field")
	var field := AsteroidField.new()
	field.field_seed = 7
	field.count = 60
	field.extents = Vector3(700, 200, 500)
	_world.add_child(field)
	var rocks := field.get_children().filter(func(node: Node) -> bool: return node is Asteroid)
	var ship := _spawn_ship("Tester", Vector3(-1000, 0, 0), Vector3.RIGHT)
	ship.give_order(MoveToOrder.new(Vector3(1000, 0, 0)))

	var stats := {"gap": INF}
	var probe := func() -> void:
		for rock: Node3D in rocks:
			stats.gap = minf(stats.gap, _gap(ship, rock))
	var time: float = await _simulate(90.0, func() -> bool: return ship.current_order == null, probe)

	_check(rocks.size() >= 40, "the field has %d rocks" % rocks.size())
	_check(time > 0.0 and time < 30.0, "crossed the field without a long detour (%.1f s)" % time)
	_check(stats.gap > MIN_GAP, "never touched a rock (closest hull gap %.1f m)" % stats.gap)
	_check(ship.collision_ticks == 0, "no physical contacts (%d ticks)" % ship.collision_ticks)
	await _end()


## A ship docks at a station through a corridor, disappears inside and later undocks.
func _dock_and_undock() -> void:
	_begin("Dock at a station and undock")
	var station := _spawn_station("Station", Vector3.ZERO, 220.0, Station.Style.TRADE)
	var ship := _spawn_ship("Tester", Vector3(700, 100, 300), Vector3.LEFT)
	ship.give_order(DockOrder.new(station))

	var time: float = await _simulate(90.0, func() -> bool: return ship.is_docked(), _no_probe)
	_check(time > 0.0, "docked in %.1f s" % time)
	_check(not ship.visible and not ship.is_in_group(Autopilot.SHIP_GROUP),
			"a docked ship is hidden and out of traffic")
	_check(ship.try_undock(), "undocked")
	time = await _simulate(30.0, func() -> bool: return ship.current_order == null, _no_probe)
	_check(time > 0.0, "flew out of the station in %.1f s" % time)
	_check(ship.collision_ticks == 0, "no physical contacts (%d ticks)" % ship.collision_ticks)
	await _end()


## Two ships want the same docking port at the same time: one waits for the other.
func _shared_docking_port() -> void:
	_begin("Two ships, one docking port")
	var station := _spawn_station("Station", Vector3.ZERO, 220.0, Station.Style.TRADE)
	var first := _spawn_ship("First", Vector3(600, 0, 250), Vector3.LEFT)
	var second := _spawn_ship("Second", Vector3(620, 0, 320), Vector3.LEFT)
	first.give_order(DockOrder.new(station))
	second.give_order(DockOrder.new(station))
	var stats := {"gap": INF}
	var probe := func() -> void:
		if not first.is_docked() and not second.is_docked():
			stats.gap = minf(stats.gap, _gap(first, second))
	var time: float = await _simulate(150.0,
			func() -> bool: return first.is_docked() and second.is_docked(), probe)

	_check(time > 0.0, "both docked in %.1f s" % time)
	_check(first.dock_corridor == second.dock_corridor,
			"through the same port (%d and %d)" % [first.dock_corridor, second.dock_corridor])
	_check(stats.gap > MIN_GAP, "ships never touched (closest hull gap %.1f m)" % stats.gap)
	_check(first.collision_ticks + second.collision_ticks == 0, "no physical contacts")
	await _end()


## A departing ship flies into the gate from its own side and leaves the system.
func _jump_through_gate(start: Vector3, title: String) -> void:
	_begin("Jump through a gate, " + title)
	var gate := _spawn_gate("Gate", Vector3.ZERO, Vector3(0, 0, -1000))
	var ship := _spawn_ship("Tester", start, Vector3.RIGHT)
	var stats := {"jumped": false, "contacts": 0}
	ship.jumped.connect(func(_gate: Gate) -> void:
		stats.jumped = true
		stats.contacts = ship.collision_ticks)
	ship.give_order(JumpOrder.new(gate))
	var time: float = await _simulate(90.0, func() -> bool: return stats.jumped, _no_probe)

	_check(time > 0.0, "jumped out in %.1f s" % time)
	_check(stats.contacts == 0, "no physical contacts (%d ticks)" % stats.contacts)
	await _end()


## Arrivals come out of the gate membrane one at a time and clear the corridor.
func _gate_arrival() -> void:
	_begin("Arrival through a gate")
	var gate := _spawn_gate("Gate", Vector3.ZERO, Vector3(0, 0, -1000))
	var ship := ShipScene.instantiate() as Ship
	_check(gate.try_receive(ship, _world), "the gate lets a ship in")
	var second := ShipScene.instantiate() as Ship
	_check(not gate.try_receive(second, _world), "the throat takes one ship at a time")
	var time: float = await _simulate(20.0, func() -> bool: return ship.current_order == null, _no_probe)

	_check(time > 0.0, "the ship cleared the gate in %.1f s" % time)
	_check(ship.global_position.z < -gate.radius, "it came out of the front side")
	_check(gate.try_receive(second, _world), "the throat is free again")
	_check(ship.collision_ticks == 0, "no physical contacts (%d ticks)" % ship.collision_ticks)
	await _end()


## Bug report: approaching a trader that then jumped out of the system crashed the game
## (the HUD asked the order for its label, and the label looked up the freed target).
func _target_leaves_the_system() -> void:
	_begin("Approach and orbit a ship that jumps out")
	var gate := _spawn_gate("Gate", Vector3.ZERO, Vector3(0, 0, -1000))
	var leaver := _spawn_ship("Leaver", Vector3(200, 0, -700), Vector3.FORWARD)
	var chaser := _spawn_ship("Chaser", Vector3(-250, 0, -900), Vector3.RIGHT)
	var orbiter := _spawn_ship("Orbiter", Vector3(450, 0, -900), Vector3.LEFT)
	leaver.give_order(JumpOrder.new(gate))
	chaser.give_order(ApproachOrder.new(leaver, 50.0))
	orbiter.give_order(OrbitOrder.new(leaver, 150.0))
	var stats := {"gone": false}
	leaver.tree_exited.connect(func() -> void: stats.gone = true)
	await _simulate(90.0, func() -> bool: return stats.gone, _no_probe)

	# First frame after the target is freed: the orders still hold it, as the HUD would see them.
	var labels := "%s | %s" % [chaser.get_order_label(), orbiter.get_order_label()]
	_check(stats.gone, "the target jumped out")
	_check(labels == "Approach - | Orbit - at 150 m", "order labels survive a freed target (%s)" % labels)
	await _simulate(0.5, func() -> bool: return false, _no_probe)
	_check(chaser.current_order == null and orbiter.current_order == null, "both orders ended")
	_check(chaser.collision_ticks + orbiter.collision_ticks == 0, "no physical contacts")
	await _end()


## Approach a miner that flies back and forth along a line next to the ship, so it passes by
## again and again. The ship must not back off from it (turning tail and then turning back
## looked silly): it stays and keeps its nose on the miner. Turns build up and die down instead
## of starting and stopping at once.
func _approach_ship_flying_past() -> void:
	_begin("Approach a ship that flies back and forth past us")
	var ship := _spawn_ship("Tester", Vector3.ZERO, Vector3.FORWARD)
	var ends: Array[Vector3] = [Vector3(600, 0, -80), Vector3(-600, 0, -80)]
	var miner := _spawn_ship("Miner", ends[1], Vector3.RIGHT)
	miner.radius = 10.0
	miner.max_speed = 80.0
	miner.acceleration = 25.0
	miner.turn_rate = 1.0
	miner.give_order(MoveToOrder.new(ends[0]))
	ship.give_order(ApproachOrder.new(miner, 50.0))

	var step := 1.0 / Engine.physics_ticks_per_second
	var stats := {"leg": 0, "rotation": ship.global_basis.get_rotation_quaternion(), "rate": 0.0,
			"ramp": 0.0, "tail": 0}
	var probe := func() -> void:
		if miner.current_order == null:
			stats.leg = 1 - stats.leg
			miner.give_order(MoveToOrder.new(ends[stats.leg]))
		var rotation := ship.global_basis.get_rotation_quaternion()
		var previous: Quaternion = stats.rotation
		var turn := rotation * previous.inverse()
		var rate := 2.0 * atan2(Vector3(turn.x, turn.y, turn.z).length(), absf(turn.w)) / step
		stats.ramp = maxf(stats.ramp, absf(rate - stats.rate) / step)
		stats.rotation = rotation
		stats.rate = rate
		var to_miner := miner.global_position - ship.global_position
		if _gap(ship, miner) < 80.0 and ship.get_forward().angle_to(to_miner) > PI / 2.0:
			stats.tail += 1
	await _simulate(30.0, func() -> bool: return false, probe)

	var max_ramp := ship.turn_rate / Ship.TURN_RAMP_TIME
	_check(stats.tail == 0, "it never turns its back on the miner nearby (%d ticks)" % stats.tail)
	_check(stats.ramp <= max_ramp * 1.1, "turns build up and die down: at most %.1f rad/s2 (limit %.1f)"
			% [stats.ramp, max_ramp])
	_check(ship.collision_ticks + miner.collision_ticks == 0, "no physical contacts")
	await _end()


## A miner undocks, fills its hold at a rock in the field, flies home and docks.
func _miner_cycle() -> void:
	_begin("Miner: undock, mine, come home, dock")
	var station := _spawn_station("Home", Vector3.ZERO, 220.0, Station.Style.TRADE)
	var field := AsteroidField.new()
	field.field_seed = 3
	field.count = 25
	field.extents = Vector3(400, 150, 300)
	field.position = Vector3(1500, 0, 0)
	_world.add_child(field)
	var ship := ShipScene.instantiate() as Ship
	ship.display_name = "Miner"
	_world.add_child(ship)
	_watch_contacts(ship)
	var routine := MinerRoutine.new()
	routine.home = station.get_path()
	routine.field = field.get_path()
	routine.start_docked_for = 0.5
	ship.add_child(routine)

	var stats := {"docks": 0, "cargo": 0.0, "rock_gap": INF}
	ship.docked.connect(func(_station: SpaceBody) -> void: stats.docks += 1)
	var rocks := field.get_rocks()
	var probe := func() -> void:
		stats.cargo = maxf(stats.cargo, ship.cargo.total())
		if ship.visible:
			for rock in rocks:
				stats.rock_gap = minf(stats.rock_gap, _gap(ship, rock))
	# The first dock is the start-docked one; the second means a full trip.
	var time: float = await _simulate(300.0, func() -> bool: return stats.docks >= 2, probe)

	_check(time > 0.0, "came home after a trip in %.1f s" % time)
	_check(is_equal_approx(stats.cargo, ship.cargo_capacity), "filled the hold (%.0f)" % stats.cargo)
	_check(stats.rock_gap > MIN_GAP, "never touched a rock (closest hull gap %.1f m)" % stats.rock_gap)
	_check(ship.collision_ticks == 0, "no physical contacts (%d ticks)" % ship.collision_ticks)
	await _end()


## The real main scene with all its traffic: traders docking, arriving and jumping out, miners,
## patrols, while the player flies through the asteroid field. Ships come and go, so they are
## collected every tick.
func _home_system_soak() -> void:
	_begin("Home system: 300 s of traffic, the player crosses the asteroid field")
	var system: Node3D = load("res://scenes/systems/home_system.tscn").instantiate()
	_world.add_child(system)
	var player := system.get_node("Ships/PlayerShip") as Ship
	var stats := {"crossed": false, "ship_gap": INF, "rock_gap": INF, "miner_docks": 0}
	player.order_changed.connect(func(order: ShipOrder) -> void:
		if order == null:
			stats.crossed = true)
	player.give_order(MoveToOrder.new(Vector3(-2200, -100, 3500)))
	for node in get_tree().get_nodes_in_group(MinerRoutine.GROUP):
		(node as Ship).docked.connect(func(_station: SpaceBody) -> void: stats.miner_docks += 1)

	var rocks := (system.get_node("AsteroidField") as AsteroidField).get_rocks()
	var contacts := {}  # Ship -> collision ticks, kept after the ship jumps out.
	var probe := func() -> void:
		var ships := get_tree().get_nodes_in_group(Autopilot.SHIP_GROUP)
		for i in ships.size():
			var ship := ships[i] as Ship
			if not contacts.has(ship):
				_watch_contacts(ship)
			contacts[ship] = ship.collision_ticks
			for j in range(i + 1, ships.size()):
				stats.ship_gap = minf(stats.ship_gap, _gap(ship, ships[j]))
			for rock in rocks:
				stats.rock_gap = minf(stats.rock_gap, _gap(ship, rock))
	await _simulate(300.0, func() -> bool: return false, probe)

	var spawner := system.get_node("TrafficSpawner") as TrafficSpawner
	var total_contacts := 0
	for ticks: int in contacts.values():
		total_contacts += ticks
	_check(stats.ship_gap > MIN_GAP, "ships never touched (closest hull gap %.1f m)" % stats.ship_gap)
	_check(stats.rock_gap > MIN_GAP, "ships never touched rocks (closest hull gap %.1f m)" % stats.rock_gap)
	_check(total_contacts == 0, "no physical contacts among %d ships (%d ticks)" % [contacts.size(), total_contacts])
	_check(spawner.arrivals > 0 and spawner.departures > 0,
			"traffic flows through gates (%d in, %d out)" % [spawner.arrivals, spawner.departures])
	# Four start-docked docks, then one per finished trip.
	_check(stats.miner_docks >= 6, "miners finished trips (%d)" % (stats.miner_docks - 4))
	_check(stats.crossed, "the player crossed the asteroid field")
	await _end()


# --- Helpers ---------------------------------------------------------------------------------

func _expect_no_traffic_accident(ships: Array[Ship], seconds: float, rocks: Array = [],
		expect_arrival := true) -> void:
	var stats := {"ship_gap": INF, "rock_gap": INF}
	if OS.get_environment("NAV_DIAG") != "":
		for ship in ships:
			ship.order_changed.connect(func(order: ShipOrder) -> void:
				var nearest := INF
				var nearest_name := ""
				for other in ships:
					if other != ship and _gap(ship, other) < nearest:
						nearest = _gap(ship, other)
						nearest_name = other.display_name
				print("    %s -> %s at %s, nearest %s gap %.1f" % [ship.display_name,
						order.get_label() if order else "done", ship.global_position.round(),
						nearest_name, nearest]))
	var probe := func() -> void:
		for i in ships.size():
			for j in range(i + 1, ships.size()):
				var gap := _gap(ships[i], ships[j])
				if gap < 0.0 and OS.get_environment("NAV_DIAG") != "":
					print("    contact %s / %s gap %.1f | %s | %s | speeds %.1f %.1f | %s %s" % [
						ships[i].display_name, ships[j].display_name, gap,
						ships[i].get_order_label(), ships[j].get_order_label(),
						ships[i].speed, ships[j].speed,
						ships[i].global_position.round(), ships[j].global_position.round()])
				stats.ship_gap = minf(stats.ship_gap, gap)
			for rock in rocks:
				stats.rock_gap = minf(stats.rock_gap, _gap(ships[i], rock))
	var all_arrived := func() -> bool:
		return expect_arrival and ships.all(func(s: Ship) -> bool: return s.current_order == null)
	var time: float = await _simulate(seconds, all_arrived, probe)

	if expect_arrival:
		_check(time > 0.0, "all ships arrived in %.1f s" % time)
	_check(stats.ship_gap > MIN_GAP, "ships never touched (closest hull gap %.1f m)" % stats.ship_gap)
	if not rocks.is_empty():
		_check(stats.rock_gap > MIN_GAP, "ships never touched rocks (closest hull gap %.1f m)" % stats.rock_gap)
	var contacts := 0
	for ship in ships:
		contacts += ship.collision_ticks
	_check(contacts == 0, "no physical contacts (%d ticks)" % contacts)
	await _end()


func _begin(title: String) -> void:
	print("\n== %s" % title)
	_world = Node3D.new()
	add_child(_world)


func _end() -> void:
	_world.queue_free()
	_world = null
	await get_tree().physics_frame


func _spawn_asteroid(asteroid_name: String, position: Vector3, radius: float) -> Asteroid:
	var asteroid := AsteroidScene.instantiate() as Asteroid
	asteroid.display_name = asteroid_name
	asteroid.radius = radius
	asteroid.position = position  # Before adding: the world sits at the origin.
	_world.add_child(asteroid)
	return asteroid


func _spawn_station(station_name: String, position: Vector3, radius: float,
		style: Station.Style) -> Station:
	var station := StationScene.instantiate() as Station
	station.display_name = station_name
	station.radius = radius
	station.style = style
	station.position = position
	_world.add_child(station)
	return station


## The gate's front (-Z) faces `front_toward`.
func _spawn_gate(gate_name: String, position: Vector3, front_toward: Vector3) -> Gate:
	var gate := GateScene.instantiate() as Gate
	gate.display_name = gate_name
	gate.transform = Transform3D(Basis.looking_at(front_toward - position, Vector3.UP), position)
	_world.add_child(gate)
	return gate


func _spawn_ship(ship_name: String, position: Vector3, facing: Vector3) -> Ship:
	var ship := ShipScene.instantiate() as Ship
	ship.display_name = ship_name
	ship.enter_space(_world, Transform3D(Basis.looking_at(facing, Vector3.UP), position))
	_watch_contacts(ship)
	return ship


func _add_routine(ship: Ship, mode: NpcRoutine.Mode, targets: Array) -> void:
	var routine := NpcRoutine.new()
	routine.mode = mode
	routine.pause = 1.0
	for target: Node in targets:
		routine.waypoints.append(target.get_path())
	ship.add_child(routine)


## Hull-to-hull (or hull-to-surface) distance between two space objects.
func _gap(a: Node3D, b: Node3D) -> float:
	return a.global_position.distance_to(b.global_position) \
			- Autopilot.radius_of(a) - Autopilot.radius_of(b)


## With NAV_DIAG set, prints every physical contact of the ship.
func _watch_contacts(ship: Ship) -> void:
	if OS.get_environment("NAV_DIAG") == "":
		return
	ship.collided.connect(func(collider: Object) -> void:
		print("    contact: %s hit %s at %s | %s | speed %.1f" % [ship.display_name,
				Autopilot.name_of(collider as Node), ship.global_position.round(),
				ship.get_order_label(), ship.speed]))


func _no_probe() -> void:
	pass


## Advances the simulation until `done` returns true or `timeout` seconds pass.
## Calls `probe` every physics tick. Returns the elapsed time, or -1.0 on timeout.
func _simulate(timeout: float, done: Callable, probe: Callable) -> float:
	var step := 1.0 / Engine.physics_ticks_per_second
	var time := 0.0
	while time < timeout:
		await get_tree().physics_frame
		time += step
		probe.call()
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
