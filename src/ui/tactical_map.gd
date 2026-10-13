class_name TacticalMap
extends CanvasLayer

## The tactical map (M): the system seen from straight above, with icons instead of models, so a
## crowded fight can be zoomed apart and every ship in it clicked. Ships are triangles pointing
## where they fly: red for hostiles, cyan for the player, gray for everyone else, bigger for
## bigger classes. Stations and gates are outlined and named, rocks and wrecks are dots.
## The game keeps running, and everything else works as in the 3D view: click to select,
## Q/W/E/R/T for orders, double click to fly to a point; the selection ring and the attack
## brackets show on the map too, the 3D name labels do not (SpaceLabel.LAYER).
## Mouse: drag with the right button to pan, wheel to zoom at the cursor. Arrows pan as well.

signal toggled(open: bool)

## Height of the map camera above the system, in meters.
const CAMERA_HEIGHT := 30000.0
## Visible height of the map in meters: initial, closest and farthest zoom.
const START_SIZE := 3000.0
const MIN_SIZE := 150.0
const MAX_SIZE := 16000.0
const ZOOM_STEP := 1.2
## Arrow keys pan this many screen heights per second.
const KEY_PAN_SPEED := 0.6

const BACKGROUND_COLOR := Color(0.02, 0.025, 0.045)
const GRID_COLOR := Color(0.4, 0.5, 0.7, 0.12)
const HOSTILE_COLOR := Color(1.0, 0.3, 0.25)
const PLAYER_COLOR := Color(0.3, 0.85, 1.0)
const OTHER_COLOR := Color(0.72, 0.75, 0.8)
const STRUCTURE_COLOR := Color(0.85, 0.85, 0.9, 0.9)
const ROCK_COLOR := Color(0.5, 0.48, 0.45)
const WRECK_COLOR := Color(0.75, 0.6, 0.3)
## Half the length of a ship icon, in pixels, by ship class.
const ICON_SIZE := {
	ShipClass.Size.CUSTOM: 6.0, ShipClass.Size.SMALL: 5.0, ShipClass.Size.MEDIUM: 7.5,
	ShipClass.Size.LARGE: 11.0,
}
const FONT_SIZE := 14

var controller: PlayerController
var is_open := false

var _camera: Camera3D
## The 3D view's camera, current again once the map closes.
var _view_camera: Camera3D
var _overlay: Control
## Point of the ecliptic in the middle of the map.
var _center := Vector3.ZERO
var _centered := false
## Arrow keys currently held (from events, so simulated input works too).
var _held_keys := {}


func _ready() -> void:
	layer = 0  # Under the HUD.
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = START_SIZE
	_camera.near = 10.0
	_camera.far = CAMERA_HEIGHT * 2.0
	_camera.cull_mask &= ~SpaceLabel.LAYER
	_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	# A plain background: the starfield sky smears into streaks under an orthogonal camera.
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = BACKGROUND_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.45, 0.47, 0.52)
	_camera.environment = environment
	add_child(_camera)
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.visible = false
	_overlay.draw.connect(_draw_map)
	add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open() -> void:
	if is_open or controller == null:
		return
	is_open = true
	if not _centered and controller.ship != null:
		_center = controller.ship.global_position
		_centered = true
	_view_camera = controller.camera
	if _view_camera != null:
		# Its input (orbit, zoom) would fight the map's while hidden.
		_view_camera.process_mode = Node.PROCESS_MODE_DISABLED
	_place_camera()
	_camera.make_current()
	controller.camera = _camera
	_overlay.visible = true
	toggled.emit(true)


func close() -> void:
	if not is_open:
		return
	is_open = false
	_held_keys.clear()
	if is_instance_valid(_view_camera):
		_view_camera.process_mode = Node.PROCESS_MODE_INHERIT
		_view_camera.make_current()
		controller.camera = _view_camera
	_overlay.visible = false
	toggled.emit(false)


## The map's camera (for tools and tests).
func get_camera() -> Camera3D:
	return _camera


## Zooms by `factor` (above 1 zooms out) keeping the point under `screen_position` in place.
func zoom_at(screen_position: Vector2, factor: float) -> void:
	var before := _ground_at(screen_position)
	_camera.size = clampf(_camera.size * factor, MIN_SIZE, MAX_SIZE)
	_center += before - _ground_at(screen_position)
	_place_camera()


## Moves the middle of the map to `point`.
func look_at_point(point: Vector3) -> void:
	_center = point
	_centered = true
	_place_camera()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.keycode == KEY_M:
		if key.pressed and not key.echo:
			toggle()
		get_viewport().set_input_as_handled()
		return
	if not is_open:
		return
	if key != null and key.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
		if key.pressed:
			_held_keys[key.keycode] = true
		else:
			_held_keys.erase(key.keycode)
		get_viewport().set_input_as_handled()
		return
	var motion := event as InputEventMouseMotion
	if motion != null and motion.button_mask & MOUSE_BUTTON_MASK_RIGHT:
		_center -= _to_ground(motion.relative)
		_place_camera()
		get_viewport().set_input_as_handled()
		return
	var button := event as InputEventMouseButton
	if button != null and button.pressed:
		if button.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_at(button.position, 1.0 / ZOOM_STEP)
			get_viewport().set_input_as_handled()
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_at(button.position, ZOOM_STEP)
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not is_open:
		return
	var pan := Vector2.ZERO
	if _held_keys.has(KEY_LEFT):
		pan.x -= 1.0
	if _held_keys.has(KEY_RIGHT):
		pan.x += 1.0
	if _held_keys.has(KEY_UP):
		pan.y -= 1.0
	if _held_keys.has(KEY_DOWN):
		pan.y += 1.0
	if pan != Vector2.ZERO:
		_center += _to_ground(pan * KEY_PAN_SPEED * _screen_size().y * delta)
		_place_camera()
	_overlay.queue_redraw()


