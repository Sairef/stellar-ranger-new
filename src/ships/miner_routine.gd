class_name MinerRoutine
extends Node

## NPC miner brain, placed as a child of a Ship: undock from the home station, fly into the
## asteroid field, mine a rock until the hold is full, fly home, dock and unload. Forever.
## Miners claim their rock, so two miners never work the same one.
## On alert (SystemSecurity) a miner in space drops its work and runs home to dock; a docked miner
## stays docked until the all clear.

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

## Rock id -> id of the miner ship working it.
static var _claimed_rocks := {}

var _ship: Ship
var _rng := RandomNumberGenerator.new()
var _step := Step.GO_TO_ROCK
var _rock := ObjectRef.new()
## Already running home because of the current alert.
var _sheltering := false


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
	var station := get_node_or_null(home) as SpaceBody
	if station != null:
		_ship.dock_instantly(station)
		undock_in = start_docked_for


func _physics_process(delta: float) -> void:
	var security := SystemSecurity.of(self)
	var alert := security != null and security.alert
	if _ship.is_docked():
		if not alert:
			undock_in -= delta
			if undock_in <= 0.0:
				_ship.try_undock()
		return
	if alert:
		_shelter()
		return
	_sheltering = false
	if _ship.current_order != null:
		return

	match _step:
		Step.GO_TO_ROCK:
			var rock := _claim_rock()
			if rock == null:
				_step = Step.GO_HOME
				return
			_rock = ObjectRef.to(rock)
			_ship.give_order(ApproachOrder.new(rock, mining_distance, true))
			_step = Step.MINE
		Step.MINE:
			_step = Step.GO_HOME
			var rock := _rock.resolve()
			if rock != null and _ship.cargo < _ship.cargo_capacity:
				_ship.give_order(MineOrder.new(rock, mining_distance))
		Step.GO_HOME:
			_release_rock()
			var station := get_node_or_null(home) as SpaceBody
			if station == null:
				return  # No home any more: nowhere to unload, so the miner just waits.
			_ship.give_order(DockOrder.new(station))
			_step = Step.GO_TO_ROCK


## Runs home and docks, once per alert.
func _shelter() -> void:
	var order := _ship.current_order
	if _sheltering and order != null:
		return  # Already on the way home.
	if order != null and not order.is_interruptible():
		return  # Finish the corridor first.
	var station := get_node_or_null(home) as SpaceBody
	if station == null:
		return
	_sheltering = true
	_release_rock()
	_ship.give_order(DockOrder.new(station))
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
	var me := WorldRegistry.id_of(_ship)
	for rock in area.get_rocks():
		var miner: int = _claimed_rocks.get(WorldRegistry.id_of(rock), 0)
		if miner == 0 or miner == me or WorldRegistry.find(miner) == null:
			free_rocks.append(rock)
	if free_rocks.is_empty():
		return null
	var rock := free_rocks[_rng.randi() % free_rocks.size()]
	_claimed_rocks[WorldRegistry.id_of(rock)] = me
	return rock


func _release_rock() -> void:
	if _rock.is_set() and _claimed_rocks.get(_rock.id, 0) == _ship.object_id:
		_claimed_rocks.erase(_rock.id)
	_rock = ObjectRef.new()
