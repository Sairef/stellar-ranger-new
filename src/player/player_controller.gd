class_name PlayerController
extends Node

## Turns mouse and keyboard input into orders for the player's ship.
## It uses exactly the same order API as NPC routines.
##
## Left click: select an object. Double click: approach the object under the cursor,
## or fly to that point on the ship's horizontal plane if there is nothing there.
## Q: approach selected, W: orbit selected, Space: stop.

signal selection_changed(target: Node3D)

@export var ship: Ship
@export var camera: Camera3D
## Distance from the target's surface for the Approach command, in meters.
@export var approach_distance := 50.0
## Distance from the target's surface for the Orbit command, in meters.
@export var orbit_distance := 100.0

var selected: Node3D = null

## Mouse travel (px) after which a press counts as a drag, not a click.
const CLICK_SLOP := 6.0
## Objects closer than this to the cursor on screen (px) can be picked even if tiny.
const PICK_RADIUS := 16.0
## Longest move order from a double click, in meters.
const MAX_MOVE_DISTANCE := 5000.0

var _press_position := Vector2.ZERO
var _marker: Sprite3D


func _ready() -> void:
	_marker = _create_selection_marker()
	add_child(_marker)


func _unhandled_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.double_click:
			_on_double_click(button.position)
		elif button.pressed:
			_press_position = button.position
		elif button.position.distance_to(_press_position) < CLICK_SLOP:
			select(pick(button.position))
		return

	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		match key.keycode:
			KEY_Q:
				approach_selected()
			KEY_W:
				orbit_selected()
			KEY_SPACE:
				stop()


func _process(_delta: float) -> void:
	if selected != null and not is_instance_valid(selected):
		select(null)
	_marker.visible = selected != null
	if selected != null:
		_marker.global_position = selected.get_global_transform_interpolated().origin
		_marker.pixel_size = Autopilot.radius_of(selected) * 2.6 / _marker.texture.get_width()


func select(target: Node3D) -> void:
	if target == ship:
		target = null
	if target == selected:
		return
	selected = target
	selection_changed.emit(selected)


func approach_selected() -> void:
	if selected != null:
		ship.give_order(ApproachOrder.new(selected, approach_distance))


func orbit_selected() -> void:
	if selected != null:
		ship.give_order(OrbitOrder.new(selected, orbit_distance))


func stop() -> void:
	ship.stop()


## Space object under the cursor (ships and obstacles), nearest to the camera, or null.
## Works in screen space so that small, distant ships are still easy to click.
func pick(screen_position: Vector2) -> Node3D:
	var best: Node3D = null
	var best_depth := INF
	var candidates := get_tree().get_nodes_in_group(Autopilot.SHIP_GROUP) \
			+ get_tree().get_nodes_in_group(Autopilot.OBSTACLE_GROUP)
	for node in candidates:
		var object := node as Node3D
		if object == null or object == ship or camera.is_position_behind(object.global_position):
			continue
		var center := camera.unproject_position(object.global_position)
		var edge := camera.unproject_position(
				object.global_position + camera.global_basis.x * Autopilot.radius_of(object))
		var pick_radius := maxf(center.distance_to(edge), PICK_RADIUS)
		if center.distance_to(screen_position) > pick_radius:
			continue
		var depth := camera.global_position.distance_to(object.global_position)
		if depth < best_depth:
			best_depth = depth
			best = object
	return best


func _on_double_click(screen_position: Vector2) -> void:
	var target := pick(screen_position)
	if target != null:
		select(target)
		approach_selected()
		return
	# Nothing under the cursor: fly to the point on the ship's horizontal plane.
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	var plane := Plane(Vector3.UP, ship.global_position.y)
	var hit: Variant = plane.intersects_ray(origin, direction)
	if hit == null:
		return
	var offset: Vector3 = hit - ship.global_position
	ship.give_order(MoveToOrder.new(ship.global_position + offset.limit_length(MAX_MOVE_DISTANCE)))


func _create_selection_marker() -> Sprite3D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.84, 0.88, 0.95, 1.0])
	gradient.colors = PackedColorArray([
		Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128

	var marker := Sprite3D.new()
	marker.texture = texture
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.shaded = false
	marker.no_depth_test = true
	marker.modulate = Color(1.0, 0.8, 0.3, 0.9)
	marker.visible = false
	marker.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	return marker
