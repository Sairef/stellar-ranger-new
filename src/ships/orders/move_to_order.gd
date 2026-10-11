class_name MoveToOrder
extends ShipOrder

## Fly to a point in space and stop there.

const ARRIVE_DISTANCE := 5.0
const ARRIVE_SPEED := 2.0

var point: Vector3


func _init(p_point: Vector3) -> void:
	point = p_point


func get_label() -> String:
	return "Move to (%.0f, %.0f, %.0f)" % [point.x, point.y, point.z]


func get_goal(_ship: Ship) -> NavGoal:
	return NavGoal.new(point)


func is_complete(ship: Ship) -> bool:
	return ship.global_position.distance_to(point) < ARRIVE_DISTANCE and ship.speed < ARRIVE_SPEED
