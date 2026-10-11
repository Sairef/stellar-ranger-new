@tool
class_name Gate
extends SpaceBody

## A jump gate (placeholder art): a big ring with an energy membrane. The opening faces the
## gate's local Z axis; the front (-Z) faces the system center.
##
## Two corridors run along the axis, one on each side, and share a single throat: only one ship
## at a time may be inside. Departing ships fly into the center and jump out of the system
## (see JumpOrder); arriving ships appear in the center and fly out the front (try_receive()).
## The collision shape is the ring itself, so the opening is free to fly through.
## `active` brightens the membrane, e.g. when something big is coming through.

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
## Membrane brightness right after a ship jumps, fading over FLASH_TIME seconds.
const FLASH_INTENSITY := 3.0
const FLASH_TIME := 1.2
## Corridor used by arriving ships: the front side, facing the system center.
const ARRIVAL_CORRIDOR := 0
## How far below a corridor's outer end ships wait for their turn, in meters.
const HOLD_DROP := 60.0
## Speed of a ship coming out of the membrane, m/s.
const ARRIVAL_SPEED := 30.0

var _membrane: ShaderMaterial
var _flash := 0.0


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _flash <= 0.0:
		return
	_flash = maxf(0.0, _flash - delta / FLASH_TIME)
	_update_membrane()


func get_corridor_count() -> int:
	return 2


func _corridor_local(index: int) -> Array[Vector3]:
	var side := -1.0 if index == 0 else 1.0
	var outer := Vector3(0, 0, side * 1.5 * radius)
	return [Vector3.ZERO, outer, outer + Vector3.DOWN * HOLD_DROP]


func _lock_key(_index: int) -> int:
	return 0  # Both sides lead to the same throat.


## Membrane flash for a ship jumping in or out.
func flash() -> void:
	_flash = 1.0
	_update_membrane()


## Brings `ship` into the system through this gate: it appears in the membrane and flies out
## the front. Returns false (and does nothing) if the throat is busy; try again later.
func try_receive(ship: Ship, parent: Node) -> bool:
	var order := LeaveOrder.new(self, ARRIVAL_CORRIDOR)
	if not try_reserve_corridor(ARRIVAL_CORRIDOR, ship, order):
		return false
	parent.add_child(ship)
	var corridor := get_corridor(ARRIVAL_CORRIDOR)
	ship.global_position = corridor["inner"]
	ship.look_at(corridor["outer"], Vector3.UP)
	ship.reset_physics_interpolation()
	ship.speed = ARRIVAL_SPEED
	ship.give_order(order)
	flash()
	return true


func _build_visuals() -> void:
	var r := radius
	var frame := make_material(frame_color, 0.6, 0.45)
	var dark := make_material(frame_color.darkened(0.5), 0.5, 0.6)
	var lights := make_glow_material(energy_color, 5.0)

	var ring := add_mesh(_ring_mesh(), frame)
	ring.rotation.x = PI / 2.0  # Torus axis from Y to Z: the opening faces along Z.

	# Four pylons around the ring, each with a light.
	for i in 4:
		var angle := _pylon_angle(i)
		var pylon := add_mesh(box(_pylon_size()), dark, _pylon_direction(angle) * 0.84 * r)
		pylon.rotation.z = angle
		add_mesh(sphere(0.03 * r), lights, _pylon_direction(angle) * 0.93 * r)

	_membrane = ShaderMaterial.new()
	_membrane.shader = MembraneShader
	var disc := QuadMesh.new()
	disc.size = Vector2.ONE * 1.6 * r
	var membrane := add_mesh(disc, _membrane)
	membrane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_update_membrane()


func _build_collision() -> void:
	add_shape(_ring_mesh().create_trimesh_shape(), Transform3D(Basis(Vector3.RIGHT, PI / 2.0)))
	for i in 4:
		var angle := _pylon_angle(i)
		var pylon := BoxShape3D.new()
		pylon.size = _pylon_size()
		add_shape(pylon, Transform3D(Basis(Vector3.BACK, angle), _pylon_direction(angle) * 0.84 * radius))


func _update_membrane() -> void:
	if _membrane == null:
		return
	var base := ACTIVE_INTENSITY if active else IDLE_INTENSITY
	_membrane.set_shader_parameter(&"energy_color", energy_color)
	_membrane.set_shader_parameter(&"intensity", lerpf(base, FLASH_INTENSITY, _flash))


func _ring_mesh() -> TorusMesh:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.78 * radius
	torus.outer_radius = 0.9 * radius
	torus.rings = 64
	torus.ring_segments = 10
	return torus


func _pylon_size() -> Vector3:
	return Vector3(0.12, 0.2, 0.24) * radius


static func _pylon_angle(index: int) -> float:
	return TAU * index / 4.0 + PI / 4.0


static func _pylon_direction(angle: float) -> Vector3:
	return Vector3(cos(angle), sin(angle), 0.0)
