@tool
class_name Ship
extends CharacterBody3D

## A spaceship: flight model plus the order it is currently executing.
##
## Ships never steer directly. Every physics tick the current order updates its state and
## produces a NavGoal, the Autopilot turns it into a desired velocity (avoiding obstacles and
## traffic), and the flight model below follows that velocity within the ship's limits.
## The player and NPCs control ships only through give_order(), so both play by the same rules.
##
## The flight model is "boat-like" on purpose: the ship always moves where its nose points,
## turns at a limited rate and slows down in sharp turns. This keeps paths predictable.
##
## A docked ship is hidden inside its station: no collision, not part of traffic, no orders.
## Visuals are generated from the exported parameters (placeholder art).

signal order_changed(order: ShipOrder)
signal docked(station: SpaceBody)
signal undocked(station: SpaceBody)
signal jumped(gate: Gate)
## Physical contact with something (another ship, a rock, a structure).
signal collided(collider: Object)
signal damaged(attacker: Ship)
## Emitted right before the ship is removed; its wreck is already in the scene.
signal destroyed(ship: Ship, wreck: Wreck)

## Fraction of the target speed kept while the nose points straight away from the goal.
const MIN_TURN_SPEED_FACTOR := 0.05
## Every ship, docked or not. Autopilot.SHIP_GROUP holds only ships out in space.
const ALL_SHIPS_GROUP := &"all_ships"

@export var display_name := "Ship":
	set(value):
		display_name = value
		_queue_rebuild()
## Collision and avoidance radius in meters.
@export var radius := 8.0:
	set(value):
		radius = maxf(value, 0.5)
		_queue_rebuild()
@export var hull_color := Color(0.35, 0.75, 1.0):
	set(value):
		hull_color = value
		_queue_rebuild()
## See Factions: decides who shoots at whom on sight.
@export var faction := Factions.NEUTRAL

@export_group("Durability")
## Damage goes to the shield first, then to the armor. No armor left: the ship is destroyed.
@export var max_shield := 20.0
@export var max_armor := 10.0

@export_group("Flight")
## Top speed in m/s.
@export var max_speed := 120.0
## Speed change in m/s per second, for both thrust and braking.
@export var acceleration := 40.0
## Max turn rate in radians per second.
@export var turn_rate := 1.5

@export_group("Cargo")
@export var cargo_capacity := 100.0

var current_order: ShipOrder = null
## Current forward speed in m/s.
var speed := 0.0
var shield := 0.0
var armor := 0.0
## Cargo units in the hold.
var cargo := 0.0
## Point (Vector3) the work beam (e.g. mining laser) is aimed at, or null when it is off.
var beam_target: Variant = null
## Station the ship is docked at (null when not docked, or if the station is gone),
## and through which corridor it came in.
var docked_at: SpaceBody:
	get:
		return _dock.resolve() as SpaceBody if _dock != null else null
var dock_corridor := -1
## Stable id in the World registry (0 until registered). Refer to ships with ObjectRef.
var object_id := 0
## Last autopilot output, kept for UI and debug drawing.
var desired_velocity := Vector3.ZERO
var has_goal := false
var goal_point := Vector3.ZERO
## Physics ticks in which the ship touched something. Avoidance should keep this at zero.
var collision_ticks := 0

var _face_point: Variant = null
var _gone := false
var _docked := false
var _dock: ObjectRef = null
var _collision_layer := 1
var _collision_mask := 1
var _engine_glow: Node3D
var _beam: MeshInstance3D
var _beam_material: StandardMaterial3D
var _label: Label3D


func _enter_tree() -> void:
	if not Engine.is_editor_hint():
		WorldRegistry.register(self)


func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		WorldRegistry.unregister(self)


func _ready() -> void:
	add_to_group(Autopilot.SHIP_GROUP)
	add_to_group(ALL_SHIPS_GROUP)
	motion_mode = MOTION_MODE_FLOATING
	_collision_layer = collision_layer
	_collision_mask = collision_mask
	shield = max_shield
	armor = max_armor
	_rebuild()


func give_order(order: ShipOrder) -> void:
	current_order = order
	beam_target = null
	order_changed.emit(order)


func stop() -> void:
	give_order(null)


func get_nav_radius() -> float:
	return radius


func get_forward() -> Vector3:
	return -global_basis.z


func is_docked() -> bool:
	return _docked


## Adds the ship to `parent` already at `where` (global). Placing it after adding would put it
## at the parent's origin for a moment, where physics may push it out of whatever is there.
func enter_space(parent: Node, where: Transform3D) -> void:
	var parent_3d := parent as Node3D
	transform = parent_3d.global_transform.affine_inverse() * where if parent_3d != null else where
	parent.add_child(self)
	reset_physics_interpolation()


