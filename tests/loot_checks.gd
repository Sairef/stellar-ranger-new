extends "res://tests/support/check_suite.gd"

## Headless checks for loot: cargo holds, wrecks, drones, loot orders, the cargo window and
## the system scavenger.
## Run from the project folder (exit code 0 when everything passes):
##   godot --headless --path . --fixed-fps 60 res://tests/loot_checks.tscn

const ShipScene := preload("res://src/ships/ship.tscn")
const PlayerShipScene := preload("res://src/ships/player_ship.tscn")
const AsteroidScene := preload("res://src/world/asteroid.tscn")
const StationScene := preload("res://src/world/station.tscn")


func _ready() -> void:
	_cargo_holds()
	await _target_priority()
	await _wreck_contents()
	await _loot_one_wreck()
	await _loot_all_in_radius()
	await _full_hold()
	await _things_vanish_while_looting()
	await _scavenger()
	await _scavenger_destroyed()
	_finish()


# --- Scenarios -------------------------------------------------------------------------------

func _cargo_holds() -> void:
	print("\n== Cargo holds pieces up to its capacity")
	var hold := Cargo.new(10.0)
	_check(hold.add(Items.LOOT_1, 7) == 7, "7 pieces go in")
	_check(hold.add(Items.ORE, 5) == 3, "then only 3 more fit into 10")
	_check(hold.room() == 0.0 and hold.total() == 10, "the hold is full (%d)" % hold.total())
	_check(hold.remove(Items.LOOT_1, 9) == 7 and hold.items() == [Items.ORE], "taking out more than there is takes all")
	var other := Cargo.new()
	other.add(Items.LOOT_1, 3)
	other.add(Items.LOOT_2, 4)
	var moved := other.move_to(hold, 5)
	_check(moved == 5 and hold.count(Items.LOOT_1) == 3 and hold.count(Items.LOOT_2) == 2 and other.count(Items.LOOT_2) == 2,
			"moving stops at the limit (%s | %s)" % [hold.describe(), other.describe()])


func _target_priority() -> void:
	_begin("Weapons pick armed targets before drones")
	var pirate := _spawn_ship("Pirate", Vector3.ZERO, Factions.PIRATE)
	var drone := _spawn_ship("Drone", Vector3(0, 0, -100), Factions.PLAYER, true)
	var fighter := _spawn_ship("Fighter", Vector3(0, 0, -500), Factions.PLAYER)
	await get_tree().physics_frame
	var weapon := pirate.get_weapon()
	_check(weapon.choose_target() == fighter, "the armed ship further away comes first (%s)"
			% Autopilot.name_of(weapon.choose_target()))
	fighter.get_weapon().enabled = false
	_check(weapon.choose_target() == drone, "with no threat in range the drone is shot (%s)"
			% Autopilot.name_of(weapon.choose_target()))
	await _end()


func _wreck_contents() -> void:
	_begin("Wrecks keep the cargo plus placeholder loot; empty drones leave nothing")
	var stats := {"wrecks": {}}
	var record := func(ship: Ship, wreck: Wreck) -> void:
		stats.wrecks[ship.display_name] = wreck.cargo.describe() if wreck != null else "none"
	var loaded := _spawn_ship("Loaded drone", Vector3(0, 0, 0), Factions.PLAYER, true)
	loaded.cargo.add(Items.ORE, 5)
	var empty := _spawn_ship("Empty drone", Vector3(0, 0, -200), Factions.PLAYER, true)
	var fighter := _spawn_ship("Fighter", Vector3(0, 0, -400), Factions.INVADER)
	fighter.cargo.add(Items.ORE, 4)
	for ship: Ship in [loaded, empty, fighter]:
		ship.destroyed.connect(record)
		ship.take_hit(1000.0, null)
	_check(stats.wrecks["Loaded drone"] == "Ore x5", "a loaded drone leaves its load and no loot (%s)"
			% stats.wrecks["Loaded drone"])
	_check(stats.wrecks["Empty drone"] == "none", "an empty drone leaves no wreck")
	_check(stats.wrecks["Fighter"] == "Ore x4, Loot 1 x3, Loot 2 x2", "a ship leaves its cargo plus loot (%s)"
			% stats.wrecks["Fighter"])
	await _end()


