class_name Minimap
extends Control

## A small top-down map in the corner, always centered on the player's ship, so the player sees
## what goes on around without opening the tactical map (M). Drawn and picked like the map
## (MapPainter), plus the selection ring and the attack brackets. Clicks work as in the 3D
## view: click to select, double click to approach the object, or to fly to that point (on the
## ship's horizontal plane) if there is nothing there. The wheel zooms. The name of the object
## under the cursor shows next to it. Hidden while the tactical map is open.

## Meters across the minimap: initial, closest and farthest zoom.
const START_SPAN := 4000.0
const MIN_SPAN := 500.0
const MAX_SPAN := 16000.0
const ZOOM_STEP := 1.25
const BACKGROUND_COLOR := Color(0.02, 0.025, 0.045, 0.85)
const BORDER_COLOR := Color(0.4, 0.5, 0.7, 0.5)
const FONT_SIZE := 12
## Mouse travel (px) after which a press counts as a drag, not a click.
const CLICK_SLOP := 6.0

var controller: PlayerController
## The tactical map: the minimap hides while it is open.
var map: TacticalMap
## Meters across the minimap.
var span := START_SPAN

var _painter := MapPainter.new()
## Where the minimap looks: the player's ship, or where it last was.
var _center := Vector3.ZERO
var _press_position := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_painter.font_size = FONT_SIZE
	_painter.draw_markers = true


func _process(_delta: float) -> void:
	visible = controller != null and (map == null or not map.is_open)
	if not visible:
		return
	var own := controller.ship
	if own != null:
		_center = own.get_global_transform_interpolated().origin
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND_COLOR)
	_update_painter()
	_painter.draw(self, controller)
	var mouse := get_local_mouse_position()
	if Rect2(Vector2.ZERO, size).has_point(mouse):
		var hovered := pick(mouse)
		if hovered != null:
			draw_string(ThemeDB.fallback_font, mouse + Vector2(12.0, -6.0), Autopilot.name_of(hovered),
					HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color.WHITE)
	draw_rect(Rect2(Vector2.ZERO, size), BORDER_COLOR, false, 1.5)


## The object under `local_position` (in the minimap's own pixels), or null.
func pick(local_position: Vector2) -> Node3D:
	_update_painter()
	return _painter.pick(get_tree(), local_position, controller)


## Where `point` is on the minimap, in its own pixels.
func to_local_point(point: Vector3) -> Vector2:
	_update_painter()
	return _painter.to_screen(point)


func zoom(factor: float) -> void:
	span = clampf(span * factor, MIN_SPAN, MAX_SPAN)


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null:
		return
	accept_event()
	if button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
		zoom(1.0 / ZOOM_STEP)
	elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
		zoom(ZOOM_STEP)
	elif button.button_index == MOUSE_BUTTON_LEFT:
		if button.double_click:
			double_click(button.position)
		elif button.pressed:
			_press_position = button.position
		elif button.position.distance_to(_press_position) < CLICK_SLOP:
			controller.select(pick(button.position))


## Approaches the object under `local_position`, or flies to that point.
func double_click(local_position: Vector2) -> void:
	var target := pick(local_position)
	if target != null:
		controller.select(target)
		controller.approach_selected()
		return
	var own := controller.ship
	if own == null:
		return
	var point := _painter.to_ground(local_position)
	point.y = own.global_position.y
	controller.fly_to(point)


func _update_painter() -> void:
	_painter.center = _center
	_painter.size = size
	_painter.meters_per_pixel = span / maxf(size.x, 1.0)
