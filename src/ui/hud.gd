class_name Hud
extends CanvasLayer

## Minimal flight HUD: ship status, faction credits, selected target, command buttons and
## controls help, the list of hostile ships (HostileList), a banner with the system's alert
## state and announcements (see SystemSecurity), the cargo window (I, or by itself when looting
## stops because the hold is full) and the tactical map (M, TacticalMap).
## Built in code for now; it will become a proper scene once the UI grows.

@export var controller: PlayerController
@export var debug_draw: NavDebugDraw

const HELP_TEXT := "LMB: select   Double click: approach object / fly to point   " \
		+ "RMB drag / arrows: rotate camera   Wheel: zoom   M: map   F3: navigation debug"

## Offset of the hover name from the mouse cursor, in pixels.
const HOVER_OFFSET := Vector2(18, 10)
## Distance of the alert banner's bottom edge from the bottom of the screen (above the controls
## help line, where it covers neither the side panels nor the ship in the middle), in pixels.
const BANNER_BOTTOM := 48.0
const ALERT_COLOR := Color(1.0, 0.45, 0.35)
const CALM_COLOR := Color(0.6, 1.0, 0.6)
## Seconds the last faction credits reward stays on screen.
const REWARD_NOTE_TIME := 4.0
## Room left for the controls help line at the bottom, in pixels.
const HELP_LINE_HEIGHT := 32.0

var _status: Label
var _approach_button: Button
var _orbit_button: Button
var _attack_button: Button
var _loot_button: Button
var _loot_all_button: Button
var _cargo_window: CargoWindow
var _hostile_list: HostileList
var _map: TacticalMap
var _hover_label: Label
var _banner: Label
var _reward_note := ""
var _reward_note_time := 0.0


func _ready() -> void:
	_map = TacticalMap.new()
	_map.controller = controller
	add_child(_map)

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
	var more := HBoxContainer.new()
	column.add_child(more)
	_loot_button = _add_button(more, "Loot [R]", controller.loot_selected)
	_loot_all_button = _add_button(more, "Loot all [T]", controller.loot_all)
	_add_button(more, "Cargo [I]", _toggle_cargo)
	_add_button(more, "Map [M]", _map.toggle)
	if debug_draw != null:
		_add_button(more, "Debug [F3]", debug_draw.toggle)

	_cargo_window = CargoWindow.new()
	_cargo_window.controller = controller
	add_child(_cargo_window)
	_cargo_window.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE, 12)
	controller.hold_full.connect(func() -> void: _cargo_window.open(CargoWindow.HOLD_FULL_NOTE))
	controller.faction_credits_earned.connect(func(amount: int, enemy: String) -> void:
		_reward_note = "+%d for %s" % [amount, enemy]
		_reward_note_time = REWARD_NOTE_TIME)

	var help := Label.new()
	help.text = HELP_TEXT
	help.modulate = Color(1, 1, 1, 0.7)
	add_child(help)
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 12)

	_hostile_list = HostileList.new()
	_hostile_list.controller = controller
	add_child(_hostile_list)
	_hostile_list.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 12)
	_hostile_list.grow_vertical = Control.GROW_DIRECTION_BEGIN
	# Above the controls help line.
	_hostile_list.offset_top -= HELP_LINE_HEIGHT
	_hostile_list.offset_bottom -= HELP_LINE_HEIGHT

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
	# Centered in the space right of the hostile list, so it never covers the list.
	_banner.offset_left = _hostile_list.offset_right + 12.0


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_I:
		_toggle_cargo()


func _toggle_cargo() -> void:
	_cargo_window.toggle()


func _process(delta: float) -> void:
	_update_banner()
	_reward_note_time -= delta
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
		var cargo_line := "Cargo %d / %.0f" % [ship.cargo.total(), ship.cargo.capacity]
		var bay: DroneBay = ship.get_drone_bay()
		if bay != null:
			cargo_line += "   Drones %d" % bay.drones
			var out := bay.drones_out().size()
			if out > 0:
				cargo_line += " (%d out)" % out
		lines.append(cargo_line)
	else:
		lines.append("Your ship has been destroyed")
	var credits_line := "Faction credits %d" % controller.faction_credits
	if _reward_note_time > 0.0:
		credits_line += "   %s" % _reward_note
	lines.append(credits_line)

	if target != null:
		var line := "Target: %s" % Autopilot.name_of(target)
		var target_ship := target as Ship
		if target_ship != null and target_ship.ship_class != ShipClass.Size.CUSTOM:
			line += " (%s)" % ShipClass.name_of(target_ship.ship_class)
		if has_ship:
			var gap := ship.global_position.distance_to(target.global_position) \
					- Autopilot.radius_of(target) - ship.radius
			line += "   %.0f m" % gap
		lines.append(line)
		if target is Ship:
			var other := target as Ship
			var activity := "%s   %s" % [other.get_health_text(), other.get_order_label()]
			if not other.cargo.is_empty():
				activity += "   cargo %d" % other.cargo.total()
			lines.append("   " + activity)
		elif target is Wreck:
			var wreck := target as Wreck
			if wreck.inspected:
				lines.append("   Contains: %s" % wreck.cargo.describe())
			else:
				lines.append("   Contents unknown: come within %.0f m" % Wreck.INSPECT_RANGE)
	else:
		lines.append("Target: none (click an object)")
	_status.text = "\n".join(lines)
	_approach_button.disabled = not has_ship or target == null
	_orbit_button.disabled = not has_ship or target == null
	_attack_button.disabled = not has_ship or not controller.can_attack_selected()
	_loot_button.disabled = not controller.can_loot_selected()
	_loot_all_button.disabled = not controller.can_loot()


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
