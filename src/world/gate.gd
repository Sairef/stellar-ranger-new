@tool
class_name Gate
extends SpaceBody

## A jump gate (placeholder art): a big ring with an energy membrane. The opening faces the
## gate's local Z axis. For now it is an obstacle and a landmark; jumping between systems,
## and ships flying through the ring, come later.
## `active` brightens the membrane, e.g. when something is coming through.

## Name of the system on the other side.
@export var destination := "Unknown"
@export var active := false:
	set(value):
		active = value
		_update_membrane()
@export var frame_color := Color(0.5, 0.52, 0.58):
	set(value):
		frame_color = value
		_queue_rebuild()
@export var energy_color := Color(0.35, 0.65, 1.0):
	set(value):
		energy_color = value
		_queue_rebuild()

const MembraneShader := preload("res://src/world/gate_membrane.gdshader")
const IDLE_INTENSITY := 0.25
const ACTIVE_INTENSITY := 1.0

var _membrane: ShaderMaterial


func _build_visuals() -> void:
	var r := radius
	var frame := make_material(frame_color, 0.6, 0.45)
	var dark := make_material(frame_color.darkened(0.5), 0.5, 0.6)
	var lights := make_glow_material(energy_color, 5.0)

	var torus := TorusMesh.new()
	torus.inner_radius = 0.78 * r
	torus.outer_radius = 0.9 * r
	torus.rings = 64
	torus.ring_segments = 10
	var ring := add_mesh(torus, frame)
	ring.rotation.x = PI / 2.0  # Torus axis from Y to Z: the opening faces along Z.

	# Four pylons around the ring, each with a light.
	for i in 4:
		var angle := TAU * i / 4.0 + PI / 4.0
		var direction := Vector3(cos(angle), sin(angle), 0.0)
		var pylon := add_mesh(box(Vector3(0.12 * r, 0.2 * r, 0.24 * r)), dark, direction * 0.84 * r)
		pylon.rotation.z = angle
		add_mesh(sphere(0.03 * r), lights, direction * 0.93 * r)

	_membrane = ShaderMaterial.new()
	_membrane.shader = MembraneShader
	var disc := QuadMesh.new()
	disc.size = Vector2.ONE * 1.6 * r
	var membrane := add_mesh(disc, _membrane)
	membrane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_update_membrane()


func _update_membrane() -> void:
	if _membrane == null:
		return
	_membrane.set_shader_parameter(&"energy_color", energy_color)
	_membrane.set_shader_parameter(&"intensity", ACTIVE_INTENSITY if active else IDLE_INTENSITY)
