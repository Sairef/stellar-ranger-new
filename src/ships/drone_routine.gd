class_name DroneRoutine
extends Node

## Brain of a cargo drone (see DroneBay), placed as a child of the drone Ship: fly to the wreck,
## load for LOAD_TIME with the work beam on it, fly back to the mother ship and land in it.
## Takes only what fits into the mother ship's hold; turns back as soon as the wreck is gone;
## is gone itself when the mother ship is.

const GROUP := &"drones"
## Seconds spent loading at the wreck.
const LOAD_TIME := 2.0
## Gap between the drone and the wreck's surface while loading, in meters.
const LOAD_DISTANCE := 6.0
## The drone lands once its hull is this close to the mother ship's hull, in meters.
const LAND_GAP := 8.0

enum Step { OUT, LOADING, BACK }

## The ship the drone belongs to, or null once it is gone.
var mother: Ship:
	get:
		return _mother.resolve() as Ship
	set(value):
		_mother = ObjectRef.to(value)
## The wreck to load from, or null once it is gone.
var wreck: Wreck:
	get:
		return _wreck.resolve() as Wreck
	set(value):
		_wreck = ObjectRef.to(value)

var step := Step.OUT

var _ship: Ship
var _mother := ObjectRef.new()
var _wreck := ObjectRef.new()
var _timer := 0.0


func _ready() -> void:
	_ship = get_parent() as Ship
	_ship.add_to_group(GROUP)


func _physics_process(delta: float) -> void:
	if not _ship.is_in_space():
		return
	var home := mother
	if home == null or not home.is_in_space() or home.get_drone_bay() == null:
		_ship.vanish()  # Nowhere to go back to.
		return
	var target := wreck
	match step:
		Step.OUT:
			if target == null:
				_go_back()
			elif _gap_to(target) <= LOAD_DISTANCE + ApproachOrder.ARRIVE_TOLERANCE and _ship.speed < 5.0:
				_ship.give_order(null)
				step = Step.LOADING
				_timer = LOAD_TIME
			elif _ship.current_order == null:
				_ship.give_order(ApproachOrder.new(target, LOAD_DISTANCE))
		Step.LOADING:
			if target == null:
				_go_back()
				return
			_ship.beam_target = target.global_position
			_timer -= delta
			if _timer <= 0.0:
				_load(target, home.get_drone_bay())
				_go_back()
		Step.BACK:
			if _gap_to(home) <= LAND_GAP:
				home.get_drone_bay().land(_ship)
			elif _ship.current_order == null:
				_ship.give_order(ApproachOrder.new(home, 0.0))


func _load(target: Wreck, bay: DroneBay) -> void:
	target.cargo.move_to(_ship.cargo, bay.room_left())
	if not target.cargo.is_empty():
		bay.out_of_space = true


func _go_back() -> void:
	step = Step.BACK
	_ship.give_order(null)


func _gap_to(node: Node3D) -> float:
	return _ship.global_position.distance_to(node.global_position) - Autopilot.radius_of(node) - _ship.radius
