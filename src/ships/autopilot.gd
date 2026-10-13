class_name Autopilot
extends RefCounted

## Turns a NavGoal into a desired velocity: where to fly and how fast,
## steering around obstacles (asteroids, later stations) and other ships.
##
## Stateless on purpose: every input comes from the ship and the scene groups,
## which makes the behaviour easy to reason about and to test headless.
##
## Layers:
## 1. Obstacles are spheres inflated by a safety bubble. If the straight line to the goal
##    crosses a bubble, the ship heads along the tangent of that bubble. If the tangent line
##    itself crosses another bubble, the planner repeats for that one (see plan_direction()).
##    Rocks whose bubbles overlap are treated as one big sphere (see _merge_cluster()).
## 2. Traffic: ships predict the closest approach to every nearby ship, sidestep if it is
##    too close and slow down the more urgent the sidestep is (see traffic_avoidance()).
##    Drones take no part in it: ships ignore them, and they ignore ships.
## 3. Parking: an arrival point taken by another ship slides sideways (see free_parking_spot()).
##
## Known limits: dense asteroid fields need real path planning (merged bubbles get huge),
## and ships cannot strafe, so they dodge only by turning and braking.

## Static things ships must fly around. Members implement get_nav_radius().
const OBSTACLE_GROUP := &"nav_obstacles"
## All ships. Members are Ship nodes.
const SHIP_GROUP := &"ships"

## Gap kept between a ship's hull and an obstacle's surface, in meters.
const OBSTACLE_MARGIN := 25.0
## The tangent is aimed slightly wider than the bubble so turn lag does not cut into it.
const TANGENT_SLACK := 1.05
## How many obstacles in a row the planner considers when one detour leads into another.
const MAX_DETOURS := 3
## Closer than this to an arrival goal the ship stops steering, in meters.
const ARRIVE_EPSILON := 2.0
## Fraction of the ship's acceleration used for planned braking. Leaves room for turns.
const BRAKING_FACTOR := 0.8
## How strongly the current motion keeps the chosen detour side (hysteresis).
const SIDE_HYSTERESIS := 0.3

## How far ahead ships predict each other's motion, in seconds.
const TRAFFIC_HORIZON := 4.0
## Gap kept between two ship hulls, in meters.
const TRAFFIC_MARGIN := 15.0
## How hard traffic avoidance pulls compared to the goal direction.
const TRAFFIC_WEIGHT := 2.0
## Gap kept between the hulls of ships parked next to each other, in meters.
## Wider than TRAFFIC_MARGIN so neighbours can turn around and leave at the same time.
const PARKING_MARGIN := 35.0


## Main entry point, called by Ship every physics tick. Returns zero to brake.
## May move `goal.point` when the arrival spot is taken by another ship.
static func steer(ship: Ship, goal: NavGoal) -> Vector3:
	if goal == null:
		return Vector3.ZERO
	var tree := ship.get_tree()
	var ships := tree.get_nodes_in_group(SHIP_GROUP)
	var obstacles := tree.get_nodes_in_group(OBSTACLE_GROUP)
	if goal.arrive:
		goal.point = free_parking_spot(ship, goal, ships)
	goal.point = push_out_of_obstacles(goal.point, ship.radius, obstacles, goal.ignore)

	var from := ship.global_position
	var distance := from.distance_to(goal.point)
	if distance < ARRIVE_EPSILON:
		return Vector3.ZERO

	var speed := minf(ship.max_speed, goal.speed)
	if goal.arrive:
		speed = minf(speed, sqrt(2.0 * ship.acceleration * BRAKING_FACTOR * distance))

	var direction := plan_direction(from, goal.point, ship.radius, ship.velocity, ship.global_basis.x,
			obstacles, goal.ignore)
	var avoidance := traffic_avoidance(ship, ships, direction)
	if avoidance != Vector3.ZERO:
		direction = (direction + avoidance).normalized()
		# The more urgent the sidestep, the slower we go: a ship that cannot dodge in time
		# (e.g. in the middle of turning around) at least does not ram anyone at full speed.
		speed /= 1.0 + avoidance.length()
	return direction * speed


## Direction to fly from `from` toward `to` without entering any obstacle's safety bubble.
## `velocity` and `right` only help to pick a side when the goal is dead behind an obstacle.
static func plan_direction(from: Vector3, to: Vector3, ship_radius: float, velocity: Vector3,
		right: Vector3, obstacles: Array, ignore: Node3D = null) -> Vector3:
	var target := to
	var skipped: Array = [ignore]
	for i in MAX_DETOURS:
		var blocker := _first_blocker(from, target, ship_radius, obstacles, skipped)
		if blocker.is_empty():
			break
		var center: Vector3 = blocker["center"]
		var bubble: float = blocker["bubble"]
		var direction := _tangent_direction(from, target, center, bubble, velocity, right)
		# Next iteration checks the way to the tangent point for other obstacles.
		var to_center := from.distance_to(center)
		var reach := sqrt(maxf(to_center * to_center - bubble * bubble, 0.0))
		target = from + direction * maxf(reach, bubble)
		skipped.append_array(blocker["nodes"])
	var result := target - from
	return result.normalized() if result.length_squared() > 0.0001 else Vector3.ZERO


