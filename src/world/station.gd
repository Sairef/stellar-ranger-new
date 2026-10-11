@tool
class_name Station
extends SpaceBody

## A space station (placeholder art): central hub, rotating habitat ring and a style-specific
## lower section (docking arms with cargo for trade, armor collar with turrets for military).
##
## Ships dock through three corridors below the ring: they wait under the corridor's outer end,
## fly in to the docking point and disappear inside (see DockOrder). The collision shape follows
## the real structure, so docking ships can enter the navigation sphere without hitting it.

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

## Docking ports: angles around the hub, in radians. Between the turrets on military stations.
const DOCK_ANGLES: Array[float] = [PI / 6.0, PI / 6.0 + TAU / 3.0, PI / 6.0 + 2.0 * TAU / 3.0]
## How far below a corridor's outer end ships wait for their turn, in meters.
const HOLD_DROP := 50.0

const CARGO_COLORS: Array[Color] = [
	Color(0.85, 0.45, 0.15), Color(0.2, 0.55, 0.6), Color(0.7, 0.2, 0.2), Color(0.8, 0.7, 0.2),
]

var _ring_pivot: Node3D


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _ring_pivot == null:
		return
	_ring_pivot.rotate_y(ring_spin * delta)


func get_corridor_count() -> int:
	return DOCK_ANGLES.size()


func _corridor_local(index: int) -> Array[Vector3]:
	var r := radius
	var direction := _radial(DOCK_ANGLES[index])
	var level := Vector3(0, _dock_level(), 0)
	var inner := direction * (0.78 * r if style == Style.TRADE else 0.52 * r) + level
	var outer := direction * 1.3 * r + level
	return [inner, outer, outer + Vector3.DOWN * HOLD_DROP]


## Height of the docking corridors, below the habitat ring.
func _dock_level() -> float:
	return -0.35 * radius if style == Style.TRADE else -0.25 * radius


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
	add_mesh(_ring_mesh(), hull, Vector3.ZERO, _ring_pivot)
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


## Three docking arms below the ring, loaded with cargo containers. Ships dock at the arm tips.
func _build_docking_arms(hull: Material, dark: Material, lights: Material) -> void:
	var r := radius
	var level := Vector3(0, _dock_level(), 0)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(display_name)
	for angle in DOCK_ANGLES:
		var arm := add_mesh(box(_arm_size()), hull, _radial(angle) * 0.45 * r + level)
		arm.rotation.y = -angle
		for j in 3:
			var cargo := make_material(CARGO_COLORS[rng.randi() % CARGO_COLORS.size()], 0.2, 0.7)
			var container := add_mesh(box(Vector3(0.09 * r, 0.06 * r, 0.06 * r)), cargo,
					_radial(angle) * (0.32 + 0.12 * j) * r + level + Vector3(0, 0.06 * r, 0))
			container.rotation.y = -angle
		add_mesh(sphere(0.02 * r), lights, _radial(angle) * 0.71 * r + level)
	add_mesh(box(Vector3(0.12 * r, 0.12 * r, 0.12 * r)), dark, Vector3(0, -0.45 * r, 0))


## Armor collar around the lower hub with six turrets and three docking ports between them.
func _build_defenses(dark: Material, lights: Material) -> void:
	var r := radius
	var level := Vector3(0, _dock_level(), 0)
	add_mesh(cylinder(0.34 * r, 0.34 * r, 0.25 * r, 8), dark, level)
	for i in 6:
		var angle := TAU * i / 6.0
		var base := _radial(angle) * 0.38 * r + Vector3(0, -0.1 * r, 0)
		add_mesh(cylinder(0.05 * r, 0.06 * r, 0.05 * r, 10), dark, base)
		var barrel := add_mesh(box(Vector3(0.12 * r, 0.015 * r, 0.015 * r)), dark,
				base + _radial(angle) * 0.06 * r + Vector3(0, 0.03 * r, 0))
		barrel.rotation.y = -angle
		add_mesh(sphere(0.015 * r), lights, _radial(angle) * 0.35 * r + Vector3(0, -0.38 * r, 0))
	for angle in DOCK_ANGLES:
		var port := add_mesh(box(_port_size()), dark, _radial(angle) * 0.39 * r + level)
		port.rotation.y = -angle
		add_mesh(sphere(0.02 * r), lights, _radial(angle) * 0.45 * r + level)


func _build_collision() -> void:
	var r := radius
	var hub := CylinderShape3D.new()
	hub.radius = 0.2 * r
	hub.height = 1.1 * r
	add_shape(hub)
	for side in [1.0, -1.0]:
		var cap := CylinderShape3D.new()
		cap.radius = 0.3 * r
		cap.height = 0.12 * r
		add_shape(cap, Transform3D(Basis.IDENTITY, Vector3(0, 0.55 * r * side, 0)))
	# The ring spins, but it is round, so a static copy of its shape is exact.
	add_shape(_ring_mesh().create_trimesh_shape())

	var level := Vector3(0, _dock_level(), 0)
	if style == Style.TRADE:
		for angle in DOCK_ANGLES:
			var arm := BoxShape3D.new()
			arm.size = _arm_size()
			add_shape(arm, Transform3D(Basis(Vector3.UP, -angle), _radial(angle) * 0.45 * r + level))
	else:
		var collar := CylinderShape3D.new()
		collar.radius = 0.34 * r
		collar.height = 0.25 * r
		add_shape(collar, Transform3D(Basis.IDENTITY, level))
		for angle in DOCK_ANGLES:
			var port := BoxShape3D.new()
			port.size = _port_size()
			add_shape(port, Transform3D(Basis(Vector3.UP, -angle), _radial(angle) * 0.39 * r + level))


func _ring_mesh() -> TorusMesh:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.6 * radius
	torus.outer_radius = 0.74 * radius
	torus.rings = 48
	torus.ring_segments = 12
	return torus


func _arm_size() -> Vector3:
	return Vector3(0.5, 0.06, 0.08) * radius


func _port_size() -> Vector3:
	return Vector3(0.1, 0.08, 0.08) * radius


## Unit vector in the horizontal plane at `angle` radians.
static func _radial(angle: float) -> Vector3:
	return Vector3(cos(angle), 0.0, sin(angle))
