class_name MapPainter
extends RefCounted

## The system from straight above, as icons: draws it on a canvas and finds the icon under a
## point. Shared by the tactical map (M) and the minimap, so both look and pick the same.
## Ships are triangles pointing where they fly: red for hostiles, cyan for the player, gray for
## everyone else, bigger for bigger classes; drones are dots. Stations and gates are outlined and
## named, rocks are dots of their size, wrecks are crosses. A faint grid shows the scale, a faint
## circle around the player's ship how far its weapon reaches.
## The projection: screen right is +X, screen down is +Z, height is ignored.

const GRID_COLOR := Color(0.4, 0.5, 0.7, 0.12)
const HOSTILE_COLOR := Color(1.0, 0.3, 0.25)
const PLAYER_COLOR := Color(0.3, 0.85, 1.0)
const OTHER_COLOR := Color(0.72, 0.75, 0.8)
const STRUCTURE_COLOR := Color(0.85, 0.85, 0.9, 0.9)
const ROCK_COLOR := Color(0.5, 0.48, 0.45)
const WRECK_COLOR := Color(0.75, 0.6, 0.3)
const SELECTION_COLOR := Color(1.0, 0.8, 0.3, 0.9)
const ATTACK_COLOR := Color(1.0, 0.25, 0.2, 0.95)
const REACH_COLOR := Color(0.3, 0.85, 1.0, 0.35)
const BEST_BAND_COLOR := Color(0.3, 0.85, 1.0, 0.12)
## Half the length of a ship icon, in pixels, by ship class.
const ICON_SIZE := {
	ShipClass.Size.CUSTOM: 6.0, ShipClass.Size.SMALL: 5.0, ShipClass.Size.MEDIUM: 7.5,
	ShipClass.Size.LARGE: 11.0,
}
## An icon can be picked this far from its middle at least, in pixels.
const PICK_RADIUS := 10.0

## Point of the ecliptic in the middle of the drawing.
var center := Vector3.ZERO
## Scale of the drawing.
var meters_per_pixel := 10.0
## Size of the drawing, in pixels.
var size := Vector2(100.0, 100.0)
var font_size := 14
## Also draw the selection ring and the attack brackets (the tactical map shows the 3D ones).
var draw_markers := false


## Where `point` is on the drawing.
func to_screen(point: Vector3) -> Vector2:
	return size * 0.5 + Vector2(point.x - center.x, point.z - center.z) / meters_per_pixel


## The point of the ecliptic under `screen_position`.
func to_ground(screen_position: Vector2) -> Vector3:
	var offset := (screen_position - size * 0.5) * meters_per_pixel
	return Vector3(center.x + offset.x, 0.0, center.z + offset.y)


func draw(canvas: CanvasItem, controller: PlayerController) -> void:
	var font := ThemeDB.fallback_font
	var tree := canvas.get_tree()
	var own := controller.ship if controller.has_ship() else null
	_draw_grid(canvas, font)
	_draw_reach(canvas, own)
	for node in tree.get_nodes_in_group(Autopilot.OBSTACLE_GROUP):
		var body := node as SpaceBody
		if body != null:
			_draw_body(canvas, body, font)
	for node in tree.get_nodes_in_group(Autopilot.SHIP_GROUP):
		var ship := node as Ship
		var color := OTHER_COLOR
		if ship == own:
			color = PLAYER_COLOR
		elif Factions.are_hostile(Factions.PLAYER, ship.faction):
			color = HOSTILE_COLOR
		_draw_ship(canvas, ship, color)
	if draw_markers:
		_draw_ring(canvas, controller.selected)
		_draw_brackets(canvas, controller.attack_target())


## The object whose icon is under `screen_position`, or null: of all the icons there, the one
## whose middle is closest. The player's own ship is left out (it cannot be selected).
func pick(tree: SceneTree, screen_position: Vector2, controller: PlayerController) -> Node3D:
	var best: Node3D = null
	var best_distance := INF
	var own := controller.ship
	for node in tree.get_nodes_in_group(Autopilot.SHIP_GROUP) + tree.get_nodes_in_group(Autopilot.OBSTACLE_GROUP):
		var object := node as Node3D
		if object == null or object == own:
			continue
		var distance := to_screen(object.global_position).distance_to(screen_position)
		if distance <= pick_radius_of(object) and distance < best_distance:
			best_distance = distance
			best = object
	return best


## How far from the middle of its icon `object` can be picked, in pixels.
func pick_radius_of(object: Node3D) -> float:
	var radius := maxf(PICK_RADIUS, Autopilot.radius_of(object) / meters_per_pixel)
	if object is Ship:
		radius = maxf(radius, ICON_SIZE[(object as Ship).ship_class])
	return radius


