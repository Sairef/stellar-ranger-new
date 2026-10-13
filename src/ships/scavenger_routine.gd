class_name ScavengerRoutine
extends Node

## Brain of the system scavenger (see SalvageService), placed as a child of a Ship that starts
## docked at `home`: undock, loot the given wrecks with the same LootOrder the player uses, dock
## back at home and leave the game (what it collected is gone with it). On alert it drops the
## job and docks at once.

const GROUP := &"scavengers"

## The station it comes from and returns to, or null once it is gone.
var home: SpaceBody:
	get:
		return _home.resolve() as SpaceBody
	set(value):
		_home = ObjectRef.to(value)

var _ship: Ship
var _home := ObjectRef.new()
var _wrecks: Array = []
var _looted := false
var _been_out := false


## The wrecks to collect.
func setup(station: SpaceBody, wrecks: Array) -> void:
	home = station
	_wrecks = wrecks.map(func(wreck: Node) -> ObjectRef: return ObjectRef.to(wreck))


func _ready() -> void:
	_ship = get_parent() as Ship
	_ship.add_to_group(GROUP)


func _physics_process(_delta: float) -> void:
	var security := SystemSecurity.of(self)
	var alert := security != null and security.alert
	if _ship.is_docked():
		if _been_out:
			_ship.vanish()  # Job done (or cut short): unloads at the station and is gone.
		elif not alert:
			_ship.try_undock()
		return
	if not _ship.is_in_space():
		return
	_been_out = true
	var order := _ship.current_order
	if order != null and not order.is_interruptible():
		return  # Still in the corridor.
	if alert and not order is DockOrder:
		_go_home()
		return
	if order != null:
		return
	if not _looted:
		_looted = true
		var targets := _wrecks.map(func(ref: ObjectRef) -> Node3D: return ref.resolve())
		_ship.give_order(LootOrder.new(targets.filter(func(node: Node3D) -> bool: return node != null)))
	else:
		_go_home()


func _go_home() -> void:
	_looted = true
	var station := home
	if station != null:
		_ship.give_order(DockOrder.new(station))
	else:
		_ship.vanish()  # No station to go back to.
