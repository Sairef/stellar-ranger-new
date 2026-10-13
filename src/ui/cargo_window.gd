class_name CargoWindow
extends PanelContainer

## The player's hold: every item, and buttons to drop items into a container
## behind the ship (Ship.jettison). Opened with I, and by the HUD when looting stops because the
## hold is full. Loot all never picks up containers the ship dropped itself.

const HOLD_FULL_NOTE := "The hold is full. Drop what is not worth keeping,\nthen Loot all [T] again."

var controller: PlayerController

var _title: Label
var _note: Label
var _rows: GridContainer
## What the rows show right now, to rebuild them only when the hold changes.
var _shown := ""


func _ready() -> void:
	visible = false
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)
	_title = Label.new()
	column.add_child(_title)
	_note = Label.new()
	_note.modulate = Color(1.0, 0.8, 0.4)
	column.add_child(_note)
	_rows = GridContainer.new()
	_rows.columns = 3
	_rows.add_theme_constant_override("h_separation", 12)
	column.add_child(_rows)
	var close := _make_button("Close [I]")
	close.pressed.connect(func() -> void: visible = false)
	column.add_child(close)


func open(note := "") -> void:
	_note.text = note
	_note.visible = not note.is_empty()
	_shown = ""
	visible = true


func toggle() -> void:
	if visible:
		visible = false
	else:
		open()


func _process(_delta: float) -> void:
	if not visible:
		return
	if controller == null or not controller.has_ship():
		visible = false
		return
	var cargo: Cargo = controller.ship.cargo
	_title.text = "Cargo   %d / %.0f" % [cargo.total(), cargo.capacity]
	var snapshot := cargo.describe()
	if snapshot != _shown:
		_shown = snapshot
		_rebuild(cargo)


func _rebuild(cargo: Cargo) -> void:
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	if cargo.is_empty():
		var empty := Label.new()
		empty.text = "Empty"
		_rows.add_child(empty)
		return
	for item in cargo.items():
		var count := cargo.count(item)
		var name_label := Label.new()
		name_label.text = "%s x%d" % [Items.name_of(item), count]
		_rows.add_child(name_label)
		var drop_one := _make_button("Drop 1")
		drop_one.pressed.connect(controller.jettison.bind(item, 1))
		_rows.add_child(drop_one)
		var drop_all := _make_button("Drop all")
		drop_all.pressed.connect(controller.jettison.bind(item, count))
		_rows.add_child(drop_all)


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	# Keep keyboard focus off the buttons, otherwise Space would press the last clicked one.
	button.focus_mode = Control.FOCUS_NONE
	return button