## Faint lines on the ecliptic every 10, 100, 1000... meters: the power of ten just below half
## the drawing's height, so there are 2 to 20 lines across. The step is written at the top.
func _draw_grid(canvas: CanvasItem, font: Font) -> void:
	var height := size.y * meters_per_pixel
	var step := pow(10.0, floorf(log(height * 0.5) / log(10.0)))
	var top_left := to_ground(Vector2.ZERO)
	var bottom_right := to_ground(size)
	var x := ceilf(top_left.x / step) * step
	while x <= bottom_right.x:
		var at := to_screen(Vector3(x, 0.0, center.z))
		canvas.draw_line(Vector2(at.x, 0.0), Vector2(at.x, size.y), GRID_COLOR)
		x += step
	var z := ceilf(top_left.z / step) * step
	while z <= bottom_right.z:
		var at := to_screen(Vector3(center.x, 0.0, z))
		canvas.draw_line(Vector2(0.0, at.y), Vector2(size.x, at.y), GRID_COLOR)
		z += step
	var label := "Grid %s" % ("%.0f km" % (step / 1000.0) if step >= 1000.0 else "%.0f m" % step)
	canvas.draw_string(font, Vector2(size.x * 0.5 - font_size * 2.0, font_size + 8.0), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, STRUCTURE_COLOR)


## Weapon range around `ship` (if armed): a target whose hull touches the circle is in range.
## The band where the weapon hits best (Weapon.best_from..best_to) is shaded.
func _draw_reach(canvas: CanvasItem, ship: Ship) -> void:
	if ship == null or not ship.is_armed():
		return
	var weapon := ship.get_weapon()
	var at := to_screen(ship.get_global_transform_interpolated().origin)
	canvas.draw_arc(at, (weapon.max_range + ship.radius) / meters_per_pixel, 0.0, TAU, 64, REACH_COLOR, 1.0)
	var inner := (weapon.best_from + ship.radius) / meters_per_pixel
	var outer := (weapon.best_to + ship.radius) / meters_per_pixel
	canvas.draw_arc(at, (inner + outer) * 0.5, 0.0, TAU, 64, BEST_BAND_COLOR, maxf(1.0, outer - inner))


func _draw_body(canvas: CanvasItem, body: SpaceBody, font: Font) -> void:
	var at := to_screen(body.global_position)
	var radius := maxf(2.0, body.radius / meters_per_pixel)
	if body is Station or body is Gate:
		radius = maxf(radius, 6.0)
		if body is Station:
			canvas.draw_rect(Rect2(at - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), STRUCTURE_COLOR, false, 2.0)
		else:
			canvas.draw_arc(at, radius, 0.0, TAU, 32, STRUCTURE_COLOR, 2.0)
		var name_at := at + Vector2(-radius, radius + font_size + 2.0)
		canvas.draw_string(font, name_at, body.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, STRUCTURE_COLOR)
	elif body is Wreck:
		var d := 3.0
		canvas.draw_line(at - Vector2(d, d), at + Vector2(d, d), WRECK_COLOR, 1.5)
		canvas.draw_line(at - Vector2(d, -d), at + Vector2(d, -d), WRECK_COLOR, 1.5)
	else:
		canvas.draw_circle(at, radius, ROCK_COLOR)


func _draw_ship(canvas: CanvasItem, ship: Ship, color: Color) -> void:
	var at := to_screen(ship.get_global_transform_interpolated().origin)
	if ship.is_drone:
		canvas.draw_circle(at, 1.5, color)
		return
	var icon: float = ICON_SIZE[ship.ship_class]
	var forward := ship.get_forward()
	var heading := Vector2(forward.x, forward.z)
	heading = heading.normalized() if heading.length_squared() > 0.0001 else Vector2.UP
	var points := PackedVector2Array([
		at + heading * icon * 1.4,
		at + heading.rotated(2.5) * icon,
		at + heading.rotated(-2.5) * icon,
	])
	canvas.draw_colored_polygon(points, color)


func _draw_ring(canvas: CanvasItem, target: Node3D) -> void:
	if target != null:
		canvas.draw_arc(_marker_center(target), _marker_radius(target) + 3.0, 0.0, TAU, 32, SELECTION_COLOR, 1.5)


## Four corners of a square around `target`, like a target lock.
func _draw_brackets(canvas: CanvasItem, target: Node3D) -> void:
	if target == null:
		return
	var at := _marker_center(target)
	var half := _marker_radius(target) + 6.0
	var arm := half * 0.5
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var tip := at + corner * half
		canvas.draw_line(tip, tip - Vector2(corner.x * arm, 0.0), ATTACK_COLOR, 2.0)
		canvas.draw_line(tip, tip - Vector2(0.0, corner.y * arm), ATTACK_COLOR, 2.0)


func _marker_center(target: Node3D) -> Vector2:
	return to_screen(target.get_global_transform_interpolated().origin)


func _marker_radius(target: Node3D) -> float:
	var radius := Autopilot.radius_of(target) / meters_per_pixel
	if target is Ship:
		radius = maxf(radius, ICON_SIZE[(target as Ship).ship_class])
	return maxf(radius, 6.0)
