class_name Hud
extends CanvasLayer

## Minimal flight HUD: ship status, selected target, command buttons and controls help.
## Built in code for now; it will become a proper scene once the UI grows.

@export var controller: PlayerController
@export var debug_draw: NavDebugDraw

const HELP_TEXT := "LMB: select   Double click: approach object / fly to point   " \
		+ "RMB drag / arrows: rotate camera   Wheel: zoom   F3: navigation debug"

var _status: Label
var _approach_button: Button
var _orbit_button: Button


func _ready() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(12, 12)
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)

	_status = Label.new()
	column.add_child(_status)

	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	_approach_button = _add_button(buttons, "Approach [Q]", controller.approach_selected)
	_orbit_button = _add_button(buttons, "Orbit [W]", controller.orbit_selected)
	_add_button(buttons, "Stop [Space]", controller.stop)
	if debug_draw != null:
		_add_button(buttons, "Debug [F3]", debug_draw.toggle)

	var help := Label.new()
	help.text = HELP_TEXT
	help.modulate = Color(1, 1, 1, 0.7)
	add_child(help)
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 12)


func _process(_delta: float) -> void:
	var ship := controller.ship
	var target := controller.selected
	var lines := PackedStringArray([
		"%s   speed %3.0f / %.0f m/s" % [ship.display_name, ship.speed, ship.max_speed],
		"Order: %s" % ship.get_order_label(),
	])
	if target != null:
		var gap := ship.global_position.distance_to(target.global_position) \
				- Autopilot.radius_of(target) - ship.radius
		lines.append("Target: %s   %.0f m" % [Autopilot.name_of(target), gap])
	else:
		lines.append("Target: none (click an object)")
	_status.text = "\n".join(lines)
	_approach_button.disabled = target == null
	_orbit_button.disabled = target == null


func _add_button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	# Keep keyboard focus off the buttons, otherwise Space would press the last clicked one.
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	parent.add_child(button)
	return button
