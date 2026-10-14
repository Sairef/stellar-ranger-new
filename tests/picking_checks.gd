extends "res://tests/support/check_suite.gd"

## Headless checks for picking objects with the mouse (PlayerController.pick()), in the 3D view,
## on the tactical map and on the minimap.
## Run from the project folder:
##   godot --headless --path . --fixed-fps 60 res://tests/picking_checks.tscn

const ShipScene := preload("res://src/ships/ship.tscn")
const GateScene := preload("res://src/world/gate.tscn")
const StationScene := preload("res://src/world/station.tscn")


func _ready() -> void:
	# The camera sits at the origin looking down -Z.
	var camera := Camera3D.new()
	camera.far = 60000.0
	add_child(camera)
	camera.current = true
	var player := _add(ShipScene, Vector3(0, 0, 200)) as Ship
	var controller := PlayerController.new()
	controller.ship = player
	controller.camera = camera
	add_child(controller)

	# Bug report: aiming at a gate across the system selected a trader in between.
	var gate := _add(GateScene, Vector3(0, 0, -6000))
	var trader := _add(ShipScene, Vector3(20, 0, -1500))
	# A small ship parked in front of a big station must stay clickable.
	var station := _add(StationScene, Vector3(-600, 0, -2000))
	var parked := _add(ShipScene, Vector3(-480, -40, -1700))
	await get_tree().process_frame

	var gate_px := camera.unproject_position(gate.global_position)
	var trader_px := camera.unproject_position(trader.global_position)
	var station_px := camera.unproject_position(station.global_position)
	var parked_px := camera.unproject_position(parked.global_position)
	_check(gate_px.distance_to(trader_px) < PlayerController.PICK_RADIUS,
			"precondition: the trader's click halo covers the gate (%.0f px apart)" % gate_px.distance_to(trader_px))
	_check(controller.pick(gate_px) == gate, "a click on the distant gate selects the gate")
	_check(controller.pick(trader_px) == trader, "a click on the trader selects the trader")
	_check(controller.pick(station_px) == station, "a click on the station selects the station")
	_check(controller.pick(parked_px) == parked, "a click on a ship in front of the station selects the ship")
	_check(controller.pick(parked_px + Vector2(8, 0)) == parked,
			"a click 8 px off that ship still selects the ship, not the station behind")
	_check(controller.pick(Vector2(5, 5)) == null, "a click on empty space selects nothing")

	# Bug report: the selected ship got destroyed and the game crashed on the selection ring.
	# A freed object compares equal to null, so only is_same() shows it is really cleared.
	controller.select(trader)
	(trader as Ship).take_hit(1000.0, player)
	for i in 3:
		await get_tree().process_frame
	_check(is_same(controller.selected, null), "a destroyed selection is cleared (%s)" % controller.selected)

	await _tactical_map(controller, camera)
	await _minimap(controller)

	_finish()


## M opens the map, and its camera becomes the one clicks are picked with. A tight group of
## ships far away can be zoomed apart and each ship clicked. M closes the map again.
func _tactical_map(controller: PlayerController, view_camera: Camera3D) -> void:
	print("\n== Tactical map")
	var map := TacticalMap.new()
	map.controller = controller
	add_child(map)
	var group: Array[Ship] = []
	for i in 5:
		group.append(_add(ShipScene, Vector3(3000 + 12 * i, 0, -2500 + 9 * (i % 2))) as Ship)
	_tap(KEY_M)
	await get_tree().process_frame
	var map_camera := map.get_camera()
	_check(map.is_open and controller.camera == map_camera and map_camera.current,
			"M opens the map, and clicks are picked through its camera")

	map.look_at_point(group[0].global_position)
	var middle := get_viewport().get_visible_rect().size * 0.5
	var first_px := map_camera.unproject_position(group[0].global_position)
	var second_px := map_camera.unproject_position(group[1].global_position)
	_check(first_px.distance_to(second_px) < PlayerController.PICK_RADIUS,
			"precondition: from afar a click cannot tell the ships apart (%.1f px apart)"
			% first_px.distance_to(second_px))
	for i in 12:
		map.zoom_at(middle, 1.0 / TacticalMap.ZOOM_STEP)
	var picked := 0
	for ship in group:
		if controller.pick(map_camera.unproject_position(ship.global_position)) == ship:
			picked += 1
	_check(picked == group.size(), "zoomed in, a click on each icon picks that ship (%d of %d)" % [picked, group.size()])

	_tap(KEY_M)
	await get_tree().process_frame
	_check(not map.is_open and controller.camera == view_camera and view_camera.current,
			"M closes it and gives the 3D view its camera back")
	map.queue_free()


## The minimap follows the ship; real mouse clicks on it select, double clicks fly, the wheel
## zooms, and none of it reaches the 3D view behind it. It hides while the tactical map is open.
func _minimap(controller: PlayerController) -> void:
	print("
== Minimap")
	var player := controller.ship
	var map := TacticalMap.new()
	map.controller = controller
	add_child(map)
	var minimap := Minimap.new()
	minimap.controller = controller
	minimap.map = map
	add_child(minimap)
	minimap.position = Vector2(100, 100)
	minimap.size = Vector2(300, 300)
	var near := _add(ShipScene, player.global_position + Vector3(400, 0, 300)) as Ship
	controller.select(null)
	await get_tree().process_frame
	_check(minimap.visible and minimap.to_local_point(player.global_position).distance_to(minimap.size * 0.5) < 1.0,
			"the minimap is centered on the player's ship")

	var near_px := minimap.position + minimap.to_local_point(near.global_position)
	_click(near_px)
	await get_tree().process_frame
	_check(controller.selected == near, "a click on an icon selects that ship (%s)" % controller.selected)

	var empty_px := minimap.position + Vector2(40, 260)
	var expected := Vector3(player.global_position.x - 110.0 / 300.0 * Minimap.START_SPAN, player.global_position.y,
			player.global_position.z + 110.0 / 300.0 * Minimap.START_SPAN)
	_click(empty_px, true)
	await get_tree().process_frame
	var order := player.current_order as MoveToOrder
	_check(order != null and order.point.distance_to(expected) < 1.0,
			"a double click on empty space flies there, at the ship's height (%s)" % (order.point if order != null else null))
	_check(controller.selected == near, "the 3D view behind got none of the clicks (selection kept)")

	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = empty_px
	get_viewport().push_input(wheel, true)
	_check(minimap.span < Minimap.START_SPAN, "the wheel zooms in (%.0f m across)" % minimap.span)

	map.open()
	await get_tree().process_frame
	_check(not minimap.visible, "hidden while the tactical map is open")
	map.close()
	minimap.queue_free()
	map.queue_free()


## A left click (press and release) at `position` in the viewport, or a double click.
## The position is in the viewport's own pixels (`in_local_coords`): headless, the window is
## scaled, and screen coordinates would land far off.
func _click(position: Vector2, double := false) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.double_click = double and pressed
		event.position = position
		event.global_position = position
		get_viewport().push_input(event, true)


func _tap(keycode: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.pressed = pressed
		get_viewport().push_input(event)


func _add(scene: PackedScene, position: Vector3) -> Node3D:
	var node := scene.instantiate() as Node3D
	add_child(node)
	node.global_position = position
	return node
