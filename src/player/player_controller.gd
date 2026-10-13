class_name PlayerController
extends Node

## Turns mouse and keyboard input into orders for the player's ship.
## It uses exactly the same order API as NPC routines.
##
## Left click: select an object. Double click: approach the object under the cursor,
## or fly to that point on the ship's horizontal plane if there is nothing there.
## Q: approach selected, W: orbit selected, E: attack selected ship, Space: stop,
## R: loot the selected wreck or container, T: loot everything within `loot_radius`.
## The object under the cursor gets a faint ring (`hovered`), so it is clear what a click selects.
## The ship the player's ship attacks (`attack_target()`) gets red corner brackets, whether it was
## picked by the player or by auto-engage.
## The ship, the selection and the hovered object are kept as ObjectRefs: once one of them is
## gone (destroyed, jumped out), it simply reads as null.
##
## Auto-engage: when the ship has no order and its weapon opens fire at a new hostile on its own,
## the ship attacks it (comes into range and circles it), so a fight goes on after the first kill.
## It never overrides an order the player gave, and after Stop the ship does not go back for the
## target it was fighting: only a hostile it has not fought yet starts a new attack.
##
## Faction credits (placeholder faction currency): +1 for every destroyed enemy the player's
## ship fired at, whoever finished it off (see docs/combat_rewards.md). One number for now:
## no factions, reputation or shop yet.
##
## The player sees what is inside wrecks only once the ship or one of its drones comes within
## Wreck.INSPECT_RANGE. When looting stops because the hold is full, `hold_full` is emitted
## (the HUD opens the cargo window, so the player can drop what is not worth keeping).

signal selection_changed(target: Node3D)
## A loot order stopped because the hold has no room left.
signal hold_full
## Faction credits were earned for destroying `enemy`.
signal faction_credits_earned(amount: int, enemy: String)

## The player's ship, or null while there is none (e.g. destroyed).
@export var ship: Ship:
	get:
		return _ship.resolve() as Ship if _ship != null else null
	set(value):
		_ship = ObjectRef.to(value)
		_engaged = ObjectRef.new()
		if value != null and not value.helped_destroy.is_connected(_on_helped_destroy):
			value.helped_destroy.connect(_on_helped_destroy)
@export var camera: Camera3D
## See "Auto-engage" above.
@export var auto_engage := true
## Radius of Loot all around the ship, in meters.
@export var loot_radius := 5000.0
## Distance from the target's surface for the Approach command, in meters.
@export var approach_distance := 50.0
## Distance from the target's surface for the Orbit command, in meters.
@export var orbit_distance := 100.0

## See "Faction credits" above.
var faction_credits := 0
## The selected object, or null.
var selected: Node3D:
	get:
		return _selected.resolve()
## Object under the mouse cursor right now, or null.
var hovered: Node3D:
	get:
		return _hovered.resolve()

## Mouse travel (px) after which a press counts as a drag, not a click.
const CLICK_SLOP := 6.0
## Objects closer than this to the cursor on screen (px) can be picked even if tiny.
const PICK_RADIUS := 16.0
## Cursor distances closer than this (px) count as a tie, decided by distance to the camera.
const PICK_TIE := 2.0
## Selection rings are never smaller than this on screen, in pixels.
const MIN_RING_PIXELS := 28.0
## Rings span this many radii of the object; attack brackets are a bit wider, around the ring.
const RING_SCALE := 2.6
const BRACKETS_SCALE := 3.2
const MIN_BRACKETS_PIXELS := 36.0
## Why auto-engage picked its target, shown in the order label.
const AUTO_ENGAGE_NOTE := "auto: nearest hostile in range"
## Longest move order from a double click, in meters.
const MAX_MOVE_DISTANCE := 5000.0

var _ship: ObjectRef = null
var _selected := ObjectRef.new()
var _hovered := ObjectRef.new()
## The last ship the player's ship attacked, by order or by auto-engage.
var _engaged := ObjectRef.new()
## The last loot order given, until it ends (watched for a full hold).
var _loot_order: LootOrder = null
var _press_position := Vector2.ZERO
var _marker: Sprite3D
var _hover_marker: Sprite3D
var _attack_marker: Sprite3D


func _ready() -> void:
	_marker = _create_marker(_ring_texture(), Color(1.0, 0.8, 0.3, 0.9))
	add_child(_marker)
	_hover_marker = _create_marker(_ring_texture(), Color(1.0, 1.0, 1.0, 0.35))
	add_child(_hover_marker)
	_attack_marker = _create_marker(_brackets_texture(), Color(1.0, 0.25, 0.2, 0.95))
	add_child(_attack_marker)


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
			KEY_E:
				attack_selected()
			KEY_R:
				loot_selected()
			KEY_T:
				loot_all()
			KEY_SPACE:
				stop()


func _process(_delta: float) -> void:
	# The selected object vanished (destroyed, jumped out): tell listeners it is cleared.
	if _selected.is_set() and selected == null:
		_selected = ObjectRef.new()
		selection_changed.emit(null)
	_hovered = ObjectRef.to(pick(get_viewport().get_mouse_position()))
	var current := selected
	var hover := hovered
	_place_marker(_marker, current)
	_place_marker(_hover_marker, hover if hover != current else null)
	_place_marker(_attack_marker, attack_target(), BRACKETS_SCALE, MIN_BRACKETS_PIXELS)


