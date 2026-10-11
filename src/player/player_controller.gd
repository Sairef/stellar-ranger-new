class_name PlayerController
extends Node

## Turns mouse and keyboard input into orders for the player's ship.
## It uses exactly the same order API as NPC routines.
##
## Left click: select an object. Double click: approach the object under the cursor,
## or fly to that point on the ship's horizontal plane if there is nothing there.
## Q: approach selected, W: orbit selected, Space: stop.
## The object under the cursor gets a faint ring (`hovered`), so it is clear what a click selects.

signal selection_changed(target: Node3D)

@export var ship: Ship
@export var camera: Camera3D
## Distance from the target's surface for the Approach command, in meters.
@export var approach_distance := 50.0
## Distance from the target's surface for the Orbit command, in meters.
@export var orbit_distance := 100.0

var selected: Node3D = null
## Object under the mouse cursor right now, or null.
var hovered: Node3D = null

## Mouse travel (px) after which a press counts as a drag, not a click.
const CLICK_SLOP := 6.0
## Objects closer than this to the cursor on screen (px) can be picked even if tiny.
const PICK_RADIUS := 16.0
## Cursor distances closer than this (px) count as a tie, decided by distance to the camera.
const PICK_TIE := 2.0
## Selection rings are never smaller than this on screen, in pixels.
const MIN_RING_PIXELS := 28.0
## Longest move order from a double click, in meters.
const MAX_MOVE_DISTANCE := 5000.0

var _press_position := Vector2.ZERO
var _marker: Sprite3D
var _hover_marker: Sprite3D


func _ready() -> void:
	_marker = _create_ring(Color(1.0, 0.8, 0.3, 0.9))
	add_child(_marker)
	_hover_marker = _create_ring(Color(1.0, 1.0, 1.0, 0.35))
	add_child(_hover_marker)


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
	hovered = pick(get_viewport().get_mouse_position())
	_place_ring(_marker, selected)
	_place_ring(_hover_marker, hovered if hovered != selected else null)


func select(target: Node3D) -> void:
	if target == ship:
		target = null
	if target == selected:
		return
	selected = target
	selection_changed.emit(selected)


func approach_selected() -> void:
	if is_instance_valid(selected):
		ship.give_order(ApproachOrder.new(selected, approach_distance))


func orbit_selected() -> void:
	if is_instance_valid(selected):
		ship.give_order(OrbitOrder.new(selected, orbit_distance))


func stop() -> void:
	ship.stop()


## Space object under the cursor (ships and obstacles), or null.
##
## Works in screen space: every object can be picked within its projected disk, and tiny ones
## within at least PICK_RADIUS pixels. When several qualify, the one whose center is closest to
## the cursor (in pixels) wins: a click right on a distant gate selects the gate even if a
## small ship in front covers it with its halo, and a click next to a small ship parked at a
## big station selects the ship, not the station. Ties go to the object closer to the camera.
func pick(screen_position: Vector2) -> Node3D:
	var best: Node3D = null
	var best_distance := INF
	var best_depth := INF
	var candidates := get_tree().get_nodes_in_group(Autopilot.SHIP_GROUP) \
			+ get_tree().get_nodes_in_group(Autopilot.OBSTACLE_GROUP)
	for node in candidates:
		var object := node as Node3D
		if object == null or object == ship or camera.is_position_behind(object.global_position):
			continue
		var distance := camera.unproject_position(object.global_position).distance_to(screen_position)
		if distance > maxf(_projected_radius(object), PICK_RADIUS):
			continue
		var depth := camera.global_position.distance_to(object.global_position)
		if distance < best_distance - PICK_TIE or (distance <= best_distance + PICK_TIE and depth < best_depth):
			best_distance = distance
			best_depth = depth
			best = object
	return best


## Radius of the object's navigation sphere on screen, in pixels.
func _projected_radius(object: Node3D) -> float:
	var center := camera.unproject_position(object.global_position)
	var edge := camera.unproject_position(
			object.global_position + camera.global_basis.x * Autopilot.radius_of(object))
	return center.distance_to(edge)


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


## Puts a ring around `target` (or hides it), at least MIN_RING_PIXELS wide on screen.
func _place_ring(ring: Sprite3D, target: Node3D) -> void:
	ring.visible = target != null
	if target == null:
		return
	ring.global_position = target.get_global_transform_interpolated().origin
	var world_size := Autopilot.radius_of(target) * 2.6
	var on_screen := _projected_radius(target) * 2.6
	if on_screen > 0.0 and on_screen < MIN_RING_PIXELS:
		world_size *= MIN_RING_PIXELS / on_screen
	ring.pixel_size = world_size / ring.texture.get_width()


func _create_ring(color: Color) -> Sprite3D:
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
	marker.modulate = color
	marker.visible = false
	marker.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	return marker
