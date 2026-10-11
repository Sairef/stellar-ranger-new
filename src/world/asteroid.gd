@tool
class_name Asteroid
extends StaticBody3D

## A rock floating in space: a static obstacle ships must fly around.
##
## The mesh is generated from `radius` and `shape_seed`: a low-poly sphere dented by noise.
## Dents only go inward, so the collision sphere (exactly `radius`) always contains the rock
## and ships keeping clear of the sphere never visually clip into it.

@export var display_name := "Asteroid":
	set(value):
		display_name = value
		_queue_rebuild()
## Collision and avoidance radius in meters.
@export var radius := 40.0:
	set(value):
		radius = maxf(value, 1.0)
		_queue_rebuild()
@export var shape_seed := 0:
	set(value):
		shape_seed = value
		_queue_rebuild()
@export var rock_color := Color(0.42, 0.39, 0.36):
	set(value):
		rock_color = value
		_queue_rebuild()

## How deep the dents go, as a fraction of the radius.
const DENT_DEPTH := 0.25


func _ready() -> void:
	add_to_group(Autopilot.OBSTACLE_GROUP)
	_rebuild()


func get_nav_radius() -> float:
	return radius


func _queue_rebuild() -> void:
	if is_node_ready():
		_rebuild()


## Builds the rock mesh and collision shape. Generated children are not saved with the scene.
func _rebuild() -> void:
	for child in get_children():
		if child.has_meta(&"generated"):
			remove_child(child)
			child.queue_free()

	var material := StandardMaterial3D.new()
	material.albedo_color = rock_color
	material.roughness = 0.95

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = _build_rock_mesh()
	mesh_instance.material_override = material
	_add_generated(mesh_instance)

	var shape := SphereShape3D.new()
	shape.radius = radius
	var collision := CollisionShape3D.new()
	collision.shape = shape
	_add_generated(collision)

	_add_generated(SpaceLabel.create(display_name, radius))


func _build_rock_mesh() -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 18
	sphere.rings = 10
	var arrays := sphere.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]

	var noise := FastNoiseLite.new()
	noise.seed = shape_seed
	noise.frequency = 0.9
	noise.fractal_octaves = 3

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)  # Flat shading: faceted rock look.
	for index in indices:
		var vertex := vertices[index]
		# Noise is sampled by position, so duplicated seam vertices get the same dent (no cracks).
		var dent := clampf(noise.get_noise_3dv(vertex * 2.0) * 0.5 + 0.5, 0.0, 1.0)
		surface.add_vertex(vertex * radius * (1.0 - dent * DENT_DEPTH))
	surface.generate_normals()
	return surface.commit()


func _add_generated(node: Node) -> void:
	node.set_meta(&"generated", true)
	add_child(node)
