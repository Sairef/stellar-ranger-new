class_name ShipClass
extends RefCounted

## Placeholder ship classes, to see how fleets of ships of different sizes feel.
## Medium is the standard ship from before there were classes. A small ship (a fighter) is 30%
## faster and more agile, but 30% weaker: shield, armor and weapon damage. A large ship is the
## other way round. The model and the collision sphere grow with the class: a medium ship is
## twice the size of a small one, a large one four times. Numbers are placeholders, not balance.
## A ship takes its class numbers when it enters the tree (see Ship.ship_class).

enum Size { CUSTOM, SMALL, MEDIUM, LARGE }

const NAMES := {Size.CUSTOM: "custom", Size.SMALL: "small", Size.MEDIUM: "medium", Size.LARGE: "large"}
const SMALL_RADIUS := 8.0
const SIZE_FACTOR := {Size.SMALL: 1.0, Size.MEDIUM: 2.0, Size.LARGE: 4.0}
## Speed, acceleration and turn rate.
const AGILITY_FACTOR := {Size.SMALL: 1.3, Size.MEDIUM: 1.0, Size.LARGE: 0.7}
## Shield, armor and weapon damage.
const POWER_FACTOR := {Size.SMALL: 0.7, Size.MEDIUM: 1.0, Size.LARGE: 1.3}

## The medium (standard) ship.
const SPEED := 120.0
const ACCELERATION := 40.0
const TURN_RATE := 1.5
const SHIELD := 40.0
const ARMOR := 20.0
const DAMAGE := 1.0


static func name_of(size: Size) -> String:
	return NAMES[size]


## The numbers of a class: radius, speed, acceleration, turn_rate, shield, armor, damage.
## Empty for CUSTOM (the ship keeps its own numbers).
static func stats(size: Size) -> Dictionary:
	if size == Size.CUSTOM:
		return {}
	var agility: float = AGILITY_FACTOR[size]
	var power: float = POWER_FACTOR[size]
	return {
		"radius": SMALL_RADIUS * SIZE_FACTOR[size],
		"speed": SPEED * agility,
		"acceleration": ACCELERATION * agility,
		"turn_rate": TURN_RATE * agility,
		"shield": SHIELD * power,
		"armor": ARMOR * power,
		"damage": DAMAGE * power,
	}
