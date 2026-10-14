extends "res://tests/support/check_suite.gd"

## Headless checks for the player's loop around stations: the shield recharging by itself,
## docking (D) and undocking, what a station sells and buys (StationServices: cargo, repairs,
## modules, an upgrade to the next class), NPC ships repaired for free, boarding another own ship,
## mining with a mining ship (F), and the escape pod that gets a new ship at a station (the lost
## ship's class and modules are gone).
## Run from the project folder (exit code 0 when everything passes):
##   godot --headless --path . --fixed-fps 60 res://tests/station_checks.tscn

const ShipScene := preload("res://src/ships/ship.tscn")
const PlayerShipScene := preload("res://src/ships/player_ship.tscn")
const PlayerMinerScene := preload("res://src/ships/player_miner.tscn")
const StationScene := preload("res://src/world/station.tscn")
const AsteroidScene := preload("res://src/world/asteroid.tscn")


func _ready() -> void:
	await _shield_recharge()
	await _dock_and_services()
	await _buying_modules()
	await _npc_free_repairs()
	await _boarding()
	await _mining()
	await _escape_pod()
	_finish()


# --- Scenarios -------------------------------------------------------------------------------

func _shield_recharge() -> void:
	_begin("The shield recharges by itself, the armor does not")
	var ship := _spawn(ShipScene, Vector3.ZERO)
	await get_tree().physics_frame
	var step := ship.max_shield * Ship.SHIELD_REGEN_FRACTION
	ship.shield = ship.max_shield - 3.0 * step
	ship.armor = ship.max_armor - 5.0
	await _wait(Ship.SHIELD_REGEN_INTERVAL + 0.1)
	_check(is_equal_approx(ship.shield, ship.max_shield - 2.0 * step),
			"+%.0f%% after %.0f s (%.1f of %.0f)" % [Ship.SHIELD_REGEN_FRACTION * 100.0,
			Ship.SHIELD_REGEN_INTERVAL, ship.shield, ship.max_shield])
	await _wait(Ship.SHIELD_REGEN_INTERVAL * 3.0)
	_check(ship.shield == ship.max_shield, "never above the maximum (%.1f)" % ship.shield)
	_check(ship.armor == ship.max_armor - 5.0, "the armor stays damaged (%.1f)" % ship.armor)
	await _end()


