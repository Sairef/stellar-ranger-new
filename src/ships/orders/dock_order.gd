class_name DockOrder
extends EnterCorridorOrder

## Fly to a station, wait for a free docking port and dock: the ship disappears inside the
## station until it undocks (Ship.try_undock()).


func get_label() -> String:
	return "Dock at %s%s" % [Autopilot.name_of(structure), _phase_suffix()]


func _on_inside(ship: Ship) -> void:
	ship.dock(structure, corridor)
