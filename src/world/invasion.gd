class_name Invasion
extends Node

## The "Eternal Enemy" invasion event (placeholder faction: invaders, hostile to everyone).
##
## Never starts on its own: start() is called by hand; with `debug_panel` set, the event adds
## a "Start invasion" button there.
## 1. Warm-up: a gate lights up and pulses for `warmup_time` seconds; the system goes on alert,
##    so traders and miners already run for cover and patrols head for the gate.
## 2. Arrival: the fleet comes out of the membrane one ship at a time, side by side in lanes,
##    small ships first, then medium, then large (see ShipClass).
## 3. `reinforcement_delay` seconds after the start the defense station launches its whole
##    garrison (Garrison, also of all three classes).
## 4. Over when the last invader is gone. Invaders hunt anything within detection range and
##    otherwise besiege the defense station; the garrison docks back home after the fight.

signal finished

enum Phase { IDLE, WARMUP, ARRIVING, FIGHTING }

const ShipScene := preload("res://src/ships/ship.tscn")
const INVADER_COLOR := Color(0.75, 0.25, 0.95)
## Free space needed around a lane before the next invader comes out there, in meters.
const LANE_CLEARANCE := 25.0
## Lanes stay within this fraction of the gate opening.
const LANE_SPREAD := 0.5
## Speed of an invader coming out of the membrane, m/s.
const EMERGE_SPEED := 40.0

@export var gates: Array[NodePath] = []
@export var defense_station: NodePath
@export var ships_root: NodePath
@export var debug_panel: DebugPanel
## 0 picks a random gate and lanes every time; anything else repeats the same invasion.
@export var event_seed := 0

@export_group("Fleet")
@export var small_invaders := 4
@export var medium_invaders := 2
@export var large_invaders := 1
@export var warmup_time := 8.0
## Seconds between ships coming out of the gate.
@export var arrival_interval := 1.0
@export var invader_detection := 6000.0

@export_group("Defense")
## Seconds from the start until the defense station launches its garrison.
@export var reinforcement_delay := 15.0

var phase := Phase.IDLE
## Invaders that came through the gate in the current (or last) invasion.
var invaders_arrived := 0

## The gate of the current (or last) invasion, or null.
var gate: Gate:
	get:
		return _gate.resolve() as Gate

var _gate := ObjectRef.new()
var _timer := 0.0
var _queue: Array[Dictionary] = []
var _invaders: Array[ObjectRef] = []
## Seconds until the garrison launches; below 0 once it has (or with no invasion).
var _launch_in := -1.0
## Garrison ships launched from the docks in this invasion (the ones still docked when it is
## over stay home).
var _launched: Array[ObjectRef] = []
var _rng := RandomNumberGenerator.new()
var _button: Button


func _ready() -> void:
	if event_seed != 0:
		_rng.seed = event_seed
	else:
		_rng.randomize()
	if debug_panel != null:
		_button = debug_panel.add_action("Start invasion", start)


func is_running() -> bool:
	return phase != Phase.IDLE


## Ships in the invading fleet.
func fleet_size() -> int:
	return small_invaders + medium_invaders + large_invaders


## The defense station's garrison, or null.
func garrison() -> Garrison:
	return Garrison.of(get_node_or_null(defense_station))


## Invaders still out in space.
func alive_invaders() -> int:
	var count := 0
	for ref in _invaders:
		var ship := ref.resolve() as Ship
		if ship != null and ship.is_in_space():
			count += 1
	return count


## Starts the invasion through `through`, or through a random gate.
func start(through: Gate = null) -> void:
	if phase != Phase.IDLE:
		return
	var chosen := through if through != null else _random_gate()
	if chosen == null:
		return
	_gate = ObjectRef.to(chosen)
	chosen.active = true
	phase = Phase.WARMUP
	_timer = warmup_time
	invaders_arrived = 0
	_invaders.clear()
	_queue = _fleet()
	_launch_in = reinforcement_delay
	var security := SystemSecurity.of(self)
	if security != null:
		security.raise_alert(chosen, warmup_time + _queue.size() * arrival_interval)
	_announce("%s is activating: unknown ships incoming!" % Autopilot.name_of(chosen), true)
	_set_button_ready(false)


