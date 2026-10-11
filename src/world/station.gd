@tool
class_name Station
extends SpaceBody

## A space station (placeholder art): central hub, rotating habitat ring and a style-specific
## lower section (docking arms with cargo for trade, armor collar with turrets for military).
## For now it is a big obstacle and an approach target; docking comes later.

enum Style { TRADE, MILITARY }

@export var style := Style.TRADE:
	set(value):
		style = value
		_queue_rebuild()
@export var hull_color := Color(0.55, 0.57, 0.6):
	set(value):
		hull_color = value
		_queue_rebuild()
## Habitat ring spin in radians per second (visual only).
@export var ring_spin := 0.05

const CARGO_COLORS: Array[Color] = [
	Color(0.85, 0.45, 0.15), Color(0.2, 0.55, 0.6), Color(0.7, 0.2, 0.2), Color(0.8, 0.7, 0.2),
]

var _ring_pivot: Node3D


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _ring_pivot == null:
		return
	_ring_pivot.rotate_y(ring_spin * delta)


func _build_visuals() -> void:
	var r := radius
	var hull := make_material(hull_color, 0.5, 0.5)
	var dark := make_material(hull_color.darkened(0.45), 0.4, 0.7)
	var accent := Color(1.0, 0.8, 0.4) if style == Style.TRADE else Color(1.0, 0.25, 0.2)
	var lights := make_glow_material(accent, 4.0)

	# Hub: vertical core with flared caps and an antenna on top.
	add_mesh(cylinder(0.2 * r, 0.2 * r, 1.1 * r), hull)
	add_mesh(cylinder(0.2 * r, 0.3 * r, 0.12 * r), dark, Vector3(0, 0.55 * r, 0))
	add_mesh(cylinder(0.3 * r, 0.2 * r, 0.12 * r), dark, Vector3(0, -0.55 * r, 0))
	add_mesh(cylinder(0.01 * r, 0.02 * r, 0.35 * r, 8), dark, Vector3(0, 0.78 * r, 0))
	add_mesh(sphere(0.025 * r), lights, Vector3(0, 0.96 * r, 0))

	# Habitat ring on spokes; spins slowly.
	_ring_pivot = add_generated(Node3D.new())
	var torus := TorusMesh.new()
	torus.inner_radius = 0.6 * r
	torus.outer_radius = 0.74 * r
	torus.rings = 48
	torus.ring_segments = 12
	add_mesh(torus, hull, Vector3.ZERO, _ring_pivot)
	for i in 4:
		var angle := TAU * i / 4.0
		var spoke := add_mesh(box(Vector3(0.42 * r, 0.04 * r, 0.05 * r)), dark,
				_radial(angle) * 0.4 * r, _ring_pivot)
		spoke.rotation.y = -angle
	for i in 8:
		add_mesh(sphere(0.02 * r), lights, _radial(TAU * i / 8.0) * 0.67 * r + Vector3(0, 0.08 * r, 0),
				_ring_pivot)

	if style == Style.TRADE:
		_build_docking_arms(hull, dark, lights)
	else:
		_build_defenses(dark, lights)


## Three docking arms below the ring, loaded with cargo containers.
func _build_docking_arms(hull: Material, dark: Material, lights: Material) -> void:
	var r := radius
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(display_name)
	for i in 3:
		var angle := TAU * i / 3.0 + PI / 6.0
		var level := Vector3(0, -0.35 * r, 0)
		var arm := add_mesh(box(Vector3(0.5 * r, 0.06 * r, 0.08 * r)), hull, _radial(angle) * 0.45 * r + level)
		arm.rotation.y = -angle
		for j in 3:
			var cargo := make_material(CARGO_COLORS[rng.randi() % CARGO_COLORS.size()], 0.2, 0.7)
			var container := add_mesh(box(Vector3(0.09 * r, 0.06 * r, 0.06 * r)), cargo,
					_radial(angle) * (0.32 + 0.12 * j) * r + level + Vector3(0, 0.06 * r, 0))
			container.rotation.y = -angle
		add_mesh(sphere(0.02 * r), lights, _radial(angle) * 0.71 * r + level)
	add_mesh(box(Vector3(0.12 * r, 0.12 * r, 0.12 * r)), dark, Vector3(0, -0.45 * r, 0))


## Armor collar around the lower hub with six turrets.
func _build_defenses(dark: Material, lights: Material) -> void:
	var r := radius
	add_mesh(cylinder(0.34 * r, 0.34 * r, 0.25 * r, 8), dark, Vector3(0, -0.25 * r, 0))
	for i in 6:
		var angle := TAU * i / 6.0
		var base := _radial(angle) * 0.38 * r + Vector3(0, -0.1 * r, 0)
		add_mesh(cylinder(0.05 * r, 0.06 * r, 0.05 * r, 10), dark, base)
		var barrel := add_mesh(box(Vector3(0.12 * r, 0.015 * r, 0.015 * r)), dark,
				base + _radial(angle) * 0.06 * r + Vector3(0, 0.03 * r, 0))
		barrel.rotation.y = -angle
		add_mesh(sphere(0.015 * r), lights, _radial(angle) * 0.35 * r + Vector3(0, -0.38 * r, 0))


## Unit vector in the horizontal plane at `angle` radians.
static func _radial(angle: float) -> Vector3:
	return Vector3(cos(angle), 0.0, sin(angle))
