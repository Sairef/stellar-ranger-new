class_name OrbitOrder
extends ShipOrder

## Circle around a target at a given distance from its surface (EVE-style orbit).
##
## The orbit can lie in any plane. The natural plane is the one the ship is already moving in,
## so it keeps turning the way it goes instead of making a U-turn. If that circle would cut
## through an obstacle (say, an asteroid next to the target), the plane is tilted around the
## ship-target line until the circle is clear; the ship stays on the new circle. If no tilt
## works, the clearest plane in any direction is used and the ship moves over to it.
## The plane is re-checked every tick and picked again only when it gets blocked.
##
## Each tick the ship chases a point slightly ahead of it on the orbit circle.

## How far ahead on the circle the chased point is, in radians.
const LEAD_ANGLE := 0.35
## Tilt step when looking for a clear plane around the ship-target line, in degrees.
const TILT_STEP := 10.0
## Directions tried when no tilted plane is clear.
const SPHERE_SAMPLES := 64

var target: Node3D
## Desired gap between the ship's hull and the target's surface, in meters.
var distance: float

var _normal := Vector3.ZERO


func _init(p_target: Node3D, p_distance := 100.0) -> void:
	target = p_target
	distance = p_distance


func get_label() -> String:
	return "Orbit %s at %.0f m" % [Autopilot.name_of(target), distance]


func get_target() -> Node3D:
	return target


func get_goal(ship: Ship) -> NavGoal:
	var center := target.global_position
	var offset := ship.global_position - center
	var orbit_radius := Autopilot.radius_of(target) + ship.radius + distance
	var obstacles := ship.get_tree().get_nodes_in_group(Autopilot.OBSTACLE_GROUP)
	if _normal == Vector3.ZERO or _clearance(_normal, center, orbit_radius, ship, obstacles) < 0.0:
		_normal = _pick_normal(ship, center, offset, orbit_radius, obstacles)

	var radial := offset - _normal * offset.dot(_normal)
	if radial.length_squared() < 0.0001:
		radial = _normal.cross(Vector3.UP)
		if radial.length_squared() < 0.0001:
			radial = _normal.cross(Vector3.RIGHT)
	radial = radial.normalized()

	var ahead := radial.rotated(_normal, LEAD_ANGLE)
	# Chasing a point ahead cuts the corner: the ship settles at radius * cos(LEAD_ANGLE).
	# Aiming slightly wider compensates for that.
	return NavGoal.new(center + ahead * orbit_radius / cos(LEAD_ANGLE), false, target)


func is_complete(_ship: Ship) -> bool:
	return not is_instance_valid(target)


## Orbit plane normal: the natural one if it is clear, otherwise the closest clear one.
func _pick_normal(ship: Ship, center: Vector3, offset: Vector3, orbit_radius: float,
		obstacles: Array) -> Vector3:
	var natural := _motion_normal(ship, offset)
	if offset.length_squared() > 0.0001:
		# Tilt around the ship-target line: every such plane still passes through the ship.
		# A tilt of +-90 degrees covers all of them (180 is the same plane flown backwards).
		var axis := offset.normalized()
		for step in range(0, int(90.0 / TILT_STEP) + 1):
			for sign: float in [1.0, -1.0]:
				var candidate := natural.rotated(axis, deg_to_rad(step * TILT_STEP) * sign)
				if _clearance(candidate, center, orbit_radius, ship, obstacles) >= 0.0:
					return candidate

	# The obstacle sits on the ship-target line, so no plane through the ship is clear.
	var best := natural
	var best_clearance := _clearance(natural, center, orbit_radius, ship, obstacles)
	for i in SPHERE_SAMPLES:
		var candidate := _sphere_direction(i, SPHERE_SAMPLES)
		if candidate.dot(natural) < 0.0:
			candidate = -candidate  # Same plane, but keep the natural direction of travel.
		var clearance := _clearance(candidate, center, orbit_radius, ship, obstacles)
		if clearance > best_clearance:
			best = candidate
			best_clearance = clearance
	return best


func _clearance(normal: Vector3, center: Vector3, orbit_radius: float, ship: Ship,
		obstacles: Array) -> float:
	return Autopilot.circle_clearance(center, normal, orbit_radius, ship.radius, obstacles, target)


## Normal of the plane the ship is already moving in.
func _motion_normal(ship: Ship, offset: Vector3) -> Vector3:
	var motion := ship.velocity if ship.velocity.length_squared() > 1.0 else ship.get_forward()
	# Rotating `offset` around offset x motion moves it toward `motion`: the ship keeps its course.
	for candidate in [offset.cross(motion), offset.cross(Vector3.UP), offset.cross(Vector3.RIGHT)]:
		if candidate.length_squared() > 0.0001:
			return candidate.normalized()
	return Vector3.UP


## Evenly spread directions on a unit sphere (Fibonacci lattice).
static func _sphere_direction(index: int, count: int) -> Vector3:
	var y := 1.0 - 2.0 * (index + 0.5) / count
	var ring := sqrt(1.0 - y * y)
	var angle := index * PI * (3.0 - sqrt(5.0))
	return Vector3(cos(angle) * ring, y, sin(angle) * ring)
