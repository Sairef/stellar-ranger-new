class_name NavGoal
extends RefCounted

## One tick of intent produced by an order: where the ship should fly and how.
## The Autopilot turns it into an actual velocity, avoiding obstacles and traffic.

## Point in global space to fly toward.
var point: Vector3
## If true, the autopilot brakes to stop at `point`. If false, it flies on at full speed.
var arrive: bool
## Node excluded from obstacle checks, usually the order's own target.
var ignore: Node3D
## Speed limit for this goal in m/s. The ship's own max speed still applies.
var speed: float


func _init(p_point: Vector3, p_arrive := true, p_ignore: Node3D = null, p_speed := INF) -> void:
	point = p_point
	arrive = p_arrive
	ignore = p_ignore
	speed = p_speed
