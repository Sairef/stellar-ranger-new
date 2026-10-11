class_name MineOrder
extends ShipOrder

## Hold position next to a rock, nose toward it, and mine with the beam until the hold is full.
## Mining only happens while the ship is (almost) stopped.

## Cargo units mined per second.
const MINING_RATE := 4.0
const MINING_MAX_SPEED := 2.0

var rock: Node3D
## Gap between the hull and the rock surface, in meters.
var distance: float


func _init(p_rock: Node3D, p_distance := 25.0) -> void:
	rock = p_rock
	distance = p_distance


func get_label() -> String:
	return "Mining %s" % Autopilot.name_of(rock)


func get_target() -> Node3D:
	return rock


func update(ship: Ship, delta: float) -> void:
	if not is_instance_valid(rock) or ship.speed > MINING_MAX_SPEED:
		ship.beam_target = null
		return
	ship.cargo = minf(ship.cargo_capacity, ship.cargo + MINING_RATE * delta)
	# Aim at the visible surface (the rock mesh is dented inward from its radius).
	var to_ship := (ship.global_position - rock.global_position).normalized()
	ship.beam_target = rock.global_position + to_ship * Autopilot.radius_of(rock) * 0.8


func get_goal(ship: Ship) -> NavGoal:
	var away := (ship.global_position - rock.global_position).normalized()
	var stand_off := Autopilot.radius_of(rock) + ship.radius + distance
	var goal := NavGoal.new(rock.global_position + away * stand_off, true, rock)
	goal.face_point = rock.global_position
	return goal


func is_complete(ship: Ship) -> bool:
	return not is_instance_valid(rock) or ship.cargo >= ship.cargo_capacity