func _loot_one_wreck() -> void:
	_begin("Loot one wreck: the ship comes closer, a drone brings everything")
	var ship := _spawn_carrier(Vector3.ZERO)
	var wreck := _make_wreck("Target wreck", Vector3(0, 0, -1500), {Items.LOOT_1: 3, Items.LOOT_2: 2})
	var wreck_ref := ObjectRef.to(wreck)
	var order := LootOrder.new([wreck])
	ship.give_order(order)
	var stats := {"closest": INF}
	var probe := func() -> void:
		stats.closest = minf(stats.closest, ship.global_position.distance_to(Vector3(0, 0, -1500)))
	var time := await _simulate(120.0, func() -> bool: return ship.current_order == null, probe)
	_check(time > 0.0, "the order is done in %.1f s" % time)
	_check(ship.cargo.count(Items.LOOT_1) == 3 and ship.cargo.count(Items.LOOT_2) == 2,
			"the hold has it all (%s)" % ship.cargo.describe())
	_check(wreck_ref.resolve() == null, "the emptied wreck is gone")
	var bay: DroneBay = ship.get_drone_bay()
	_check(bay.drones_out().is_empty() and bay.drones == 3, "all drones are back (%d out)" % bay.drones_out().size())
	_check(stats.closest < bay.drone_range + 100.0, "the ship came within drone range (%.0f m)" % stats.closest)
	_check(ship.collision_ticks == 0, "no physical contacts (%d ticks)" % ship.collision_ticks)
	await _end()


func _loot_all_in_radius() -> void:
	_begin("Loot all: every wreck in the radius, around a rock, but not our own container")
	var ship := _spawn_carrier(Vector3.ZERO)
	ship.cargo.add(Items.ORE, 2)
	var own_container := ship.jettison(Items.ORE, 2)
	var rock := AsteroidScene.instantiate() as Asteroid
	rock.radius = 60.0
	rock.position = Vector3(0, 0, -600)
	_world.add_child(rock)
	var inside: Array[ObjectRef] = []
	for spot: Vector3 in [Vector3(0, 0, -1200), Vector3(150, 20, -1300), Vector3(2000, 50, 500), Vector3(-1500, -40, 1800)]:
		inside.append(ObjectRef.to(_make_wreck("Wreck", spot, {Items.LOOT_1: 1, Items.LOOT_2: 1})))
	var far := _make_wreck("Far wreck", Vector3(6000, 0, 0), {Items.LOOT_1: 1})
	ship.give_order(LootOrder.around(Vector3.ZERO, 5000.0))
	var time := await _simulate(300.0, func() -> bool: return ship.current_order == null)
	_check(time > 0.0, "the order is done in %.1f s" % time)
	_check(inside.all(func(ref: ObjectRef) -> bool: return ref.resolve() == null), "every wreck in the radius is emptied")
	_check(ship.cargo.count(Items.LOOT_1) == 4 and ship.cargo.count(Items.LOOT_2) == 4,
			"the hold has their contents (%s)" % ship.cargo.describe())
	_check(is_instance_valid(far) and far.cargo.count(Items.LOOT_1) == 1, "the wreck outside the radius is untouched")
	_check(is_instance_valid(own_container) and own_container.cargo.count(Items.ORE) == 2,
			"our own dropped container is left alone")
	_check(ship.collision_ticks == 0, "no physical contacts (%d ticks)" % ship.collision_ticks)
	await _end()


