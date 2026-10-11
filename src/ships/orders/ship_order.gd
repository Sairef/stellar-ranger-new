class_name ShipOrder
extends RefCounted

## Base class for everything a ship can be told to do.
##
## The player and the AI use exactly the same orders (design pillar "Same rules for everyone").
## An order only decides *where* to go each tick; the Autopilot decides *how* to get there safely.


## Human-readable description for UI and logs.
func get_label() -> String:
	return "Order"


## The object this order is about, if any. Excluded from the ship's obstacle checks.
func get_target() -> Node3D:
	return null


## Called every physics tick. Returns where the ship should go, or null to brake and hold position.
func get_goal(_ship: Ship) -> NavGoal:
	return null


## True when the order is finished (or can no longer be carried out) and the ship should drop it.
func is_complete(_ship: Ship) -> bool:
	return false
