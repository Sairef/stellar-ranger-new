class_name ShieldBooster
extends ShipModule

## Pushes a burst of energy into the shield: restores `restore` of the maximum shield at once.
## Useless while the shield is full. Placeholder numbers.

## Part of the maximum shield restored.
var restore := 0.35


func _init() -> void:
	title = "Shield booster"
	energy_cost = 50.0
	cooldown = 3.0
	sound = &"shield_boost"


func _is_useful(on: Ship) -> bool:
	return on.shield < on.max_shield


func _start(on: Ship) -> void:
	on.charge_shield(on.max_shield * restore)