func _dock_and_services() -> void:
	_begin("The player docks, sells, repairs, upgrades and undocks")
	var station := _spawn_station()
	var ship := _spawn(PlayerShipScene, Vector3(0, 0, 700))
	var controller := _spawn_controller(ship)
	_check(ship.ship_class == ShipClass.Size.SMALL, "the player starts in a small ship")
	controller.select(station)
	controller.dock_selected()
	var time := await _simulate(120.0, func() -> bool: return controller.is_docked())
	_check(time > 0.0 and controller.docked_station() == station,
			"D docks at the selected station (%.0f s)" % time)
	_check(not controller.has_ship(), "a docked ship takes no orders")

	ship.cargo.add(Items.LOOT_1, 3)
	ship.cargo.add(Items.ORE, 4)
	controller.sell_cargo()
	_check(controller.credits == 7 * StationServices.SELL_PRICE and ship.cargo.is_empty(),
			"selling empties the hold for %d cr (%d)" % [7 * StationServices.SELL_PRICE, controller.credits])

	var price := StationServices.REPAIR_PRICE
	ship.armor -= 5.0
	controller.credits = 3 * price
	controller.repair_ship()
	_check(controller.credits == 0 and is_equal_approx(ship.armor, ship.max_armor - 2.0),
			"%d cr repair 3 of 5 armor points (armor %.1f / %.0f)" % [3 * price, ship.armor, ship.max_armor])
	controller.credits = 150
	controller.repair_ship()
	_check(controller.credits == 150 - 2 * price and ship.armor == ship.max_armor,
			"the rest costs %d cr (%d left)" % [2 * price, controller.credits])

	var small_radius := ship.radius
	var small_hold := ship.cargo.capacity
	var to_medium: int = StationServices.UPGRADE_PRICES[ShipClass.Size.MEDIUM]
	var to_large: int = StationServices.UPGRADE_PRICES[ShipClass.Size.LARGE]
	ship.shield = ship.max_shield * 0.5
	controller.credits = to_medium - 1
	controller.upgrade_ship()
	_check(ship.ship_class == ShipClass.Size.SMALL and controller.credits == to_medium - 1,
			"an upgrade the credits do not pay for does not happen")
	controller.credits = to_medium + 100
	controller.upgrade_ship()
	_check(ship.ship_class == ShipClass.Size.MEDIUM and controller.credits == 100,
			"the upgrade makes it medium for %d cr" % to_medium)
	_check(ship.radius == small_radius * 2.0 and ship.cargo.capacity == small_hold * 2.0
			and ship.max_armor == ShipClass.stats(ShipClass.Size.MEDIUM).armor,
			"bigger, tougher, with a bigger hold (radius %.0f, hold %.0f)" % [ship.radius, ship.cargo.capacity])
	_check(is_equal_approx(ship.shield, ship.max_shield * 0.5), "damage stays in proportion")
	controller.credits = to_large
	controller.upgrade_ship()
	_check(ship.ship_class == ShipClass.Size.LARGE and controller.credits == 0,
			"the next one makes it large for %d cr" % to_large)
	controller.credits = 10000
	controller.upgrade_ship()
	_check(ship.ship_class == ShipClass.Size.LARGE and controller.credits == 10000, "there is nothing above large")

	controller.undock()
	time = await _simulate(30.0, func() -> bool: return controller.has_ship())
	_check(time > 0.0 and not controller.is_docked(), "Undock takes the ship out (%.1f s)" % time)
	await _end()


func _buying_modules() -> void:
	_begin("Modules for sale: one of each type, for credits, and keys 1, 2 switch them on")
	var station := _spawn_station()
	var ship := _spawn(PlayerShipScene, Vector3(0, 0, 700))
	var controller := _spawn_controller(ship)
	await get_tree().physics_frame
	ship.dock_instantly(station)
	var afterburner := StationServices.module_price(Afterburner)
	var booster := StationServices.module_price(ShieldBooster)
	_check(StationServices.modules() == [Afterburner, ShieldBooster] and afterburner > 0 and booster > 0,
			"the station sells an afterburner (%d cr) and a shield booster (%d cr)" % [afterburner, booster])
	controller.credits = afterburner - 1
	controller.buy_module(Afterburner)
	_check(ship.get_modules().is_empty() and controller.credits == afterburner - 1, "not without the credits")
	controller.credits = afterburner + booster + 10
	controller.buy_module(Afterburner)
	controller.buy_module(Afterburner)
	_check(ship.get_modules().size() == 1 and controller.credits == booster + 10,
			"an afterburner, and only one (%d cr left)" % controller.credits)
	controller.buy_module(ShieldBooster)
	var modules := ship.get_modules()
	_check(modules.size() == 2 and modules[0] is Afterburner and modules[1] is ShieldBooster
			and controller.credits == 10, "then a shield booster: keys 1 and 2, in the order bought")
	_check(not modules[0].can_activate(), "modules do not work while docked")
	ship.set_ship_class(ShipClass.Size.MEDIUM)
	_check(ship.get_modules().size() == 2, "an upgrade keeps the modules")

	controller.undock()
	await _simulate(30.0, func() -> bool: return controller.has_ship())
	var top := ship.top_speed()
	_check(controller.use_module(0) and ship.top_speed() > top,
			"out in space, key 1 fires the afterburner (%.0f -> %.0f m/s)" % [top, ship.top_speed()])
	_check(not controller.use_module(1), "key 2: the booster refuses a full shield")
	_check(not controller.use_module(5), "a key with no module does nothing")
	await _end()