## Out in space and still in one piece: can fly, shoot and be shot.
func is_in_space() -> bool:
	return not _gone and not _docked and is_inside_tree()


func is_hostile_to(other: Ship) -> bool:
	return Factions.are_hostile(faction, other.faction)


func get_weapon() -> Weapon:
	for child in get_children():
		if child is Weapon:
			return child
	return null


## Where shots leave the ship: the tip of the nose.
func get_muzzle_position() -> Vector3:
	return global_position + get_forward() * radius


func get_health_text() -> String:
	return "S %d  A %d" % [ceili(shield), ceili(armor)]


# --- Damage ----------------------------------------------------------------------------------

## Applies weapon damage: shield first, then armor. Destroys the ship when armor runs out.
func take_hit(damage: float, attacker: Ship) -> void:
	if not is_in_space():
		return
	var absorbed := minf(shield, damage)
	shield -= absorbed
	armor = maxf(0.0, armor - (damage - absorbed))
	_update_label()
	damaged.emit(attacker)
	if armor <= 0.0:
		_destroy()


func _destroy() -> void:
	_gone = true
	give_order(null)
	_set_in_space(false)
	CombatEffects.explosion(self, global_position, radius)
	var wreck := Wreck.from_ship(self)
	FadingEffect.root_for(self).add_child(wreck)
	wreck.global_position = global_position
	destroyed.emit(self, wreck)
	queue_free()


func get_order_label() -> String:
	if _docked:
		return "Docked at %s" % Autopilot.name_of(docked_at)
	if current_order != null:
		return current_order.get_label()
	return "Stopping" if speed > 0.5 else "Idle"


# --- Docking and jumping ---------------------------------------------------------------------

## Called by DockOrder when the ship reaches the inner end of a docking corridor.
func dock(station: SpaceBody, corridor: int) -> void:
	station.release_corridor(corridor, self)
	_docked = true
	_dock = ObjectRef.to(station)
	dock_corridor = corridor
	give_order(null)
	_set_in_space(false)
	docked.emit(station)


## Puts the ship straight into a docked state, e.g. for ships that start the game docked.
func dock_instantly(station: SpaceBody, corridor := 0) -> void:
	global_position = station.get_corridor(corridor)["inner"]
	dock(station, corridor)


## Leaves the station through the corridor the ship came in by.
## Returns false if that corridor is busy right now; try again later.
func try_undock() -> bool:
	var station := docked_at
	if station == null:
		return false
	var order := LeaveOrder.new(station, dock_corridor)
	if not station.try_reserve_corridor(dock_corridor, self, order):
		return false
	var points := station.get_corridor(dock_corridor)
	_docked = false
	_dock = null
	global_position = points["inner"]
	look_at(points["outer"], Vector3.UP)
	reset_physics_interpolation()
	_set_in_space(true)
	give_order(order)
	undocked.emit(station)
	return true


## Called by JumpOrder in the middle of a gate: the ship leaves the system for good.
func jump_out(gate: Gate, corridor: int) -> void:
	gate.release_corridor(corridor, self)
	gate.flash()
	_gone = true
	give_order(null)
	_set_in_space(false)
	jumped.emit(gate)
	queue_free()


## Removes the ship without a trace (no wreck), e.g. along with the station it was docked in.
func _vanish() -> void:
	_gone = true
	give_order(null)
	_set_in_space(false)
	queue_free()


func _set_in_space(present: bool) -> void:
	visible = present
	speed = 0.0 if not present else speed
	velocity = Vector3.ZERO
	desired_velocity = Vector3.ZERO
	has_goal = false
	collision_layer = _collision_layer if present else 0
	collision_mask = _collision_mask if present else 0
	if present:
		add_to_group(Autopilot.SHIP_GROUP)
	else:
		remove_from_group(Autopilot.SHIP_GROUP)


# --- Flight ----------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or _gone:
		return
	if _docked:
		if docked_at == null:
			_vanish()  # The station is gone, and the ship was inside it.
		return
	if current_order != null:
		current_order.update(self, delta)
	if _gone or _docked:
		return  # The order docked the ship or jumped it out.
	if current_order != null and current_order.is_complete(self):
		give_order(null)

	var goal: NavGoal = current_order.get_goal(self) if current_order != null else null
	desired_velocity = Autopilot.steer(self, goal)
	has_goal = goal != null
	if has_goal:
		goal_point = goal.point
	_face_point = goal.face_point if goal != null else null
	_fly(delta)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or _engine_glow == null:
		return
	_engine_glow.scale = Vector3.ONE * lerpf(0.3, 1.3, speed / max_speed)
	_update_beam()


