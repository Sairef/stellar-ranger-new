class_name Hud
extends CanvasLayer

## Minimal flight HUD: ship status, selected target, command buttons and controls help,
## plus a banner with the system's alert state and announcements (see SystemSecurity).
## Built in code for now; it will become a proper scene once the UI grows.

@export var controller: PlayerController
@export var debug_draw: NavDebugDraw

const HELP_TEXT := "LMB: select   Double click: approach object / fly to point   " \
		+ "RMB drag / arrows: rotate camera   Wheel: zoom   F3: navigation debug"

## Offset of the hover name from the mouse cursor, in pixels.
const HOVER_OFFSET := Vector2(18, 10)
## Distance of the alert banner's bottom edge from the bottom of the screen (above the controls
## help line, where it covers neither the side panels nor the ship in the middle), in pixels.
const BANNER_BOTTOM := 48.0
const ALERT_COLOR := Color(1.0, 0.45, 0.35)
const CALM_COLOR := Color(0.6, 1.0, 0.6)

var _status: Label
var _approach_button: Button
var _orbit_button: Button
var _attack_button: Button
var _hover_label: Label
var _banner: Label


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
	_attack_button = _add_button(buttons, "Attack [E]", controller.attack_selected)
	_add_button(buttons, "Stop [Space]", controller.stop)
	if debug_draw != null:
		_add_button(buttons, "Debug [F3]", debug_draw.toggle)

	var help := Label.new()
	help.text = HELP_TEXT
	help.modulate = Color(1, 1, 1, 0.7)
	add_child(help)
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 12)

	_hover_label = Label.new()
	_hover_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_label.add_theme_constant_override("outline_size", 6)
	_hover_label.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(_hover_label)

	_banner = Label.new()
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 22)
	_banner.add_theme_constant_override("outline_size", 8)
	_banner.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(_banner)
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_banner.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_banner.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_banner.offset_bottom = -BANNER_BOTTOM


func _process(_delta: float) -> void:
	_update_banner()
	var hovered := controller.hovered
	_hover_label.visible = hovered != null
	if hovered != null:
		_hover_label.text = Autopilot.name_of(hovered)
		_hover_label.position = get_viewport().get_mouse_position() + HOVER_OFFSET

	var has_ship := controller.has_ship()
	var ship := controller.ship if has_ship else null
	var target := controller.selected
	var lines := PackedStringArray()
	if has_ship:
		lines.append("%s   speed %3.0f / %.0f m/s" % [ship.display_name, ship.speed, ship.max_speed])
		lines.append("Shield %.0f / %.0f   Armor %.0f / %.0f" % [
				ship.shield, ship.max_shield, ship.armor, ship.max_armor])
		lines.append("Order: %s" % ship.get_order_label())
	else:
		lines.append("Your ship has been destroyed")

	if target != null:
		var line := "Target: %s" % Autopilot.name_of(target)
		if has_ship:
			var gap := ship.global_position.distance_to(target.global_position) \
					- Autopilot.radius_of(target) - ship.radius
			line += "   %.0f m" % gap
		lines.append(line)
		if target is Ship:
			var other := target as Ship
			var activity := "%s   %s" % [other.get_health_text(), other.get_order_label()]
			if other.cargo > 0.0:
				activity += "   cargo %.0f / %.0f" % [other.cargo, other.cargo_capacity]
			lines.append("   " + activity)
		elif target is Wreck:
			lines.append("   Contains: %s" % ", ".join((target as Wreck).contents))
	else:
		lines.append("Target: none (click an object)")
	_status.text = "\n".join(lines)
	_approach_button.disabled = not has_ship or target == null
	_orbit_button.disabled = not has_ship or target == null
	_attack_button.disabled = not has_ship or not controller.can_attack_selected()


func _update_banner() -> void:
	var security := SystemSecurity.of(self)
	var lines := PackedStringArray()
	if security != null:
		var announcement := security.current_announcement()
		if not announcement.is_empty():
			lines.append(announcement)
		if security.alert:
			var count := security.threats().size()
			lines.append("ALERT: %d hostile ships in the system" % count if count > 0 else "ALERT")
	_banner.text = "\n".join(lines)
	_banner.modulate = ALERT_COLOR if security != null and security.alert else CALM_COLOR


func _add_button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	# Keep keyboard focus off the buttons, otherwise Space would press the last clicked one.
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	parent.add_child(button)
	return button