## Sidestep vector that keeps the ship clear of other ships, or zero if nobody is in the way.
static func traffic_avoidance(ship: Ship, ships: Array, heading: Vector3) -> Vector3:
	var result := Vector3.ZERO
	if ship.is_drone:
		return result
	var position := ship.global_position
	for node in ships:
		var other := node as Ship
		if other == null or other == ship or other.is_drone:
			continue
		var offset := other.global_position - position
		# Big ships are slow to turn and to stop: they keep more room, half their combined size.
		var size := ship.radius + other.radius
		var safe := size + maxf(TRAFFIC_MARGIN, 0.5 * size)
		var reach := safe + (ship.max_speed + other.max_speed) * TRAFFIC_HORIZON
		if offset.length() > reach:
			continue

		# Closest approach if both keep their current velocities.
		var relative_velocity := other.velocity - ship.velocity
		var time := 0.0
		var rv2 := relative_velocity.length_squared()
		if rv2 > 0.0001:
			time = clampf(-offset.dot(relative_velocity) / rv2, 0.0, TRAFFIC_HORIZON)
		var closest := offset + relative_velocity * time
		var miss := closest.length()
		if miss >= safe:
			continue

		# Sidestep away from where the other ship will be. The closer to a nose-to-nose meeting,
		# the more both ships also turn to their own right, like ships at sea, so they never
		# dodge into each other.
		var closeness := 1.0 - miss / safe
		var away := -closest
		away -= heading * away.dot(heading)
		away = away.normalized() if away.length_squared() > 0.0001 else Vector3.ZERO
		away += ship.global_basis.x * closeness
		var urgency := (1.0 - time / TRAFFIC_HORIZON) * closeness
		result += away.normalized() * urgency * TRAFFIC_WEIGHT
	return result


## Ships approaching the same target from the same side would all try to stop at the same spot.
## If another ship is too close to the arrival point, the point slides sideways around the
## goal's target (keeping the same distance to it) until there is room.
static func free_parking_spot(ship: Ship, goal: NavGoal, ships: Array) -> Vector3:
	var point := goal.point
	if ship.is_drone:
		return point
	var axis := Vector3.ZERO
	if is_instance_valid(goal.ignore):
		axis = (point - goal.ignore.global_position).normalized()
	for node in ships:
		var other := node as Ship
		if other == null or other == ship or other.is_drone:
			continue
		# Big neighbours need more room to turn around and leave (see traffic_avoidance()).
		var size := ship.radius + other.radius
		var safe := size + maxf(PARKING_MARGIN, size)
		var offset := point - other.global_position
		var distance := offset.length()
		if distance >= safe:
			continue
		var push := offset if offset.length_squared() > 0.01 \
				else ship.global_position - other.global_position
		push -= axis * push.dot(axis)
		if push.length_squared() < 0.01:
			push = ship.global_basis.x - axis * ship.global_basis.x.dot(axis)
		point += push.normalized() * (safe - distance)
	return point


## A goal inside an obstacle's safety bubble cannot be reached without scraping the rock
## (e.g. an orbit circle or a clicked point that cuts through it). Moves the goal out to the
## bubble surface, so the ship flies around the rock instead.
static func push_out_of_obstacles(point: Vector3, ship_radius: float, obstacles: Array,
		ignore: Node3D = null) -> Vector3:
	for node in obstacles:
		var obstacle := node as Node3D
		if obstacle == null or obstacle == ignore:
			continue
		var bubble := radius_of(obstacle) + ship_radius + OBSTACLE_MARGIN
		var offset := point - obstacle.global_position
		var distance := offset.length()
		if distance >= bubble:
			continue
		var direction := offset / distance if distance > 0.01 else Vector3.UP
		point = obstacle.global_position + direction * bubble
	return point


## How far a circle (an orbit) passes from the nearest obstacle bubble, in meters.
## Negative means the circle cuts through a bubble; INF means there are no obstacles.
static func circle_clearance(center: Vector3, normal: Vector3, circle_radius: float,
		ship_radius: float, obstacles: Array, ignore: Node3D = null) -> float:
	var result := INF
	for node in obstacles:
		var obstacle := node as Node3D
		if obstacle == null or obstacle == ignore:
			continue
		var bubble := radius_of(obstacle) + ship_radius + OBSTACLE_MARGIN
		var offset := obstacle.global_position - center
		var height := offset.dot(normal)
		var in_plane := (offset - normal * height).length()
		var gap := sqrt(height * height + pow(in_plane - circle_radius, 2.0)) - bubble
		result = minf(result, gap)
	return result


## Collision/avoidance radius of any space object (0 if it has none).
## Deliberately untyped: callers may hold a reference to an object that has been freed
## (e.g. a ship that jumped out), and a typed parameter would fail before the check below.
static func radius_of(node: Variant) -> float:
	if is_instance_valid(node) and node.has_method(&"get_nav_radius"):
		return node.get_nav_radius()
	return 0.0


