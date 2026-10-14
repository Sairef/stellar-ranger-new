class_name SalvageService
extends Node

## Keeps the system clean. Wrecks and containers left alone for `abandon_time` are collected by
## a scavenger ship from `station` (see ScavengerRoutine): it undocks, loots them with its drones,
## docks back and is gone, and so is the loot. It is an ordinary neutral ship, though, and
## unarmed: whoever destroys it finds what it had collected in its wreck.
## One scavenger at a time, none while the system is on alert.
## With `debug_panel` set, adds an "Age wrecks +10 min" button there.

const ShipScene := preload("res://src/ships/ship.tscn")
const SCAVENGER_COLOR := Color(0.85, 0.75, 0.35)

@export var station: NodePath
## Node the scavenger ship is added to.
@export var ships_root: NodePath
@export var debug_panel: DebugPanel
## Seconds a wreck lies around before the scavenger comes for it.
@export var abandon_time := 600.0
## Seconds between looks for abandoned wrecks.
@export var check_interval := 5.0

var scavengers_launched := 0

## The scavenger out on a job right now, or null.
var scavenger: Ship:
	get:
		return _scavenger.resolve() as Ship

var _scavenger := ObjectRef.new()
var _check_in := 0.0


func _ready() -> void:
	if debug_panel != null:
		debug_panel.add_action("Age wrecks +10 min", age_wrecks.bind(600.0))


## Debug: makes every wreck and container older, so the scavenger comes sooner.
func age_wrecks(seconds: float) -> void:
	for node in get_tree().get_nodes_in_group(Wreck.GROUP):
		(node as Wreck).age += seconds
	_check_in = 0.0


## Wrecks and containers older than `abandon_time` that still hold something.
func abandoned_wrecks() -> Array[Wreck]:
	var result: Array[Wreck] = []
	for node in get_tree().get_nodes_in_group(Wreck.GROUP):
		var wreck := node as Wreck
		if wreck.age >= abandon_time and not wreck.cargo.is_empty():
			result.append(wreck)
	return result


func _physics_process(delta: float) -> void:
	_check_in -= delta
	if _check_in > 0.0:
		return
	_check_in = check_interval
	if scavenger != null:
		return
	var security := SystemSecurity.of(self)
	if security != null and security.alert:
		return
	var wrecks := abandoned_wrecks()
	if not wrecks.is_empty():
		_launch(wrecks)


func _launch(wrecks: Array[Wreck]) -> void:
	var home := get_node_or_null(station) as SpaceBody
	if home == null:
		return
	scavengers_launched += 1
	var ship := ShipScene.instantiate() as Ship
	ship.name = "Scavenger%d" % scavengers_launched
	ship.display_name = "Scavenger"
	ship.hull_color = SCAVENGER_COLOR
	ship.radius = 12.0
	ship.max_speed = 90.0
	ship.acceleration = 25.0
	ship.turn_rate = 1.0
	ship.cargo_capacity = 2000.0
	ship.remove_weapon()
	var bay := DroneBay.new()
	bay.drones = 4
	ship.add_child(bay)
	var routine := ScavengerRoutine.new()
	routine.setup(home, wrecks)
	ship.add_child(routine)
	var corridor := scavengers_launched % home.get_corridor_count()
	ship.enter_space(get_node(ships_root), Transform3D(Basis.IDENTITY, home.get_corridor(corridor)["inner"]))
	ship.dock_instantly(home, corridor)
	_scavenger = ObjectRef.to(ship)
