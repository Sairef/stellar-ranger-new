@tool
class_name AsteroidField
extends Node3D

## A field of asteroids generated from a seed inside an ellipsoid volume.
##
## Rocks keep `min_gap` between their surfaces. It is wider than two avoidance bubbles, so the
## autopilot never merges neighbouring rocks into one blob and ships can thread through the field.
## Rocks are generated children (not saved with the scene); change the seed for a new layout.

@export var field_seed := 1:
	set(value):
		field_seed = value
		_queue_rebuild()
@export var count := 60:
	set(value):
		count = maxi(value, 0)
		_queue_rebuild()
## Semi-axes of the ellipsoid the rocks are placed in, in meters.
@export var extents := Vector3(900, 250, 700):
	set(value):
		extents = value
		_queue_rebuild()
@export var min_radius := 12.0:
	set(value):
		min_radius = value
		_queue_rebuild()
@export var max_radius := 70.0:
	set(value):
		max_radius = value
		_queue_rebuild()
## Minimum gap between rock surfaces, in meters.
@export var min_gap := 80.0:
	set(value):
		min_gap = value
		_queue_rebuild()
@export var rock_color := Color(0.42, 0.39, 0.36):
	set(value):
		rock_color = value
		_queue_rebuild()

## Placement tries per requested rock before giving up (the field may come out smaller).
const ATTEMPTS_PER_ROCK := 100


func _ready() -> void:
	_rebuild()


func _queue_rebuild() -> void:
	if is_node_ready():
		_rebuild()


func _rebuild() -> void:
	for child in get_children():
		if child.has_meta(&"generated"):
			remove_child(child)
			child.queue_free()

	var rng := RandomNumberGenerator.new()
	rng.seed = field_seed
	var placed: Array[Dictionary] = []
	var attempts := 0
	while placed.size() < count and attempts < count * ATTEMPTS_PER_ROCK:
		attempts += 1
		var point := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))
		if point.length_squared() > 1.0:
			continue
		point *= extents
		# Mostly small rocks with a few big ones.
		var rock_radius := lerpf(min_radius, max_radius, pow(rng.randf(), 2.5))
		if _fits(point, rock_radius, placed):
			placed.append({"position": point, "radius": rock_radius})

	for i in placed.size():
		var asteroid := Asteroid.new()
		asteroid.display_name = "Rock %d" % (i + 1)
		asteroid.show_label = false
		asteroid.radius = placed[i]["radius"]
		asteroid.shape_seed = field_seed * 1000 + i
		asteroid.rock_color = rock_color.darkened(rng.randf_range(0.0, 0.3))
		asteroid.position = placed[i]["position"]
		asteroid.set_meta(&"generated", true)
		add_child(asteroid)


func _fits(point: Vector3, rock_radius: float, placed: Array[Dictionary]) -> bool:
	for rock in placed:
		var gap := point.distance_to(rock["position"]) - rock_radius - float(rock["radius"])
		if gap < min_gap:
			return false
	return true