func _full_hold() -> void:
	_begin("Full hold: the cargo window opens; dropped items stay out of Loot all")
	var ship := _spawn_carrier(Vector3.ZERO)
	ship.cargo_capacity = 20.0
	var controller := _spawn_controller(ship)
	controller.loot_radius = 3000.0
	var hud := Hud.new()
	hud.controller = controller
	_world.add_child(hud)
	var wrecks: Array[ObjectRef] = [
		ObjectRef.to(_make_wreck("Pile 1", Vector3(0, 0, -900), {Items.LOOT_1: 16})),
		ObjectRef.to(_make_wreck("Pile 2", Vector3(100, 0, -1000), {Items.LOOT_2: 12})),
	]
	var far := _make_wreck("Far wreck", Vector3(0, 0, 4000), {Items.LOOT_1: 1})
	var stats := {"full": 0}
	controller.hold_full.connect(func() -> void: stats.full += 1)

	controller.loot_all()
	var time := await _simulate(120.0, func() -> bool: return stats.full > 0)
	_check(time > 0.0, "looting stops on a full hold (%.1f s, %s)" % [time, ship.cargo.describe()])
	_check(ship.cargo.total() <= 20, "the hold never overflows (%d / 20)" % ship.cargo.total())
	_check(wrecks.any(func(ref: ObjectRef) -> bool: return ref.resolve() != null), "the rest stays in the wrecks")
	var window := _find_cargo_window(hud)
	_check(window != null and window.visible, "the cargo window opens")
	var near := wrecks.filter(func(ref: ObjectRef) -> bool: return ref.resolve() != null)
	_check((near[0].resolve() as Wreck).inspected and not far.inspected,
			"the ship knows what is in wrecks nearby, not in the far one")

	var dropped: int = ship.cargo.count(Items.LOOT_1)
	controller.jettison(Items.LOOT_1, dropped)
	var containers := get_children().filter(func(node: Node) -> bool: return node is Wreck and node.is_container)
	_check(containers.size() == 1 and (containers[0] as Wreck).cargo.count(Items.LOOT_1) == dropped,
			"dropped loot goes into a container behind the ship (%d)" % dropped)
	await _simulate(1.0, func() -> bool: return false)
	controller.loot_all()
	time = await _simulate(120.0, func() -> bool: return ship.current_order == null)
	_check(time > 0.0 and wrecks.all(func(ref: ObjectRef) -> bool: return ref.resolve() == null),
			"Loot all again collects the rest (%.1f s, %s)" % [time, ship.cargo.describe()])
	_check(is_instance_valid(containers[0]) and (containers[0] as Wreck).cargo.count(Items.LOOT_1) == dropped,
			"but not the dropped container")
	_check(stats.full == 1, "no second full-hold stop (%d)" % stats.full)
	await _end()


func _things_vanish_while_looting() -> void:
	_begin("Wrecks and the mother ship vanish while drones are out")
	var ship := _spawn_carrier(Vector3.ZERO)
	var first := _make_wreck("First", Vector3(0, 0, -400), {Items.LOOT_1: 1})
	_make_wreck("Second", Vector3(200, 0, -450), {Items.LOOT_1: 1})
	ship.give_order(LootOrder.around(Vector3.ZERO, 2000.0))
	var bay: DroneBay = ship.get_drone_bay()
	await _simulate(10.0, func() -> bool: return bay.drones_out().size() >= 2)
	first.queue_free()
	var time := await _simulate(60.0, func() -> bool: return ship.current_order == null)
	_check(time > 0.0 and bay.drones_out().is_empty() and bay.drones == 3,
			"a drone whose wreck vanished comes back, the order ends (%.1f s)" % time)

	_make_wreck("Third", Vector3(0, 0, 500), {Items.LOOT_1: 1})
	ship.give_order(LootOrder.around(Vector3.ZERO, 2000.0))
	await _simulate(10.0, func() -> bool: return not bay.drones_out().is_empty())
	ship.take_hit(1000.0, null)
	await _simulate(1.0, func() -> bool: return false)
	_check(get_tree().get_node_count_in_group(DroneRoutine.GROUP) == 0, "drones of a destroyed ship are gone too")
	await _end()