func _physics_process(delta: float) -> void:
	if phase == Phase.IDLE:
		return
	_update_reinforcements(delta)
	match phase:
		Phase.WARMUP:
			_timer -= delta
			if gate == null:
				_queue.clear()
				phase = Phase.FIGHTING
			elif _timer <= 0.0:
				phase = Phase.ARRIVING
				_announce("Hostile fleet coming through %s!" % Autopilot.name_of(gate), true)
		Phase.ARRIVING:
			_timer -= delta
			if gate == null:
				_queue.clear()
			if _timer <= 0.0 and not _queue.is_empty() and _try_emerge(_queue.front()):
				_queue.pop_front()
				_timer = arrival_interval
			if _queue.is_empty():
				phase = Phase.FIGHTING
				if gate != null:
					gate.active = false
		Phase.FIGHTING:
			if alive_invaders() == 0:
				_finish()


func _finish() -> void:
	phase = Phase.IDLE
	_launch_in = -1.0
	var defense := garrison()
	if defense != null:
		defense.cancel(_launched)
	_launched.clear()
	if gate != null:
		gate.active = false
	_announce("The invasion has been repelled")
	_set_button_ready(true)
	finished.emit()


## The ships to bring in, in order: small ones first, then medium, then large.
func _fleet() -> Array[Dictionary]:
	var fleet: Array[Dictionary] = []
	for size in ShipClass.sizes(small_invaders, medium_invaders, large_invaders):
		fleet.append({"name": "Invader %d" % (fleet.size() + 1), "class": size})
	return fleet


## Brings one invader out of the gate in a random free lane. Returns false if the lane picked
## this time is not free (try again next tick).
func _try_emerge(spec: Dictionary) -> bool:
	var through := gate
	if through == null:
		return false
	var corridor := through.get_corridor(Gate.ARRIVAL_CORRIDOR)
	var angle := _rng.randf() * TAU
	var offset := sqrt(_rng.randf()) * through.opening_radius() * LANE_SPREAD
	var lane := (through.global_basis.x * cos(angle) + through.global_basis.y * sin(angle)) * offset
	var spawn: Vector3 = corridor["inner"] + lane
	if not _is_clear(spawn, ShipClass.stats(spec["class"]).radius):
		return false

	var ship := ShipScene.instantiate() as Ship
	ship.display_name = spec["name"]
	ship.faction = Factions.INVADER
	ship.hull_color = INVADER_COLOR
	ship.ship_class = spec["class"]
	var routine := CombatRoutine.new()
	routine.detection_range = invader_detection
	routine.assault_target = get_node_or_null(defense_station)
	ship.add_child(routine)
	var heading: Vector3 = corridor["outer"] - corridor["inner"]
	ship.enter_space(get_node(ships_root), Transform3D(Basis.looking_at(heading, Vector3.UP), spawn))
	ship.speed = EMERGE_SPEED
	ship.give_order(LeaveOrder.new(through, Gate.ARRIVAL_CORRIDOR, lane))
	through.flash()
	_invaders.append(ObjectRef.to(ship))
	invaders_arrived += 1
	return true


func _is_clear(point: Vector3, radius: float) -> bool:
	for node in get_tree().get_nodes_in_group(Autopilot.SHIP_GROUP):
		var other := node as Ship
		if point.distance_to(other.global_position) < radius + other.radius + LANE_CLEARANCE:
			return false
	return true


## Waits out the delay, then launches the whole garrison.
func _update_reinforcements(delta: float) -> void:
	if _launch_in < 0.0:
		return
	_launch_in -= delta
	if _launch_in >= 0.0:
		return
	var defense := garrison()
	if defense != null:
		_launched = defense.launch_all()
		_announce("%s launches its garrison" % Autopilot.name_of(get_node_or_null(defense_station)))


func _random_gate() -> Gate:
	var options: Array[Gate] = []
	for path in gates:
		var node := get_node_or_null(path) as Gate
		if node != null:
			options.append(node)
	return options[_rng.randi() % options.size()] if not options.is_empty() else null


func _announce(text: String, warning := false) -> void:
	var security := SystemSecurity.of(self)
	if security != null:
		security.announce(text, warning)


func _set_button_ready(available: bool) -> void:
	if _button == null:
		return
	_button.disabled = not available
	_button.text = "Start invasion" if available else "Invasion in progress"