func _npc_free_repairs() -> void:
	_begin("NPC ships are repaired for free when they dock")
	var station := _spawn_station()
	var ship := _spawn(ShipScene, Vector3(0, 0, 700))
	await get_tree().physics_frame
	ship.armor = 1.0
	ship.dock_instantly(station)
	_check(ship.armor == ship.max_armor, "armor %.0f / %.0f" % [ship.armor, ship.max_armor])
	var player := _spawn(PlayerShipScene, Vector3(0, 0, -700))
	await get_tree().physics_frame
	player.armor = 1.0
	player.dock_instantly(station, 1)
	_check(player.armor == 1.0, "the player's ships are not (they pay)")
	await _end()


func _boarding() -> void:
	_begin("Boarding another own ship docked at the same station")
	var station := _spawn_station()
	var combat := _spawn(PlayerShipScene, Vector3(0, 0, 700))
	var miner := _spawn(PlayerMinerScene, Vector3(0, 0, -700))
	var elsewhere := _spawn(PlayerMinerScene, Vector3(2000, 0, 0))
	var controller := _spawn_controller(combat)
	controller.fleet = [miner, elsewhere]
	await get_tree().physics_frame
	_check(controller.fleet.size() == 3 and controller.ship == combat, "the fleet: three ships, flying the combat one")
	_check(controller.ships_here().is_empty(), "nothing to board out in space")
	combat.dock_instantly(station, 0)
	miner.dock_instantly(station, 1)
	_check(controller.ships_here() == [miner], "docked: the miner is here, the other miner is not")
	controller.board(elsewhere)
	_check(controller.ship == combat, "a ship that is not here cannot be boarded")
	controller.board(miner)
	_check(controller.ship == miner and combat.is_docked() and controller.ships_here() == [combat],
			"boarded the miner; the combat ship stays docked")
	await _end()


func _mining() -> void:
	_begin("Only a mining ship mines (F), and its ore sells")
	var station := _spawn_station()
	var rock := AsteroidScene.instantiate() as Asteroid
	rock.radius = 40.0
	rock.enter_space(_world, Vector3(0, 0, 900))
	var combat := _spawn(PlayerShipScene, Vector3(200, 0, 700))
	var controller := _spawn_controller(combat)
	controller.select(rock)
	_check(not controller.can_mine_selected(), "the combat ship cannot mine")
	combat.give_order(MineOrder.new(rock))
	await _wait(1.0)
	_check(combat.current_order == null and combat.cargo.is_empty(), "a mine order ends at once for it")

	var miner := _spawn(PlayerMinerScene, Vector3(-200, 0, 700))
	controller.ship = miner
	controller.select(rock)
	_check(controller.can_mine_selected(), "the mining ship can")
	controller.mine_selected()
	var time := await _simulate(60.0, func() -> bool: return miner.cargo.count(Items.ORE) >= 10)
	_check(time > 0.0, "it mines ore (%d after %.0f s)" % [miner.cargo.count(Items.ORE), time])
	_check(not miner.is_armed(), "it carries no weapon")
	var laser := miner.get_mining_laser()
	var small_fill := miner.cargo.capacity / laser.mining_rate()
	var big := _spawn(PlayerMinerScene, Vector3(-200, 0, 500))
	big.set_ship_class(ShipClass.Size.LARGE)
	var big_fill := big.cargo.capacity / big.get_mining_laser().mining_rate()
	_check(big.cargo.capacity == miner.cargo.capacity * 4.0 and is_equal_approx(big_fill, small_fill),
			"a large one holds 4 times more and fills it just as fast (%.0f s for %.0f, %.0f s for %.0f)"
			% [small_fill, miner.cargo.capacity, big_fill, big.cargo.capacity])
	var ore := miner.cargo.total()
	miner.dock_instantly(station)
	controller.sell_cargo()
	_check(controller.credits == ore * StationServices.SELL_PRICE, "the ore sells (%d cr)" % controller.credits)
	await _end()


