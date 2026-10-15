class_name ShipClass
extends RefCounted

## Placeholder ship classes, to see how fleets of ships of different sizes feel.
## Medium is the standard ship from before there were classes. A small ship (a fighter) is 30%
## faster and more agile, but 30% weaker: shield, armor, weapon damage and weapon range. A large
## ship is the other way round: too slow to chase anyone, it hits from farther away. The model
## and the collision sphere grow with the class: a medium ship is twice the size of a small one,
## a large one four times, and so is the hold (the ship's `cargo_capacity` is the hold of its
## small version). Numbers are placeholders, not balance.
## Each class's weapon hits best at its own distance (WEAPON_BANDS, see Weapon): small guns close
## up, big guns farther out, as they cannot follow a target that close. So a fight between
## classes is decided by who gets their distance: the small ship has to get close and stay there,
## the large one has to keep it away.
## A ship takes its class numbers when it enters the tree, or when it is upgraded (see
## Ship.ship_class, Ship.set_ship_class()).

enum Size { CUSTOM, SMALL, MEDIUM, LARGE }

const NAMES := {Size.CUSTOM: "custom", Size.SMALL: "small", Size.MEDIUM: "medium", Size.LARGE: "large"}
const SMALL_RADIUS := 8.0
const SIZE_FACTOR := {Size.SMALL: 1.0, Size.MEDIUM: 2.0, Size.LARGE: 4.0}
## Speed, acceleration and turn rate.
const AGILITY_FACTOR := {Size.SMALL: 1.3, Size.MEDIUM: 1.0, Size.LARGE: 0.7}
## Shield, armor, weapon damage and weapon range.
const POWER_FACTOR := {Size.SMALL: 0.7, Size.MEDIUM: 1.0, Size.LARGE: 1.3}

## The medium (standard) ship.
const SPEED := 120.0
const ACCELERATION := 40.0
const TURN_RATE := 1.5
const SHIELD := 40.0
const ARMOR := 20.0
const DAMAGE := 1.0
const WEAPON_RANGE := 600.0
## Where each class's weapon hits best: the gap between hulls (from, to) in meters with the full
## hit chance, and the share of it left right next to the target (Weapon.best_from, best_to,
## close_share).
const WEAPON_BANDS := {
	Size.SMALL: [0.0, 200.0, 1.0],
	Size.MEDIUM: [250.0, 450.0, 0.2],
	Size.LARGE: [350.0, 650.0, 0.15],
}


static func name_of(size: Size) -> String:
	return NAMES[size]


## A fleet's classes: `small` small ships first, then `medium` medium and `large` large ones.
static func sizes(small: int, medium: int, large: int) -> Array[Size]:
	var result: Array[Size] = []
	for count_and_size: Array in [[small, Size.SMALL], [medium, Size.MEDIUM], [large, Size.LARGE]]:
		for i in count_and_size[0]:
			result.append(count_and_size[1])
	return result


## The next class up (what an upgrade at a station makes of a ship), or CUSTOM if there is none.
static func next(size: Size) -> Size:
	match size:
		Size.SMALL:
			return Size.MEDIUM
		Size.MEDIUM:
			return Size.LARGE
	return Size.CUSTOM


## How many times the hold of the small version a ship of this class holds (1 for CUSTOM).
static func cargo_factor(size: Size) -> float:
	return SIZE_FACTOR.get(size, 1.0)


## The numbers of a class: radius, speed, acceleration, turn_rate, shield, armor, damage,
## weapon_range, best_from, best_to, close_share.
## Empty for CUSTOM (the ship keeps its own numbers).
static func stats(size: Size) -> Dictionary:
	if size == Size.CUSTOM:
		return {}
	var agility: float = AGILITY_FACTOR[size]
	var power: float = POWER_FACTOR[size]
	var band: Array = WEAPON_BANDS[size]
	return {
		"best_from": band[0],
		"best_to": band[1],
		"close_share": band[2],
		"radius": SMALL_RADIUS * SIZE_FACTOR[size],
		"speed": SPEED * agility,
		"acceleration": ACCELERATION * agility,
		"turn_rate": TURN_RATE * agility,
		"shield": SHIELD * power,
		"armor": ARMOR * power,
		"damage": DAMAGE * power,
		"weapon_range": WEAPON_RANGE * power,
	}
