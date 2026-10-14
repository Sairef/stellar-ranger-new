class_name TacticalMap
extends CanvasLayer

## The tactical map (M): the system seen from straight above, with icons instead of models, so a
## crowded fight can be zoomed apart and every ship in it clicked. The icons are drawn by
## MapPainter, like on the minimap.
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

var controller: PlayerController
var is_open := false

var _camera: Camera3D
## The 3D view's camera, current again once the map closes.
var _view_camera: Camera3D
var _overlay: Control
var _painter := MapPainter.new()
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
	_painter.center = _center
	_painter.size = _screen_size()
	_painter.meters_per_pixel = _camera.size / _painter.size.y
	_painter.draw(_overlay, controller)