func _escape_pod() -> void:
	_begin("A destroyed ship leaves an escape pod; the pod gets a new ship at a station")
	var station := _spawn_station()
	var ship := _spawn(PlayerShipScene, Vector3(0, 0, 900))
	var controller := _spawn_controller(ship)
	var miner := _spawn(PlayerMinerScene, Vector3(0, 0, -700))
	controller.fleet = [miner]
	controller.credits = 42
	ship.cargo.add(Items.LOOT_1, 2)
	var lost := {"title": ""}
	controller.ship_lost.connect(func(title: String) -> void: lost.title = title)
	var pirate := _spawn(ShipScene, Vector3(0, 0, 1100))
	pirate.faction = Factions.PIRATE
	pirate.get_weapon().enabled = false
	await get_tree().physics_frame
	ship.set_ship_class(ShipClass.Size.MEDIUM)
	ship.add_child(Afterburner.new())
	var wreck_at := ship.global_position
	ship.take_hit(1000.0, pirate)
	var pod := controller.ship
	_check(pod != null and pod.is_pod and pod.is_in_space(), "the pilot flies the escape pod (%s)" % pod)
	if pod == null:
		await _end()
		return
	_check(pod.global_position.distance_to(wreck_at) < 40.0, "right next to the wreck")
	_check(lost.title == "Combat ship (medium)", "the HUD hears of the loss (%s)" % lost.title)
	controller.select(pirate)
	_check(not controller.can_attack_selected(), "the pod cannot attack")
	_check(not pod.is_armed() and pod.max_speed < ship.max_speed * 0.5, "unarmed and slow (%.0f m/s)" % pod.max_speed)
	var wreck: Wreck = null
	for node in get_tree().get_nodes_in_group(Wreck.GROUP):
		wreck = node as Wreck
	_check(wreck != null and wreck.cargo.count(Items.LOOT_1) >= 2, "the cargo stays in the wreck")
	pirate.get_weapon().enabled = true
	_check(pirate.get_weapon().choose_target() == null, "weapons do not pick the pod")
	await get_tree().process_frame
	_check(controller.fleet == [miner, pod], "the lost ship is gone from the fleet (%s)" % [controller.fleet])

	controller.select(station)
	controller.dock_selected()
	var time := await _simulate(150.0, func() -> bool: return controller.is_docked())
	var replacement := controller.ship
	_check(time > 0.0 and replacement != null and not replacement.is_pod and replacement.docked_at == station,
			"docked: the station gives a new ship (%.0f s)" % time)
	await get_tree().process_frame
	_check(not is_instance_valid(pod), "the pod is gone")
	_check(replacement != null and replacement.ship_class == ShipClass.Size.SMALL and replacement.is_armed()
			and replacement.get_modules().is_empty(), "a small combat ship, no modules: the lost class and modules are gone")
	_check(controller.credits == 42, "the credits stay with the pilot")
	_check(controller.fleet.size() == 2 and miner in controller.fleet, "the miner is still owned")
	await _end()


# --- Helpers ---------------------------------------------------------------------------------

func _spawn(scene: PackedScene, position: Vector3) -> Ship:
	var ship := scene.instantiate() as Ship
	ship.enter_space(_world, Transform3D(Basis.IDENTITY, position))
	return ship


func _spawn_station() -> SpaceBody:
	var station := StationScene.instantiate() as SpaceBody
	station.display_name = "Depot"
	_world.add_child(station)
	return station


func _spawn_controller(ship: Ship) -> PlayerController:
	var camera := Camera3D.new()
	camera.far = 60000.0
	_world.add_child(camera)
	camera.position = Vector3(0, 300, 1600)
	var controller := PlayerController.new()
	controller.ship = ship
	controller.camera = camera
	_world.add_child(controller)
	return controller
