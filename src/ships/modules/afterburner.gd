class_name Afterburner
extends ShipModule

## Pours extra power into the engines for a few seconds: higher top speed and acceleration
## (Ship.thrust_boost). To catch a ship that runs away, to get out of a fight, or to get somewhere
## sooner. Placeholder numbers.

## Top speed and acceleration multiplier while active.
var boost := 1.6


func _init() -> void:
	title = "Afterburner"
	energy_cost = 40.0
	duration = 6.0
	cooldown = 4.0
	sound = &"afterburner"


func _start(on: Ship) -> void:
	on.thrust_boost = boost


func _stop(on: Ship) -> void:
	on.thrust_boost = 1.0