func _fly(delta: float) -> void:
	var target_speed := desired_velocity.length()
	if target_speed > 0.01:
		var wanted := desired_velocity / target_speed
		_turn_towards(wanted, delta)
		# Slow down while the nose points away from where we want to go: makes turns tighter,
		# and a ship that has to turn around almost pivots in place instead of sweeping a wide arc.
		var alignment := (get_forward().dot(wanted) + 1.0) * 0.5
		target_speed *= lerpf(MIN_TURN_SPEED_FACTOR, 1.0, alignment * alignment)
	elif _face_point != null:
		var to_face: Vector3 = _face_point - global_position
		if to_face.length_squared() > 1.0:
			_turn_towards(to_face.normalized(), delta)

	speed = move_toward(speed, target_speed, acceleration * delta)
	velocity = get_forward() * speed
	move_and_slide()
	if get_slide_collision_count() > 0:
		collision_ticks += 1
		collided.emit(get_slide_collision(0).get_collider())
		# A bump costs the speed that went into the obstacle.
		speed = clampf(velocity.dot(get_forward()), 0.0, speed)


func _turn_towards(direction: Vector3, delta: float) -> void:
	# Slowly roll back toward the galactic "up" so ships do not end up flying upside down.
	var up := global_basis.y.lerp(Vector3.UP, clampf(delta, 0.0, 1.0)).normalized()
	for candidate: Vector3 in [up, global_basis.z, global_basis.x]:
		var ortho := candidate - direction * candidate.dot(direction)
		if ortho.length_squared() > 0.0001:
			up = ortho.normalized()
			break

	var current := global_basis.get_rotation_quaternion()
	var wanted := Basis.looking_at(direction, up).get_rotation_quaternion()
	var angle := current.angle_to(wanted)
	if angle < 0.0001:
		return
	global_basis = Basis(current.slerp(wanted, minf(1.0, turn_rate * delta / angle)))


## Stretches the beam from the ship's nose to beam_target, with a little flicker.
func _update_beam() -> void:
	if beam_target == null or not visible:
		_beam.visible = false
		return
	var nose := get_global_transform_interpolated().origin + get_forward() * radius
	var span: Vector3 = beam_target - nose
	var length := span.length()
	if length < 0.1:
		_beam.visible = false
		return
	var beam_basis := Basis(Quaternion(Vector3.UP, span / length))
	beam_basis.y *= length
	_beam.global_transform = Transform3D(beam_basis, nose + span * 0.5)
	_beam_material.emission_energy_multiplier = randf_range(2.0, 5.0)
	_beam.visible = true


# --- Placeholder visuals ---------------------------------------------------------------------

func _queue_rebuild() -> void:
	if is_node_ready():
		_rebuild()


## Builds placeholder visuals and the collision shape from the exported parameters.
## Generated children are not saved with the scene.
func _rebuild() -> void:
	for child in get_children():
		if child.has_meta(&"generated"):
			remove_child(child)
			child.queue_free()

	var hull_material := SpaceBody.make_material(hull_color, 0.4, 0.45)
	var hull := _add_mesh(SpaceBody.cylinder(0.0, radius * 0.45, radius * 2.0, 6), hull_material)
	hull.rotation.x = -PI / 2.0  # Cylinder tip (+Y) points forward (-Z).
	var wings := _add_mesh(SpaceBody.box(Vector3(radius * 1.8, radius * 0.1, radius * 0.6)), hull_material)
	wings.position = Vector3(0.0, 0.0, radius * 0.45)

	_engine_glow = _add_mesh(SpaceBody.sphere(radius * 0.25), SpaceBody.make_glow_material(Color(1.0, 0.6, 0.25), 4.0))
	_engine_glow.position = Vector3(0.0, 0.0, radius)

	_beam_material = SpaceBody.make_glow_material(Color(0.5, 1.0, 0.6), 3.0)
	_beam = _add_mesh(SpaceBody.cylinder(0.4, 0.4, 1.0, 6), _beam_material)
	_beam.top_level = true
	_beam.visible = false
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF

	var shape := SphereShape3D.new()
	shape.radius = radius
	var collision := CollisionShape3D.new()
	collision.shape = shape
	_add_generated(collision)

	# Always visible for now (debugging); later visibility should come from sensors.
	_label = SpaceLabel.create(display_name, radius)
	_add_generated(_label)
	_update_label()


## Name, plus shield and armor once the ship has taken damage.
func _update_label() -> void:
	if _label == null:
		return
	var damaged_now := shield < max_shield or armor < max_armor
	_label.text = "%s\n%s" % [display_name, get_health_text()] if damaged_now else display_name


func _add_mesh(mesh: Mesh, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	_add_generated(instance)
	return instance


func _add_generated(node: Node) -> void:
	node.set_meta(&"generated", true)
	add_child(node)
