extends "res://tests/support/check_suite.gd"

## Headless checks for the HUD layout in the home system: the hostile list hides while docked and
## while the tactical map is open, the alert banner keeps clear of the panels along the bottom
## and on screen, and the selection ring of the station the ship is docked at is not drawn over
## the whole view.
## Run from the project folder (exit code 0 when everything passes):
##   godot --headless --path . --fixed-fps 60 res://tests/hud_checks.tscn

const SystemScene := preload("res://scenes/systems/home_system.tscn")


func _ready() -> void:
	await _docked_station_ring()
	await _panels_and_banner()
	_finish()


## The usual way in: select the station, D, docked. The station stays selected, and from the
## port the camera sees it filling most of the view: its ring must not be drawn over it.
func _docked_station_ring() -> void:
	_begin("The selection ring of the station the ship is docked at is not drawn")
	var system := _home_system()
	var controller := system.get_node("PlayerController") as PlayerController
	var station := system.get_node("Stations/HalcyonExchange") as SpaceBody
	var own := controller.ship
	controller.select(station)
	controller.dock_selected()
	var docked := await _simulate(90.0, func() -> bool: return own.is_docked())
	_check(docked > 0.0 and controller.selected == station, "docked with the station selected (%.0f s)" % docked)
	await _frames(30)
	var ring := controller.get("_marker") as Sprite3D
	var share: float = controller.call("_projected_radius", station) * PlayerController.RING_SCALE \
			/ get_viewport().get_visible_rect().size.y
	_check(not ring.visible, "no ring around the station from its port (it would be %.0f%% of the screen height)"
			% (share * 100.0))
	await _end()


## The banner sits between the panels along the bottom, docked and out in space, and stays on
## screen whatever the window's shape.
func _panels_and_banner() -> void:
	_begin("Hostile list and banner placement, docked, in space and with the map open")
	var original_size := get_window().size
	get_window().size = Vector2i(1152, 648)
	var system := _home_system()
	var controller := system.get_node("PlayerController") as PlayerController
	var hud := system.get_node("Hud") as Hud
	var raids := system.get_node("PirateRaids") as PirateRaids
	var own := controller.ship
	own.dock_instantly(system.get_node("Stations/HalcyonExchange") as SpaceBody, 0)
	# The longest message: the raid warning naming when the squad comes.
	raids.start(system.get_node("Gates/WestGate") as Gate)
	await _frames(5)
	var banner := hud.get("_banner") as Label
	var list := hud.get("_hostile_list") as Control
	var station_window := hud.get("_station_window") as Control
	var minimap := hud.get("_minimap") as Control
	_check(not list.visible and station_window.visible, "docked: the station window shows, the hostile list does not")
	_check(not banner.get_global_rect().intersects(station_window.get_global_rect()),
			"docked: the banner keeps clear of the station window (Undock)")

	controller.undock()
	await _simulate(20.0, func() -> bool: return own.is_in_space())
	await _frames(5)
	_check(list.visible, "in space: the hostile list shows")
	_check(not banner.get_global_rect().intersects(list.get_global_rect())
			and not banner.get_global_rect().intersects(minimap.get_global_rect()),
			"in space: the banner keeps clear of the hostile list and the minimap")
	_check(banner.get_global_rect().position.y >= 0.0, "16:9 window: the banner is on screen (%s)"
			% banner.get_global_rect())

	var map := hud.get("_map") as TacticalMap
	map.open()
	await _frames(5)
	_check(not list.visible, "the map open: the hostile list hides")
	map.close()

	# A squarer window: the minimap grows with the height and squeezes the room left for the
	# banner between it and the (wider) hostile list.
	get_window().size = Vector2i(1152, 1152)
	await _frames(5)
	var rect := banner.get_global_rect()
	_check(rect.position.y >= 0.0, "square window: the warning stays on screen (%.0f px wide, top at %.0f)"
			% [rect.size.x, rect.position.y])
	get_window().size = original_size
	await _end()


func _home_system() -> Node3D:
	var system := SystemScene.instantiate() as Node3D
	(system.get_node("PirateRaids") as PirateRaids).auto = false
	_world.add_child(system)
	return system


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
