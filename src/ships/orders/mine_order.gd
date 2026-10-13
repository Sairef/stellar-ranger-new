class_name MineOrder
extends ShipOrder

## Hold position next to a rock, nose toward it, and mine with the beam until the hold is full.
## Mining only happens while the ship is (almost) stopped. Ends if the rock is gone.

## Pieces of ore mined per second.
const MINING_RATE := 4.0
const MINING_MAX_SPEED := 2.0

## The live rock, or null once it is gone.
var rock: Node3D:
	get:
		return _rock.resolve()
## Gap between the hull and the rock surface, in meters.
var distance: float

var _rock: ObjectRef
## Ore mined but not yet a whole piece.
var _progress := 0.0


func _init(p_rock: Node3D, p_distance := 25.0) -> void:
	_rock = ObjectRef.to(p_rock)
	distance = p_distance


func get_label() -> String:
	return "Mining %s" % Autopilot.name_of(rock)


func get_target() -> Node3D:
	return rock


func update(ship: Ship, delta: float) -> void:
	var node := rock
	if node == null or ship.speed > MINING_MAX_SPEED:
		ship.beam_target = null
		return
	_progress += MINING_RATE * delta
	var pieces := floori(_progress)
	if pieces > 0:
		_progress -= pieces
		ship.cargo.add(Items.ORE, pieces)
	# Aim at the visible surface (the rock mesh is dented inward from its radius).
	var to_ship := (ship.global_position - node.global_position).normalized()
	ship.beam_target = node.global_position + to_ship * Autopilot.radius_of(node) * 0.8


func get_goal(ship: Ship) -> NavGoal:
	var node := rock
	if node == null:
		return null
	var away := (ship.global_position - node.global_position).normalized()
	var stand_off := Autopilot.radius_of(node) + ship.radius + distance
	var goal := NavGoal.new(node.global_position + away * stand_off, true, node)
	goal.face_point = node.global_position
	return goal


func is_complete(ship: Ship) -> bool:
	return rock == null or ship.cargo.room() < 1.0
