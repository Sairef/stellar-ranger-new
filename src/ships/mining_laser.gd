class_name MiningLaser
extends Node

## A mining laser, placed as a child of a Ship: only ships with one can mine (MineOrder).
## Mining ships carry it instead of a weapon. The beam itself is drawn by the ship
## (Ship.beam_target).
## A bigger ship mines faster in proportion to its bigger hold (ShipClass.cargo_factor()), so a
## hold of any class fills in the same time: an upgrade never makes mining slower, it only brings
## more ore per trip.

## Pieces of ore mined per second by a small ship (or one without a class).
@export var rate := 4.0


## Pieces of ore per second on the ship carrying the laser.
func mining_rate() -> float:
	var ship := get_parent() as Ship
	return rate * ShipClass.cargo_factor(ship.ship_class) if ship != null else rate
