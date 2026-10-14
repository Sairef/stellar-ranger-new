extends Node

## Base of the headless check suites: PASS/FAIL bookkeeping, a scenario world, and simulation
## helpers. Any error logged during the run (ErrorLog) fails the suite.
## A suite extends this file, runs its scenarios from _ready() and ends with _finish().

const ErrorLog := preload("res://tests/support/error_log.gd")

## The current scenario's world: _begin() makes a fresh one, _end() frees it.
var _world: Node3D
var _errors := ErrorLog.new()
var _passed := 0
var _failed := 0


func _init() -> void:
	OS.add_logger(_errors)


## Starts a scenario: prints its title and makes a fresh world for it.
func _begin(title: String) -> void:
	print("\n== %s" % title)
	_world = Node3D.new()
	add_child(_world)


## Ends a scenario: frees its world and whatever it left in the scene (wrecks, effects, sounds
## live in the current scene, not in the scenario's world).
func _end() -> void:
	_world.queue_free()
	_world = null
	for child in get_children():
		if child is Wreck or child is FadingEffect or child.is_in_group(Sfx.VOICES_GROUP):
			child.queue_free()
	await get_tree().physics_frame


## Advances the simulation until `done` returns true or `timeout` seconds pass, calling `probe`
## (if given) every tick. Returns the elapsed time, or -1.0 on timeout.
func _simulate(timeout: float, done: Callable, probe := Callable()) -> float:
	var step := 1.0 / Engine.physics_ticks_per_second
	var time := 0.0
	while time < timeout:
		await get_tree().physics_frame
		time += step
		if probe.is_valid():
			probe.call()
		if done.call():
			return time
	return -1.0


func _wait(seconds: float) -> void:
	await _simulate(seconds, func() -> bool: return false)


func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  " + message)
	else:
		_failed += 1
		print("  FAIL  " + message)


## Checks that nothing logged an error, prints the totals and quits (exit code 1 on any failure).
func _finish() -> void:
	_check(_errors.errors.is_empty(), "no errors during the run (%d) %s" % [
			_errors.errors.size(), _errors.errors.slice(0, 5)])
	print("\n%d passed, %d failed" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)