func _scavenger() -> void:
	_begin("The scavenger collects abandoned wrecks, docks and is gone")
	var service := _spawn_salvage_service()
	var old := [
		ObjectRef.to(_make_wreck("Old wreck", Vector3(1500, 0, 0), {Items.LOOT_1: 2})),
		ObjectRef.to(_make_wreck("Old container", Vector3(1700, 50, 300), {Items.ORE: 10})),
	]
	for ref: ObjectRef in old:
		(ref.resolve() as Wreck).age = service.abandon_time
	var fresh := _make_wreck("Fresh wreck", Vector3(1500, 0, -400), {Items.LOOT_1: 1})
	var time := await _simulate(400.0, func() -> bool:
		return service.scavengers_launched > 0 and service.scavenger == null)
	_check(time > 0.0, "a scavenger came and went in %.1f s" % time)
	_check(old.all(func(ref: ObjectRef) -> bool: return ref.resolve() == null), "it collected the abandoned wrecks")
	_check(is_instance_valid(fresh) and fresh.cargo.count(Items.LOOT_1) == 1, "a fresh wreck is left alone")
	_check(service.scavengers_launched == 1, "one scavenger at a time (%d)" % service.scavengers_launched)
	await _end()


func _scavenger_destroyed() -> void:
	_begin("Destroying the scavenger leaves what it collected in its wreck")
	var service := _spawn_salvage_service()
	var old := _make_wreck("Old wreck", Vector3(1500, 0, 0), {Items.LOOT_2: 3})
	old.age = service.abandon_time
	var time := await _simulate(200.0, func() -> bool:
		var ship := service.scavenger
		return ship != null and ship.cargo.count(Items.LOOT_2) == 3)
	_check(time > 0.0, "the scavenger loaded the wreck (%.1f s)" % time)
	_check(not service.scavenger.is_armed(), "it is unarmed: anyone can take its load")
	var stats := {"parts": 0, "wreck": ""}
	service.scavenger.destroyed.connect(func(_ship: Ship, wreck: Wreck) -> void:
		stats.parts = wreck.cargo.count(Items.LOOT_2)
		stats.wreck = wreck.cargo.describe())
	service.scavenger.take_hit(1000.0, null)
	# Plus its own placeholder loot.
	_check(stats.parts >= 3, "its wreck holds the loot (%s)" % stats.wreck)
	await _end()


# --- Helpers ---------------------------------------------------------------------------------

func _spawn_ship(ship_name: String, position: Vector3, faction: StringName, drone := false) -> Ship:
	var ship := ShipScene.instantiate() as Ship
	ship.display_name = ship_name
	ship.faction = faction
	if drone:
		ship.is_drone = true
		ship.radius = DroneBay.DRONE_RADIUS
		ship.get_weapon().free()
	ship.enter_space(_world, Transform3D(Basis.IDENTITY, position))
	return ship


func _spawn_carrier(position: Vector3) -> Ship:
	var ship := PlayerShipScene.instantiate() as Ship
	ship.enter_space(_world, Transform3D(Basis.IDENTITY, position))
	return ship


func _spawn_controller(ship: Ship) -> PlayerController:
	var camera := Camera3D.new()
	camera.far = 60000.0
	_world.add_child(camera)
	camera.position = Vector3(0, 300, 600)
	var controller := PlayerController.new()
	controller.ship = ship
	controller.camera = camera
	_world.add_child(controller)
	return controller


func _spawn_salvage_service() -> SalvageService:
	var station := StationScene.instantiate() as SpaceBody
	station.display_name = "Depot"
	_world.add_child(station)
	var service := SalvageService.new()
	service.station = station.get_path()
	service.ships_root = _world.get_path()
	service.check_interval = 1.0
	_world.add_child(service)
	return service


## A wreck at `position` holding `items` (item id -> count).
func _make_wreck(wreck_name: String, position: Vector3, items: Dictionary) -> Wreck:
	var wreck := Wreck.new()
	wreck.display_name = wreck_name
	wreck.radius = 8.0
	for item: StringName in items:
		wreck.cargo.add(item, items[item])
	wreck.enter_space(_world, position)
	return wreck


func _find_cargo_window(hud: Hud) -> CargoWindow:
	for child in hud.get_children():
		if child is CargoWindow:
			return child
	return null
