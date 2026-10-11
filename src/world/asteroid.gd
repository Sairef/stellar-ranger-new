@tool
class_name Asteroid
extends SpaceBody

## A rock floating in space: a static obstacle ships must fly around.
##
## The mesh is a low-poly sphere dented by noise, generated from `radius` and `shape_seed`.
## Dents only go inward, so the collision sphere (exactly `radius`) always contains the rock
## and ships keeping clear of the sphere never visually clip into it.

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


func _build_visuals() -> void:
	add_mesh(_build_rock_mesh(), make_material(rock_color, 0.0, 0.95))


func _build_rock_mesh() -> ArrayMesh:
	var base := SphereMesh.new()
	base.radius = 1.0
	base.height = 2.0
	base.radial_segments = 18
	base.rings = 10
	var arrays := base.get_mesh_arrays()
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
