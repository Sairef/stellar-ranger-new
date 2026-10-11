class_name JumpOrder
extends EnterCorridorOrder

## Fly into a gate and jump out of the system: the ship is gone.


func get_label() -> String:
	return "Jump through %s%s" % [Autopilot.name_of(structure), _phase_suffix()]


func _on_inside(ship: Ship) -> void:
	ship.jump_out(structure as Gate, corridor)
