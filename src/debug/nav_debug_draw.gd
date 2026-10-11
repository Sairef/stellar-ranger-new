class_name NavDebugDraw
extends MeshInstance3D

## Debug overlay for navigation, toggled with F3:
## - gray line: from each ship to its current goal point;
## - yellow line: where the autopilot is steering right now (desired velocity, 1.5 s ahead);
## - cyan trail: where each ship has actually been recently;
## - red circles: obstacle safety bubbles (as seen by an 8 m ship).

@export var enabled := true

## Seconds between trail samples, and how many samples to keep per ship.
const TRAIL_INTERVAL := 0.2
const TRAIL_LENGTH := 150
const BUBBLE_SEGMENTS := 40
const TYPICAL_SHIP_RADIUS := 8.0

const GOAL_COLOR := Color(0.6, 0.6, 0.6, 0.6)
const STEER_COLOR := Color(1.0, 0.9, 0.2, 0.9)
const TRAIL_COLOR := Color(0.3, 0.8, 1.0, 0.7)
const BUBBLE_COLOR := Color(1.0, 0.3, 0.3, 0.35)

var _immediate := ImmediateMesh.new()
var _material := StandardMaterial3D.new()
var _trails := {}  # Ship -> PackedVector3Array
var _trail_timer := 0.0


func _ready() -> void:
	mesh = _immediate
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.vertex_color_use_as_albedo = true
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.no_depth_test = true


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F3:
		toggle()


func toggle() -> void:
	enabled = not enabled


func _process(delta: float) -> void:
	_immediate.clear_surfaces()
	var ships := get_tree().get_nodes_in_group(Autopilot.SHIP_GROUP)
	_record_trails(ships, delta)
	if not enabled:
		return

	var lines := PackedVector3Array()
	var colors := PackedColorArray()
	for node in ships:
		var ship := node as Ship
		var origin := ship.get_global_transform_interpolated().origin
		if ship.has_goal:
			_add_line(lines, colors, origin, ship.goal_point, GOAL_COLOR)
		if ship.desired_velocity.length_squared() > 0.01:
			_add_line(lines, colors, origin, origin + ship.desired_velocity * 1.5, STEER_COLOR)
		var trail: PackedVector3Array = _trails.get(ship, PackedVector3Array())
		for i in range(1, trail.size()):
			_add_line(lines, colors, trail[i - 1], trail[i], TRAIL_COLOR)

	var camera := get_viewport().get_camera_3d()
	if camera != null:
		for node in get_tree().get_nodes_in_group(Autopilot.OBSTACLE_GROUP):
			var obstacle := node as Node3D
			var bubble := Autopilot.radius_of(obstacle) + TYPICAL_SHIP_RADIUS + Autopilot.OBSTACLE_MARGIN
			_add_circle(lines, colors, obstacle.global_position, bubble, camera.global_basis, BUBBLE_COLOR)

	if lines.is_empty():
		return
	_immediate.surface_begin(Mesh.PRIMITIVE_LINES, _material)
	for i in lines.size():
		_immediate.surface_set_color(colors[i])
		_immediate.surface_add_vertex(lines[i])
	_immediate.surface_end()


func _record_trails(ships: Array, delta: float) -> void:
	for ship in _trails.keys():
		if not is_instance_valid(ship):
			_trails.erase(ship)
	_trail_timer -= delta
	if _trail_timer > 0.0:
		return
	_trail_timer = TRAIL_INTERVAL
	for node in ships:
		var ship := node as Ship
		var trail: PackedVector3Array = _trails.get(ship, PackedVector3Array())
		trail.append(ship.global_position)
		if trail.size() > TRAIL_LENGTH:
			trail.remove_at(0)
		_trails[ship] = trail


func _add_line(lines: PackedVector3Array, colors: PackedColorArray, from: Vector3, to: Vector3,
		color: Color) -> void:
	lines.append(from)
	lines.append(to)
	colors.append(color)
	colors.append(color)


## Circle facing the camera, so the bubble outline is always visible.
func _add_circle(lines: PackedVector3Array, colors: PackedColorArray, center: Vector3, radius: float,
		view: Basis, color: Color) -> void:
	var previous := center + view.x * radius
	for i in range(1, BUBBLE_SEGMENTS + 1):
		var angle := TAU * i / BUBBLE_SEGMENTS
		var point := center + (view.x * cos(angle) + view.y * sin(angle)) * radius
		_add_line(lines, colors, previous, point, color)
		previous = point
