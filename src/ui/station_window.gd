class_name StationWindow
extends PanelContainer

## Shown while the player's ship is docked: the ship's state and what the station offers
## (StationServices): sell the cargo, repair the armor, buy modules, upgrade to the next class,
## buy a new ship, board another of the player's ships docked here, undock. Hides itself once the
## ship is out.

var controller: PlayerController

var _title: Label
var _ship_line: Label
var _cargo_line: Label
var _credits_line: Label
var _sell: Button
var _repair: Button
var _upgrade: Button
## Module type -> its buy button.
var _module_buttons := {}
## Module type -> its title.
var _module_titles := {}
## Ship scene for sale -> its buy button.
var _ship_buttons := {}
## Ship scene for sale -> its title.
var _ship_titles := {}
var _ships_title: Label
var _ships: GridContainer
var _undock: Button
## Ship ids the board rows show right now, to rebuild them only when that changes.
var _shown_ships: Array[int] = []


func _ready() -> void:
	visible = false
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 20)
	column.add_child(_title)
	_ship_line = Label.new()
	column.add_child(_ship_line)
	_cargo_line = Label.new()
	column.add_child(_cargo_line)
	_credits_line = Label.new()
	column.add_child(_credits_line)
	_sell = _add_button(column, controller.sell_cargo)
	_repair = _add_button(column, controller.repair_ship)
	for type in StationServices.modules():
		var probe := type.new() as ShipModule
		_module_titles[type] = probe.title
		probe.free()
		_module_buttons[type] = _add_button(column, controller.buy_module.bind(type))
	_upgrade = _add_button(column, controller.upgrade_ship)
	for scene in StationServices.ships():
		var probe := scene.instantiate() as Ship
		_ship_titles[scene] = probe.get_title()
		probe.free()
		_ship_buttons[scene] = _add_button(column, controller.buy_ship.bind(scene))
	_ships_title = Label.new()
	_ships_title.text = "Your ships here"
	column.add_child(_ships_title)
	_ships = GridContainer.new()
	_ships.columns = 2
	_ships.add_theme_constant_override("h_separation", 12)
	column.add_child(_ships)
	_undock = _add_button(column, controller.undock)


func _process(_delta: float) -> void:
	visible = controller != null and controller.is_docked()
	if not visible:
		return
	var ship := controller.ship
	var credits := controller.credits
	_title.text = "Docked at %s" % Autopilot.name_of(controller.docked_station())
	_ship_line.text = "%s   Shield %.0f / %.0f   Armor %.0f / %.0f" % [
			ship.get_title(), ship.shield, ship.max_shield, ship.armor, ship.max_armor]
	_cargo_line.text = "Cargo %d / %.0f: %s" % [ship.cargo.total(), ship.cargo.capacity, ship.cargo.describe()]
	_credits_line.text = "Credits %d" % credits

	_sell.text = "Sell cargo: +%d cr" % StationServices.cargo_value(ship)
	_sell.disabled = ship.cargo.is_empty()
	var repair_cost := StationServices.repair_cost(ship)
	_repair.text = "Repair armor: %d cr" % repair_cost if repair_cost > 0 else "Armor intact"
	if repair_cost > credits and credits > 0:
		_repair.text += " (%d cr repairs a part)" % credits
	_repair.disabled = repair_cost <= 0 or credits <= 0
	for type: Script in _module_buttons:
		var button: Button = _module_buttons[type]
		var fitted := ship.find_part(type) != null
		button.text = "%s: %s" % [_module_titles[type],
				"fitted" if fitted else "%d cr" % StationServices.module_price(type)]
		button.disabled = not StationServices.can_buy_module(ship, type, credits)
	var next := StationServices.upgrade_class(ship)
	if next == ShipClass.Size.CUSTOM:
		_upgrade.text = "No upgrade for this ship"
	else:
		_upgrade.text = "Upgrade to %s: %d cr" % [ShipClass.name_of(next), StationServices.upgrade_price(ship)]
	_upgrade.disabled = not StationServices.can_upgrade(ship, credits)
	for scene: PackedScene in _ship_buttons:
		var button: Button = _ship_buttons[scene]
		button.text = "Buy %s: %d cr" % [_ship_titles[scene], StationServices.ship_price(scene)]
		button.disabled = not StationServices.can_buy_ship(scene, credits)

	_update_ships()
	_undock.text = "Undocking: waiting for the port..." if controller.is_undocking() else "Undock"
	_undock.disabled = controller.is_undocking()


func _update_ships() -> void:
	var here := controller.ships_here()
	var ids: Array[int] = []
	for other in here:
		ids.append(other.object_id)
	_ships_title.visible = not here.is_empty()
	if ids == _shown_ships:
		return
	_shown_ships = ids
	for child in _ships.get_children():
		_ships.remove_child(child)
		child.queue_free()
	for other in here:
		var name_label := Label.new()
		name_label.text = other.get_title()
		_ships.add_child(name_label)
		var board := _make_button("Board")
		board.pressed.connect(_board.bind(other.object_id))
		_ships.add_child(board)


## Boards the ship by id: the button must not hold the node itself, the ship may vanish.
func _board(id: int) -> void:
	var other := WorldRegistry.find(id) as Ship
	if other != null:
		controller.board(other)


func _add_button(parent: Control, action: Callable) -> Button:
	var button := _make_button("")
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	# Keep keyboard focus off the buttons, otherwise Space would press the last clicked one.
	button.focus_mode = Control.FOCUS_NONE
	return button