## Display name of any space object, for UI. "-" for nothing or a freed object.
## Untyped for the same reason as radius_of().
static func name_of(node: Variant) -> String:
	if not is_instance_valid(node):
		return "-"
	var display_name = node.get(&"display_name")
	return display_name if display_name is String else String(node.name)


## Nearest obstacle (or cluster of obstacles) whose safety bubble crosses the segment from -> to.
## Returns {nodes, center, bubble} or an empty dictionary.
static func _first_blocker(from: Vector3, to: Vector3, ship_radius: float, obstacles: Array,
		skipped: Array) -> Dictionary:
	var path := to - from
	var length := path.length()
	if length < 0.001:
		return {}
	var direction := path / length

	var best := {}
	var best_distance := INF
	for node in obstacles:
		var obstacle := node as Node3D
		if obstacle == null or obstacle in skipped:
			continue
		var center := obstacle.global_position
		var to_center := center - from
		if to_center.dot(direction) <= 0.0:
			continue  # Behind us or beside us: flying on cannot hit it.

		var contact := radius_of(obstacle) + ship_radius
		var bubble := contact + OBSTACLE_MARGIN
		var goal_gap := to.distance_to(center)
		if goal_gap < bubble:
			if goal_gap <= contact:
				continue  # The goal is inside the obstacle; nothing sensible to steer around.
			# The goal is close to this obstacle: shrink the bubble so the goal stays reachable.
			bubble = (goal_gap + contact) * 0.5

		var along := clampf(to_center.dot(direction), 0.0, length)
		var miss := (to_center - direction * along).length()
		if miss >= bubble:
			continue
		var distance := to_center.length() - bubble
		if distance < best_distance:
			best_distance = distance
			best = {"nodes": [obstacle], "center": center, "bubble": bubble}
	if best.is_empty():
		return best
	return _merge_cluster(best, from, to, ship_radius, obstacles, skipped)


## Rocks whose safety bubbles overlap leave no safe gap between them, so the ship must go
## around the whole group. Replaces the blocker with a sphere enclosing all such neighbours.
## Keeps the single blocker when the ship or the goal is inside the merged sphere
## (e.g. mining inside a field); proper path planning for dense fields is future work.
static func _merge_cluster(blocker: Dictionary, from: Vector3, to: Vector3, ship_radius: float,
		obstacles: Array, skipped: Array) -> Dictionary:
	var members: Array = blocker["nodes"].duplicate()
	var queue: Array = members.duplicate()
	while not queue.is_empty():
		var current: Node3D = queue.pop_back()
		var current_bubble := radius_of(current) + ship_radius + OBSTACLE_MARGIN
		for node in obstacles:
			var other := node as Node3D
			if other == null or other in members or other in skipped:
				continue
			var other_bubble := radius_of(other) + ship_radius + OBSTACLE_MARGIN
			if current.global_position.distance_to(other.global_position) < current_bubble + other_bubble:
				members.append(other)
				queue.append(other)
	if members.size() == 1:
		return blocker

	var center: Vector3 = members[0].global_position
	var bubble := radius_of(members[0]) + ship_radius + OBSTACLE_MARGIN
	for i in range(1, members.size()):
		var member_center: Vector3 = members[i].global_position
		var member_bubble := radius_of(members[i]) + ship_radius + OBSTACLE_MARGIN
		var distance := center.distance_to(member_center)
		if distance + member_bubble <= bubble:
			continue  # Already inside.
		if distance + bubble <= member_bubble:
			center = member_center
			bubble = member_bubble
			continue
		var merged := (distance + bubble + member_bubble) * 0.5
		center += (member_center - center) / distance * (merged - bubble)
		bubble = merged

	if from.distance_to(center) < bubble or to.distance_to(center) < bubble:
		return blocker
	return {"nodes": members, "center": center, "bubble": bubble}


## Direction that grazes the bubble around `center` on the side of the goal.
static func _tangent_direction(from: Vector3, to: Vector3, center: Vector3, bubble: float,
		velocity: Vector3, right: Vector3) -> Vector3:
	var to_center := center - from
	var distance := to_center.length()
	var axis := to_center / distance

	# Pass on the side where the goal is. Current motion adds hysteresis so the choice
	# does not flip every tick when the goal is almost exactly behind the obstacle.
	var side := _perpendicular((to - from).normalized(), axis)
	if velocity.length_squared() > 1.0:
		side += _perpendicular(velocity.normalized(), axis) * SIDE_HYSTERESIS
	for fallback in [right, Vector3.UP, Vector3.RIGHT]:
		if side.length_squared() > 0.0001:
			break
		side = _perpendicular(fallback, axis)
	side = side.normalized()

	if distance <= bubble:
		# Already inside the safety bubble: slide along it and push outward.
		var depth := 1.0 - distance / bubble
		return (side - axis * (0.3 + 2.0 * depth)).normalized()
	var angle := asin(minf(1.0, bubble * TANGENT_SLACK / distance))
	return (axis * cos(angle) + side * sin(angle)).normalized()


static func _perpendicular(v: Vector3, axis: Vector3) -> Vector3:
	return v - axis * v.dot(axis)
