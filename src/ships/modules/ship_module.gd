class_name ShipModule
extends Node

## A module fitted to a ship, placed as a child of a Ship (like the Weapon): something the pilot
## switches on at the right moment. Activating takes `energy_cost` from the ship's energy
## (Ship.energy, it recharges by itself); a module with a `duration` keeps its effect up for that
## many seconds. Once the effect is over the module needs `cooldown` seconds before the next use.
## The player and NPC brains switch modules on the same way (activate()), next to the ship's
## current order, not instead of it. Modules work only out in space: docking switches an active
## one off. Stations sell them (StationServices); a destroyed ship loses its modules.
## Subclasses set their numbers in _init() and apply their effect in _start() and _stop().

signal activated

## Shown in the HUD and the station window.
var title := "Module"
var energy_cost := 30.0
## Seconds the effect lasts; 0 for an instant one.
var duration := 0.0
## Seconds after the effect before the module can be used again.
var cooldown := 1.0
## Sound played at the ship when the module switches on (see Sfx).
var sound := &""

var _ship: Ship
var _active_left := 0.0
var _cooldown_left := 0.0


func _ready() -> void:
	_ship = get_parent() as Ship


func is_active() -> bool:
	return _active_left > 0.0


## Out in space, not busy, not cooling down, enough energy, and the effect would do something.
func can_activate() -> bool:
	return _ship != null and _ship.is_in_space() and not is_active() and _cooldown_left <= 0.0 \
			and _ship.energy >= energy_cost and _is_useful(_ship)


## Switches the module on if it can be (see can_activate()). Returns whether it did.
func activate() -> bool:
	if not can_activate():
		return false
	_ship.energy -= energy_cost
	if duration > 0.0:
		_active_left = duration
	else:
		_cooldown_left = cooldown
	_start(_ship)
	if not sound.is_empty():
		Sfx.play_at(_ship, sound, _ship.global_position)
	activated.emit()
	return true


## "ready", "active 4 s", "cooldown 2 s", "needs 40 energy" and the like, for the HUD.
func get_state_text() -> String:
	if _ship != null and not _ship.is_in_space():
		return "offline"
	if is_active():
		return "active %d s" % ceili(_active_left)
	if _cooldown_left > 0.0:
		return "cooldown %d s" % ceili(_cooldown_left)
	if _ship != null and _ship.energy < energy_cost:
		return "needs %.0f energy" % energy_cost
	if _ship != null and not _is_useful(_ship):
		return "not needed"
	return "ready"


func _physics_process(delta: float) -> void:
	if _ship == null:
		return
	if is_active():
		_active_left -= delta
		if _active_left <= 0.0 or not _ship.is_in_space():
			_active_left = 0.0
			_cooldown_left = cooldown
			_stop(_ship)
	elif _cooldown_left > 0.0:
		_cooldown_left = maxf(0.0, _cooldown_left - delta)


## Whether switching on now would do anything (e.g. no point boosting a full shield).
func _is_useful(_on: Ship) -> bool:
	return true


func _start(_on: Ship) -> void:
	pass


## Ends the effect of a module with a duration.
func _stop(_on: Ship) -> void:
	pass