func _physics_process(_delta: float) -> void:
	if not has_ship():
		return
	var own := ship
	_watch_loot_order(own)
	_inspect_wrecks(own)
	if auto_engage:
		_auto_engage(own)


func _auto_engage(own: Ship) -> void:
	if own.current_order != null:
		var fighting := own.current_order.get_attack_target()
		if fighting != null and not _engaged.points_to(fighting):
			_engaged = ObjectRef.to(fighting)
		return  # Never override an order.
	var weapon := own.get_weapon()
	if weapon == null or not weapon.enabled:
		return
	var target := weapon.choose_target()
	if target == null or _engaged.points_to(target):
		return
	_engaged = ObjectRef.to(target)
	var order := AttackOrder.new(target)
	order.note = AUTO_ENGAGE_NOTE
	own.give_order(order)
	if selected == null:
		select(target)


func select(target: Node3D) -> void:
	if target != null and target == ship:
		target = null
	if target == selected:
		return
	_selected = ObjectRef.to(target)
	selection_changed.emit(target)


func has_ship() -> bool:
	var own := ship
	return own != null and own.is_in_space()


## The ship the player's ship is ordered to fight (by the player or by auto-engage), or null.
func attack_target() -> Ship:
	if not has_ship() or ship.current_order == null:
		return null
	return ship.current_order.get_attack_target()


func approach_selected() -> void:
	if has_ship() and selected != null:
		ship.give_order(ApproachOrder.new(selected, approach_distance))


func orbit_selected() -> void:
	if has_ship() and selected != null:
		ship.give_order(OrbitOrder.new(selected, orbit_distance))


func attack_selected() -> void:
	if has_ship() and can_attack_selected():
		ship.give_order(AttackOrder.new(selected as Ship))


func can_attack_selected() -> bool:
	return selected is Ship


func loot_selected() -> void:
	if can_loot_selected():
		_give_loot_order(LootOrder.new([selected]))


func loot_all() -> void:
	if can_loot():
		_give_loot_order(LootOrder.around(ship.global_position, loot_radius))


## The ship is there and has drones.
func can_loot() -> bool:
	if not has_ship():
		return false
	var bay: DroneBay = ship.get_drone_bay()
	return bay != null and bay.drones > 0


func can_loot_selected() -> bool:
	return can_loot() and selected is Wreck


## Drops `amount` pieces of `item` from the hold into a container behind the ship.
func jettison(item: StringName, amount: int) -> void:
	if has_ship():
		ship.jettison(item, amount)


func _give_loot_order(order: LootOrder) -> void:
	_loot_order = order
	ship.give_order(order)


## The player's ship fired at `victim`, which has just been destroyed.
func _on_helped_destroy(victim: Ship) -> void:
	var own := ship
	if own == null or not own.is_hostile_to(victim):
		return  # Only enemies count: shooting down a neutral earns nothing.
	faction_credits += 1
	faction_credits_earned.emit(1, victim.display_name)


## Once the loot order has ended (its drones are back), tells whether the hold got full.
func _watch_loot_order(own: Ship) -> void:
	if _loot_order == null or own.current_order == _loot_order:
		return
	var full := _loot_order.hold_full
	_loot_order = null
	if full:
		hold_full.emit()


## Marks wrecks near the ship or its drones as inspected: the player now knows what is inside.
func _inspect_wrecks(own: Ship) -> void:
	var eyes: Array[Vector3] = [own.global_position]
	var bay: DroneBay = own.get_drone_bay()
	if bay != null:
		for drone in bay.drones_out():
			eyes.append(drone.global_position)
	for node in get_tree().get_nodes_in_group(Wreck.GROUP):
		var wreck := node as Wreck
		if wreck.inspected:
			continue
		for eye in eyes:
			if eye.distance_to(wreck.global_position) - wreck.radius <= Wreck.INSPECT_RANGE:
				wreck.inspected = true
				break


func stop() -> void:
	if has_ship():
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
	if not has_ship():
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


## Puts a marker around `target` (or hides it): `span` radii of the object wide, but at least
## `min_pixels` on screen.
func _place_marker(marker: Sprite3D, target: Node3D, span := RING_SCALE,
		min_pixels := MIN_RING_PIXELS) -> void:
	marker.visible = target != null
	if target == null:
		return
	marker.global_position = target.get_global_transform_interpolated().origin
	var world_size := Autopilot.radius_of(target) * span
	var on_screen := _projected_radius(target) * span
	if on_screen > 0.0 and on_screen < min_pixels:
		world_size *= min_pixels / on_screen
	marker.pixel_size = world_size / marker.texture.get_width()


func _ring_texture() -> Texture2D:
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
	return texture


## Four corners of a square, like a target lock.
func _brackets_texture() -> Texture2D:
	const SIZE := 128
	const ARM := 30
	const WIDTH := 7
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		image.fill_rect(Rect2i(corner.x * (SIZE - ARM), corner.y * (SIZE - WIDTH), ARM, WIDTH), Color.WHITE)
		image.fill_rect(Rect2i(corner.x * (SIZE - WIDTH), corner.y * (SIZE - ARM), WIDTH, ARM), Color.WHITE)
	return ImageTexture.create_from_image(image)


func _create_marker(texture: Texture2D, color: Color) -> Sprite3D:
	var marker := Sprite3D.new()
	marker.texture = texture
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.shaded = false
	marker.no_depth_test = true
	marker.modulate = color
	marker.visible = false
	marker.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	return marker
