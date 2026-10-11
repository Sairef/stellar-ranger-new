@tool
class_name Wreck
extends SpaceBody

## What is left of a destroyed ship: a few slowly tumbling pieces of debris and its cargo.
## For now the cargo is a single placeholder item called "Loot"; collecting it comes later.
## A wreck is an obstacle like any other: ships fly around it.

@export var contents: Array[String] = ["Loot"]
@export var debris_color := Color(0.3, 0.3, 0.3):
	set(value):
		debris_color = value
		_queue_rebuild()

## Tumbling speed in radians per second (visual only).
const SPIN := 0.2

var _pivot: Node3D
var _spin_axis := Vector3.UP


static func from_ship(ship: Ship) -> Wreck:
	var wreck := Wreck.new()
	wreck.display_name = "Wreck of %s" % ship.display_name
	wreck.radius = ship.radius
	wreck.debris_color = ship.hull_color.darkened(0.6)
	return wreck


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _pivot == null:
		return
	_pivot.rotate(_spin_axis, SPIN * delta)


func _build_visuals() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(display_name)
	_spin_axis = Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
	_pivot = add_generated(Node3D.new())
	var material := make_material(debris_color, 0.5, 0.8)
	var r := radius
	for i in 5:
		var size := Vector3(rng.randf_range(0.2, 0.6), rng.randf_range(0.1, 0.3), rng.randf_range(0.2, 0.7)) * r
		var offset := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * 0.35 * r
		var piece := add_mesh(box(size), material, offset, _pivot)
		piece.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
	add_mesh(sphere(0.08 * r), make_glow_material(Color(1.0, 0.45, 0.15), 3.0), Vector3.ZERO, _pivot)
