class_name StationServices
extends RefCounted

## What a station does for a docked ship, for credits (the one galactic currency): buys the
## cargo, repairs the armor (the shield recharges by itself), sells modules (ShipModule) and
## upgrades the ship to the next class (ShipClass.next()). Every station offers everything for
## now. The caller keeps the money: functions take a budget and return what was earned or spent.
##
## Prices are placeholders, but their size matters: they are set so that in the first hour a pilot
## buys a module within minutes, a medium ship in about twenty and a large one by the end of it
## (see docs/concept.md, "Third milestone"). Playtests can skip the earning with the debug panel.

## Credits for one piece of any item.
const SELL_PRICE := 1
## Credits for one point of armor.
const REPAIR_PRICE := 3
## Credits for an upgrade to each class.
const UPGRADE_PRICES := {
	ShipClass.Size.MEDIUM: 1500,
	ShipClass.Size.LARGE: 4000,
}
## Credits for each module (see modules()).
const AFTERBURNER_PRICE := 400
const SHIELD_BOOSTER_PRICE := 500


## Credits the hold would fetch.
static func cargo_value(ship: Ship) -> int:
	return ship.cargo.total() * SELL_PRICE


## Empties the hold. Returns the credits it fetched.
static func sell_cargo(ship: Ship) -> int:
	var value := cargo_value(ship)
	ship.cargo.clear()
	return value


## Credits for a full repair.
static func repair_cost(ship: Ship) -> int:
	return ceili(ship.armor_damage() * REPAIR_PRICE)


## Repairs as much armor as `budget` pays for. Returns the credits spent.
static func repair(ship: Ship, budget: int) -> int:
	var cost := mini(repair_cost(ship), maxi(budget, 0))
	if cost <= 0:
		return 0
	ship.repair(float(cost) / REPAIR_PRICE)
	return cost


## The class an upgrade would make of the ship, or CUSTOM if it cannot be upgraded.
static func upgrade_class(ship: Ship) -> ShipClass.Size:
	return ShipClass.next(ship.ship_class)


## Credits for the ship's upgrade (0 if there is none).
static func upgrade_price(ship: Ship) -> int:
	return UPGRADE_PRICES.get(upgrade_class(ship), 0)


static func can_upgrade(ship: Ship, budget: int) -> bool:
	return upgrade_class(ship) != ShipClass.Size.CUSTOM and budget >= upgrade_price(ship)


## Upgrades the ship to the next class if `budget` pays for it. Returns the credits spent.
static func upgrade(ship: Ship, budget: int) -> int:
	if not can_upgrade(ship, budget):
		return 0
	var price := upgrade_price(ship)
	ship.set_ship_class(upgrade_class(ship))
	return price


## Module types for sale; a ship carries at most one module of each type.
static func modules() -> Array[Script]:
	return [Afterburner, ShieldBooster]


## Credits for a module of `type`, 0 if it is not for sale.
static func module_price(type: Script) -> int:
	if type == Afterburner:
		return AFTERBURNER_PRICE
	if type == ShieldBooster:
		return SHIELD_BOOSTER_PRICE
	return 0


static func can_buy_module(ship: Ship, type: Script, budget: int) -> bool:
	return type in modules() and ship.find_part(type) == null and budget >= module_price(type)


## Fits a new module of `type` to the ship if `budget` pays for it and the ship has none of that
## type yet. Returns the credits spent.
static func buy_module(ship: Ship, type: Script, budget: int) -> int:
	if not can_buy_module(ship, type, budget):
		return 0
	ship.add_child(type.new())
	return module_price(type)
