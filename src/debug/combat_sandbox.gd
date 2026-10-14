class_name CombatSandbox
extends Node3D

## Test bed for combat: the player and one small pirate among a few rocks.
## Debug panel buttons spawn more pirates of each class, switch the player's ship to the next
## class and fit it with modules, so fights between classes, at different distances, with and
## without modules can be tried; the PlayerRespawner gives the player a new ship.

## How far from the player new pirates appear, in meters.
const SPAWN_DISTANCE := 1500.0

@export var controller: PlayerController
@export var debug_panel: DebugPanel
@export var respawner: PlayerRespawner
@export var ships_root: Node3D

var _pirates := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 42
	_pirates = get_tree().get_node_count_in_group(CombatRoutine.GROUP)
	for size: ShipClass.Size in [ShipClass.Size.SMALL, ShipClass.Size.MEDIUM, ShipClass.Size.LARGE]:
		debug_panel.add_action("Spawn %s pirate" % ShipClass.name_of(size), spawn_pirate.bind(size))
	debug_panel.add_action("Player: next class", next_player_class)
	debug_panel.add_action("Player: fit modules", fit_player_modules)


func spawn_pirate(size := ShipClass.Size.SMALL) -> Ship:
	_pirates += 1
	var ship := PirateRaids.create_pirate("Pirate %d" % _pirates, size)
	var center := controller.ship.global_position if controller.has_ship() else respawner.spawn_point
	var direction := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.15, 0.15), _rng.randf_range(-1, 1))
	direction = direction.normalized()
	ship.enter_space(ships_root, Transform3D(Basis.looking_at(-direction, Vector3.UP),
			center + direction * SPAWN_DISTANCE))
	return ship


func respawn_player() -> void:
	respawner.respawn()


## Turns the player's ship into the next class: small, medium, large, small again.
func next_player_class() -> void:
	var own := controller.ship
	if own == null or own.is_pod:
		return
	var next := ShipClass.next(own.ship_class)
	own.set_ship_class(next if next != ShipClass.Size.CUSTOM else ShipClass.Size.SMALL)


## Fits the player's ship with every module a station sells that it does not have yet.
func fit_player_modules() -> void:
	var own := controller.ship
	if own == null or own.is_pod:
		return
	for type in StationServices.modules():
		if own.find_part(type) == null:
			own.add_child(type.new())
