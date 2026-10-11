extends Node

## Headless navigation scenarios for the autopilot.
##
## Run from the project folder (exit code 0 when everything passes):
##   godot --headless --path . --fixed-fps 60 res://tests/nav_scenarios.tscn
## --fixed-fps disables real-time sync, so a minute of flight takes a fraction of a second.
## Set the environment variable NAV_DIAG=1 to also print every contact between ships and
## every order change in the traffic scenarios.

const ShipScene := preload("res://src/ships/ship.tscn")
const AsteroidScene := preload("res://src/world/asteroid.tscn")

## Physics keeps hulls from overlapping, so a ship scraping along a rock shows a gap of ~0.
## "Never touched" therefore means a clearly positive gap.
const MIN_GAP := 1.0

var _world: Node3D
var _passed := 0
var _failed := 0


func _ready() -> void:
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
	await _home_system_soak()
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


## The real main scene with all its NPC traffic, while the player flies through the asteroid field.
func _home_system_soak() -> void:
	_begin("Home system: 180 s of traffic, the player crosses the asteroid field")
	var system: Node3D = load("res://scenes/systems/home_system.tscn").instantiate()
	_world.add_child(system)
	var player := system.get_node("Ships/PlayerShip") as Ship
	var arrival := {"done": false}
	player.order_changed.connect(func(order: ShipOrder) -> void:
		if order == null:
			arrival.done = true)
	player.give_order(MoveToOrder.new(Vector3(-2200, -100, 3500)))

	var ships: Array[Ship] = []
	for node in system.get_node("Ships").get_children():
		ships.append(node as Ship)
	var obstacles := get_tree().get_nodes_in_group(Autopilot.OBSTACLE_GROUP)
	await _expect_no_traffic_accident(ships, 180.0, obstacles, false)
	_check(arrival.done, "the player crossed the asteroid field")


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
	_world.add_child(asteroid)
	asteroid.global_position = position
	return asteroid


func _spawn_ship(ship_name: String, position: Vector3, facing: Vector3) -> Ship:
	var ship := ShipScene.instantiate() as Ship
	ship.display_name = ship_name
	_world.add_child(ship)
	ship.global_position = position
	ship.look_at(position + facing, Vector3.UP)
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
