class_name MinerRoutine
extends Node

## NPC miner brain, placed as a child of a Ship: undock from the home station, fly into the
## asteroid field, mine a rock until the hold is full, fly home, dock and unload. Forever.
## Miners claim their rock, so two miners never work the same one.

const GROUP := &"miners"

enum Step { GO_TO_ROCK, MINE, GO_HOME }

@export var home: NodePath
@export var field: NodePath
## Gap between the hull and the rock surface while mining, in meters.
@export var mining_distance := 25.0
## Seconds docked to unload, random within this range.
@export var unload_time := Vector2(6.0, 12.0)
## If not negative: start docked at home and undock after this many seconds.
@export var start_docked_for := -1.0

## Seconds until the ship undocks (while docked).
var undock_in := 0.0

## Rock -> miner currently working it.
static var _claimed_rocks := {}

var _ship: Ship
var _rng := RandomNumberGenerator.new()
var _step := Step.GO_TO_ROCK
var _rock: Asteroid = null


func _ready() -> void:
	_ship = get_parent() as Ship
	_ship.add_to_group(GROUP)
	_rng.seed = hash(_ship.display_name)
	_ship.docked.connect(_on_docked)
	if start_docked_for >= 0.0:
		# Dock before the ship's first physics tick: it may be placed inside the station.
		# In a scene, children are ready before their parent, so wait for the ship.
		if _ship.is_node_ready():
			_start_docked()
		else:
			_ship.ready.connect(_start_docked, CONNECT_ONE_SHOT)


func _exit_tree() -> void:
	_release_rock()


func _start_docked() -> void:
	_ship.dock_instantly(get_node(home))
	undock_in = start_docked_for


func _physics_process(delta: float) -> void:
	if _ship.is_docked():
		undock_in -= delta
		if undock_in <= 0.0:
			_ship.try_undock()
		return
	if _ship.current_order != null:
		return

	match _step:
		Step.GO_TO_ROCK:
			_rock = _claim_rock()
			if _rock == null:
				_step = Step.GO_HOME
				return
			_ship.give_order(ApproachOrder.new(_rock, mining_distance, true))
			_step = Step.MINE
		Step.MINE:
			_step = Step.GO_HOME
			if is_instance_valid(_rock) and _ship.cargo < _ship.cargo_capacity:
				_ship.give_order(MineOrder.new(_rock, mining_distance))
		Step.GO_HOME:
			_release_rock()
			_ship.give_order(DockOrder.new(get_node(home)))
			_step = Step.GO_TO_ROCK


func _on_docked(_station: SpaceBody) -> void:
	_ship.cargo = 0.0  # Unloaded while docked.
	_step = Step.GO_TO_ROCK
	undock_in = _rng.randf_range(unload_time.x, unload_time.y)


func _claim_rock() -> Asteroid:
	var area := get_node_or_null(field) as AsteroidField
	if area == null:
		return null
	var free_rocks: Array[Asteroid] = []
	for rock in area.get_rocks():
		var miner = _claimed_rocks.get(rock)
		if miner == null or not is_instance_valid(miner) or miner == self:
			free_rocks.append(rock)
	if free_rocks.is_empty():
		return null
	var rock := free_rocks[_rng.randi() % free_rocks.size()]
	_claimed_rocks[rock] = self
	return rock


func _release_rock() -> void:
	if _rock != null and _claimed_rocks.get(_rock) == self:
		_claimed_rocks.erase(_rock)
	_rock = null