func _place_camera() -> void:
	_camera.global_transform = Transform3D(Basis.looking_at(Vector3.DOWN, Vector3.FORWARD),
			Vector3(_center.x, CAMERA_HEIGHT, _center.z))


func _screen_size() -> Vector2:
	return _overlay.get_viewport_rect().size


## A move on screen, in pixels, as a move on the ecliptic (screen up is -Z, right is +X).
func _to_ground(pixels: Vector2) -> Vector3:
	var meters_per_pixel := _camera.size / _screen_size().y
	return Vector3(pixels.x, 0.0, pixels.y) * meters_per_pixel


## The point of the ecliptic under `screen_position`.
func _ground_at(screen_position: Vector2) -> Vector3:
	return _center + _to_ground(screen_position - _screen_size() * 0.5)


func _draw_map() -> void:
	var font := ThemeDB.fallback_font
	var tree := get_tree()
	_draw_grid(font)
	for node in tree.get_nodes_in_group(Autopilot.OBSTACLE_GROUP):
		var body := node as SpaceBody
		if body != null:
			_draw_body(body, font)
	var own := controller.ship if controller.has_ship() else null
	for node in tree.get_nodes_in_group(Autopilot.SHIP_GROUP):
		var ship := node as Ship
		var color := OTHER_COLOR
		if ship == own:
			color = PLAYER_COLOR
		elif Factions.are_hostile(Factions.PLAYER, ship.faction):
			color = HOSTILE_COLOR
		_draw_ship(ship, color)


## Faint lines on the ecliptic every 10, 100, 1000... meters: the power of ten just below half
## the map height, so there are 2 to 20 lines across. The step is written at the top.
func _draw_grid(font: Font) -> void:
	var screen := _screen_size()
	var step := pow(10.0, floorf(log(_camera.size * 0.5) / log(10.0)))
	var top_left := _ground_at(Vector2.ZERO)
	var bottom_right := _ground_at(screen)
	var x := ceilf(top_left.x / step) * step
	while x <= bottom_right.x:
		var at := _camera.unproject_position(Vector3(x, 0.0, _center.z))
		_overlay.draw_line(Vector2(at.x, 0.0), Vector2(at.x, screen.y), GRID_COLOR)
		x += step
	var z := ceilf(top_left.z / step) * step
	while z <= bottom_right.z:
		var at := _camera.unproject_position(Vector3(_center.x, 0.0, z))
		_overlay.draw_line(Vector2(0.0, at.y), Vector2(screen.x, at.y), GRID_COLOR)
		z += step
	var label := "Grid %s" % ("%.0f km" % (step / 1000.0) if step >= 1000.0 else "%.0f m" % step)
	_overlay.draw_string(font, Vector2(screen.x * 0.5 - 30.0, 24.0), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, STRUCTURE_COLOR)


func _draw_body(body: SpaceBody, font: Font) -> void:
	var at := _camera.unproject_position(body.global_position)
	var radius := maxf(2.0, body.radius / _camera.size * _screen_size().y)
	if body is Station or body is Gate:
		radius = maxf(radius, 6.0)
		if body is Station:
			_overlay.draw_rect(Rect2(at - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), STRUCTURE_COLOR, false, 2.0)
		else:
			_overlay.draw_arc(at, radius, 0.0, TAU, 32, STRUCTURE_COLOR, 2.0)
		var name_at := at + Vector2(-radius, radius + FONT_SIZE + 2.0)
		_overlay.draw_string(font, name_at, body.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, STRUCTURE_COLOR)
	elif body is Wreck:
		var d := 3.0
		_overlay.draw_line(at - Vector2(d, d), at + Vector2(d, d), WRECK_COLOR, 1.5)
		_overlay.draw_line(at - Vector2(d, -d), at + Vector2(d, -d), WRECK_COLOR, 1.5)
	else:
		_overlay.draw_circle(at, radius, ROCK_COLOR)


func _draw_ship(ship: Ship, color: Color) -> void:
	var at := _camera.unproject_position(ship.get_global_transform_interpolated().origin)
	if ship.is_drone:
		_overlay.draw_circle(at, 1.5, color)
		return
	var size: float = ICON_SIZE[ship.ship_class]
	var forward := ship.get_forward()
	var heading := Vector2(forward.x, forward.z)
	heading = heading.normalized() if heading.length_squared() > 0.0001 else Vector2.UP
	var points := PackedVector2Array([
		at + heading * size * 1.4,
		at + heading.rotated(2.5) * size,
		at + heading.rotated(-2.5) * size,
	])
	_overlay.draw_colored_polygon(points, color)
