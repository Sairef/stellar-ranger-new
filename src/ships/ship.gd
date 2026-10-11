@tool
class_name Ship
extends CharacterBody3D

## A spaceship: flight model plus the order it is currently executing.
##
## Ships never steer directly. Every physics tick the current order produces a NavGoal,
## the Autopilot turns it into a desired velocity (avoiding obstacles and traffic), and the
## flight model below follows that velocity within the ship's limits.
## The player and NPCs control ships only through give_order(), so both play by the same rules.
##
## The flight model is "boat-like" on purpose: the ship always moves where its nose points,
## turns at a limited rate and slows down in sharp turns. This keeps paths predictable.
## Visuals are generated from the exported parameters (placeholder art).

signal order_changed(order: ShipOrder)

## Fraction of the target speed kept while the nose points straight away from the goal.
const MIN_TURN_SPEED_FACTOR := 0.05

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

@export_group("Flight")
## Top speed in m/s.
@export var max_speed := 120.0
## Speed change in m/s per second, for both thrust and braking.
@export var acceleration := 40.0
## Max turn rate in radians per second.
@export var turn_rate := 1.5

var current_order: ShipOrder = null
## Current forward speed in m/s.
var speed := 0.0
## Last autopilot output, kept for UI and debug drawing.
var desired_velocity := Vector3.ZERO
var has_goal := false
var goal_point := Vector3.ZERO
## Physics ticks in which the ship touched something. Avoidance should keep this at zero.
var collision_ticks := 0

var _engine_glow: Node3D


func _ready() -> void:
	add_to_group(Autopilot.SHIP_GROUP)
	motion_mode = MOTION_MODE_FLOATING
	_rebuild()


func give_order(order: ShipOrder) -> void:
	current_order = order
	order_changed.emit(order)


func stop() -> void:
	give_order(null)


func get_nav_radius() -> float:
	return radius


func get_forward() -> Vector3:
	return -global_basis.z


func get_order_label() -> String:
	if current_order != null:
		return current_order.get_label()
	return "Stopping" if speed > 0.5 else "Idle"


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if current_order != null and current_order.is_complete(self):
		give_order(null)

	var goal: NavGoal = current_order.get_goal(self) if current_order != null else null
	desired_velocity = Autopilot.steer(self, goal)
	has_goal = goal != null
	if has_goal:
		goal_point = goal.point
	_fly(delta)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or _engine_glow == null:
		return
	_engine_glow.scale = Vector3.ONE * lerpf(0.3, 1.3, speed / max_speed)


func _fly(delta: float) -> void:
	var target_speed := desired_velocity.length()
	if target_speed > 0.01:
		var wanted := desired_velocity / target_speed
		_turn_towards(wanted, delta)
		# Slow down while the nose points away from where we want to go: makes turns tighter,
		# and a ship that has to turn around almost pivots in place instead of sweeping a wide arc.
		var alignment := (get_forward().dot(wanted) + 1.0) * 0.5
		target_speed *= lerpf(MIN_TURN_SPEED_FACTOR, 1.0, alignment * alignment)

	speed = move_toward(speed, target_speed, acceleration * delta)
	velocity = get_forward() * speed
	move_and_slide()
	if get_slide_collision_count() > 0:
		collision_ticks += 1
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

	var hull_material := StandardMaterial3D.new()
	hull_material.albedo_color = hull_color
	hull_material.metallic = 0.4
	hull_material.roughness = 0.45

	var hull_mesh := CylinderMesh.new()
	hull_mesh.top_radius = 0.0
	hull_mesh.bottom_radius = radius * 0.45
	hull_mesh.height = radius * 2.0
	hull_mesh.radial_segments = 6
	hull_mesh.rings = 1
	var hull := _add_mesh(hull_mesh, hull_material)
	hull.rotation.x = -PI / 2.0  # Cylinder tip (+Y) points forward (-Z).

	var wings_mesh := BoxMesh.new()
	wings_mesh.size = Vector3(radius * 1.8, radius * 0.1, radius * 0.6)
	var wings := _add_mesh(wings_mesh, hull_material)
	wings.position = Vector3(0.0, 0.0, radius * 0.45)

	var glow_material := StandardMaterial3D.new()
	glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_material.albedo_color = Color(1.0, 0.65, 0.3)
	glow_material.emission_enabled = true
	glow_material.emission = Color(1.0, 0.55, 0.2)
	glow_material.emission_energy_multiplier = 4.0
	var glow_mesh := SphereMesh.new()
	glow_mesh.radius = radius * 0.25
	glow_mesh.height = radius * 0.5
	_engine_glow = _add_mesh(glow_mesh, glow_material)
	_engine_glow.position = Vector3(0.0, 0.0, radius)

	var shape := SphereShape3D.new()
	shape.radius = radius
	var collision := CollisionShape3D.new()
	collision.shape = shape
	_add_generated(collision)

	_add_generated(SpaceLabel.create(display_name, radius))


func _add_mesh(mesh: Mesh, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	_add_generated(instance)
	return instance


func _add_generated(node: Node) -> void:
	node.set_meta(&"generated", true)
	add_child(node)
