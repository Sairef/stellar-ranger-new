class_name Hud
extends CanvasLayer

## Minimal flight HUD: ship status, credits, selected target (with how well both sides would hit
## each other right now, odds_text()), command buttons, module buttons
## (keys 1, 2, ...) and controls help, the list of hostile ships (HostileList), a banner with the
## system's alert state, hostiles around and announcements (see SystemSecurity; warnings sound the
## alarm) and the news that the player's ship was lost, the cargo window (I, or by itself when
## looting stops because the hold is full), the station window (StationWindow, while docked), the
## minimap in the bottom right corner (Minimap) and the tactical map (M, TacticalMap).
## A reward rings a coin (Sfx).
## Built in code for now; it will become a proper scene once the UI grows.

@export var controller: PlayerController
@export var debug_draw: NavDebugDraw

const HELP_TEXT := "LMB: select   Double click: approach object / fly to point   " \
		+ "Z / X: fight closer / farther   RMB drag / arrows: rotate camera   Wheel: zoom   M: map"

## Offset of the hover name from the mouse cursor, in pixels.
const HOVER_OFFSET := Vector2(18, 10)
## Distance of the alert banner's bottom edge from the bottom of the screen (above the controls
## help line, where it covers neither the side panels nor the ship in the middle), in pixels.
const BANNER_BOTTOM := 48.0
## Narrowest the banner may get between the panels before it moves above the hostile list.
const BANNER_MIN_WIDTH := 280.0
const ALERT_COLOR := Color(1.0, 0.45, 0.35)
const CALM_COLOR := Color(0.6, 1.0, 0.6)
## Seconds the last credits reward stays on screen.
const REWARD_NOTE_TIME := 4.0
## Seconds the news of a lost ship stays on screen.
const LOSS_NOTE_TIME := 10.0
## Room left for the controls help line at the bottom, in pixels.
const HELP_LINE_HEIGHT := 32.0
## Side of the minimap: this share of the screen height, within the limits, in pixels.
const MINIMAP_SHARE := 0.36
const MINIMAP_MIN := 220.0
const MINIMAP_MAX := 460.0
## Gap between panels and from the screen edges, in pixels.
const MARGIN := 12.0

var _status: Label
var _approach_button: Button
var _orbit_button: Button
var _attack_button: Button
var _loot_button: Button
var _loot_all_button: Button
var _dock_button: Button
var _mine_button: Button
var _cargo_window: CargoWindow
var _station_window: StationWindow
var _hostile_list: HostileList
var _minimap: Minimap
var _map: TacticalMap
var _hover_label: Label
var _banner: Label
var _modules_row: HBoxContainer
## Ids of the modules the buttons are for, to rebuild them only when that changes.
var _shown_modules: Array[int] = []
var _reward_note := ""
var _reward_note_time := 0.0
var _loss_note := ""
var _loss_note_time := 0.0
## SystemSecurity.announcements already seen (to sound a new warning once).
var _announcements_seen := 0


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
	_dock_button = _add_button(more, "Dock [D]", controller.dock_selected)
	_mine_button = _add_button(more, "Mine [F]", controller.mine_selected)
	_add_button(more, "Cargo [I]", _toggle_cargo)
	_add_button(more, "Map [M]", _map.toggle)
	if debug_draw != null:
		_add_button(more, "Debug [F3]", debug_draw.toggle)
	_modules_row = HBoxContainer.new()
	column.add_child(_modules_row)

	_cargo_window = CargoWindow.new()
	_cargo_window.controller = controller
	add_child(_cargo_window)
	_cargo_window.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE, 12)
	controller.hold_full.connect(func() -> void: _cargo_window.open(CargoWindow.HOLD_FULL_NOTE))
	controller.credits_earned.connect(_on_credits_earned)
	controller.ship_lost.connect(_on_ship_lost)

	_station_window = StationWindow.new()
	_station_window.controller = controller
	add_child(_station_window)

	var help := Label.new()
	help.text = HELP_TEXT
	help.modulate = Color(1, 1, 1, 0.7)
	add_child(help)
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 12)

	_hostile_list = HostileList.new()
	_hostile_list.controller = controller
	_hostile_list.map = _map
	add_child(_hostile_list)
	_hostile_list.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 12)
	_hostile_list.grow_vertical = Control.GROW_DIRECTION_BEGIN
	# Above the controls help line.
	_hostile_list.offset_top -= HELP_LINE_HEIGHT
	_hostile_list.offset_bottom -= HELP_LINE_HEIGHT

	_minimap = Minimap.new()
	_minimap.controller = controller
	_minimap.map = _map
	add_child(_minimap)

	_hover_label = Label.new()
	_hover_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_label.add_theme_constant_override("outline_size", 6)
	_hover_label.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(_hover_label)

	_banner = Label.new()
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Long announcements wrap within the room between the hostile list and the minimap.
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner.add_theme_font_size_override("font_size", 22)
	_banner.add_theme_constant_override("outline_size", 8)
	_banner.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(_banner)
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_banner.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_banner.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_banner.offset_bottom = -BANNER_BOTTOM
	_layout()
	get_viewport().size_changed.connect(_layout)


## Places what depends on the screen size: the minimap in the bottom right corner above the
## controls help line, the station window left of it (the banner keeps clear of both, see
## _place_banner()).
func _layout() -> void:
	var side := clampf(get_viewport().get_visible_rect().size.y * MINIMAP_SHARE, MINIMAP_MIN, MINIMAP_MAX)
	_minimap.custom_minimum_size = Vector2(side, side)
	_place_bottom_right(_minimap, 0.0)
	_place_bottom_right(_station_window, side + MARGIN)


## Centers the banner in the room between the panels along the bottom: the hostile list on the
## left, the station window (while docked) and the minimap on the right, so it covers none of
## their buttons. If that room is narrower than BANNER_MIN_WIDTH (a squarer window, where the
## minimap grows), the banner goes above the hostile list instead. Every frame: which panels show
## changes (docked, the map open).
func _place_banner() -> void:
	var screen := get_viewport().get_visible_rect().size
	var right := screen.x - MARGIN
	for panel: Control in [_station_window, _minimap]:
		if panel.visible:
			right = minf(right, panel.get_global_rect().position.x - MARGIN)
	var left := MARGIN
	var bottom := BANNER_BOTTOM
	if _hostile_list.visible:
		var list := _hostile_list.get_global_rect()
		left = list.end.x + MARGIN
		if right - left < BANNER_MIN_WIDTH:
			left = MARGIN
			bottom = screen.y - list.position.y + MARGIN
	_banner.offset_left = left
	_banner.offset_right = right - screen.x
	_banner.offset_bottom = -bottom


## Anchors `panel` to the bottom right corner, above the help line, `shift` pixels to the left.
func _place_bottom_right(panel: Control, shift: float) -> void:
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, int(MARGIN))
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_left -= shift
	panel.offset_right -= shift
	panel.offset_top -= HELP_LINE_HEIGHT
	panel.offset_bottom -= HELP_LINE_HEIGHT


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_I:
		_toggle_cargo()


func _toggle_cargo() -> void:
	_cargo_window.toggle()


## "You hit 85%   It hits you 21%": how `own` and `other` would hit each other right now, the
## same numbers their weapons fire with (Weapon.hit_chance_against()). Empty if neither is armed.
static func odds_text(own: Ship, other: Ship) -> String:
	var parts := PackedStringArray()
	if own.is_armed():
		var mine := own.get_weapon()
		parts.append("You hit %d%%" % roundi(mine.hit_chance_against(other) * 100.0)
				if mine.in_range(other) else "You: out of range")
	if other.is_armed() and other.is_hostile_to(own):
		var theirs := other.get_weapon()
		parts.append("It hits you %d%%" % roundi(theirs.hit_chance_against(own) * 100.0)
				if theirs.in_range(own) else "It: out of range")
	return "   ".join(parts)


## "At 100 m: you 85%, it 31%": the same if the ships were `gap` meters apart (the distance
## `own` would fight at), so the player sees what closing in or keeping away would change.
## Empty unless `own` is armed.
static func forecast_text(own: Ship, other: Ship, gap: float) -> String:
	if not own.is_armed() or gap <= 0.0:
		return ""
	var text := "At %.0f m: you %s" % [gap, _chance_text(own.get_weapon().hit_chance_at(gap, other))]
	if other.is_armed() and other.is_hostile_to(own):
		text += ", it %s" % _chance_text(other.get_weapon().hit_chance_at(gap, own))
	return text


static func _chance_text(chance: float) -> String:
	return "%d%%" % roundi(chance * 100.0) if chance > 0.0 else "out of range"


func _on_credits_earned(amount: int, enemy: String) -> void:
	_reward_note = "+%d for %s" % [amount, enemy]
	_reward_note_time = REWARD_NOTE_TIME
	Sfx.play_ui(self, &"reward")


func _on_ship_lost(title: String) -> void:
	_loss_note = "Your %s was destroyed!\nYou got away in the escape pod: dock at a station (D) for a new ship." % title
	_loss_note_time = LOSS_NOTE_TIME
	Sfx.play_ui(self, &"explosion", 3.0, 0.6)


func _process(delta: float) -> void:
	_update_banner()
	_place_banner()
	_update_modules()
	_reward_note_time -= delta
	_loss_note_time -= delta
	var hovered := controller.hovered
	_hover_label.visible = hovered != null
	if hovered != null:
		_hover_label.text = Autopilot.name_of(hovered)
		_hover_label.position = get_viewport().get_mouse_position() + HOVER_OFFSET

	var has_ship := controller.has_ship()
	# Docked too: the ship is there, it just takes no orders.
	var ship := controller.ship
	var target := controller.selected
	var lines := PackedStringArray()
	if ship != null:
		lines.append("%s   speed %3.0f / %.0f m/s" % [ship.get_title(), ship.speed, ship.top_speed()])
		var durability := "Shield %.0f / %.0f   Armor %.0f / %.0f" % [
				ship.shield, ship.max_shield, ship.armor, ship.max_armor]
		if not ship.get_modules().is_empty():
			durability += "   Energy %.0f / %.0f" % [ship.energy, ship.max_energy]
		lines.append(durability)
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
		lines.append("You have no ship (debug panel: Respawn player)")
	var credits_line := "Credits %d" % controller.credits
	if _reward_note_time > 0.0:
		credits_line += "   %s" % _reward_note
	lines.append(credits_line)

	if target != null:
		var target_ship := target as Ship
		var line := "Target: %s" % (target_ship.get_title() if target_ship != null else Autopilot.name_of(target))
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
			if has_ship and (ship.is_hostile_to(other) or controller.attack_target() == other):
				var odds := odds_text(ship, other)
				var forecast := forecast_text(ship, other, controller.attack_distance())
				if not forecast.is_empty():
					odds += "   (%s)" % forecast
				if not odds.is_empty():
					lines.append("   " + odds)
		elif target is Wreck:
			var wreck := target as Wreck
			if wreck.inspected:
				lines.append("   Contains: %s" % wreck.cargo.describe())
			else:
				lines.append("   Contents unknown: come within %.0f m" % Wreck.INSPECT_RANGE)
		elif target is Gate:
			lines.append("   Jumps to other systems: not in the game yet")
	else:
		lines.append("Target: none (click an object)")
	_status.text = "\n".join(lines)
	_approach_button.disabled = not has_ship or target == null
	_orbit_button.disabled = not has_ship or target == null
	_attack_button.disabled = not has_ship or not controller.can_attack_selected()
	_loot_button.disabled = not controller.can_loot_selected()
	_loot_all_button.disabled = not controller.can_loot()
	_dock_button.disabled = not controller.can_dock_selected()
	_mine_button.disabled = not controller.can_mine_selected()


func _update_banner() -> void:
	var security := SystemSecurity.of(self)
	var lines := PackedStringArray()
	var danger := _loss_note_time > 0.0
	if danger:
		lines.append(_loss_note)
	if security != null:
		if security.announcements != _announcements_seen:
			_announcements_seen = security.announcements
			if security.announcement_is_warning:
				Sfx.play_ui(self, &"alert")
		var announcement := security.current_announcement()
		if not announcement.is_empty():
			lines.append(announcement)
		var count := security.threats().size()
		if security.alert:
			lines.append("ALERT: %d hostile ships in the system" % count if count > 0 else "ALERT")
		elif count > 0:
			lines.append("Hostile ships in the system: %d" % count)
		danger = danger or security.alert or count > 0
	_banner.text = "\n".join(lines)
	_banner.modulate = ALERT_COLOR if danger else CALM_COLOR


## One button per module of the ship (keys 1, 2, ...), with its state.
func _update_modules() -> void:
	var ship := controller.ship
	var modules: Array[ShipModule] = []
	if ship != null:
		modules = ship.get_modules()
	var ids: Array[int] = []
	for module in modules:
		ids.append(module.get_instance_id())
	if ids != _shown_modules:
		_shown_modules = ids
		for child in _modules_row.get_children():
			_modules_row.remove_child(child)
			child.queue_free()
		for i in modules.size():
			_add_button(_modules_row, "", controller.use_module.bind(i))
	var buttons := _modules_row.get_children()
	for i in modules.size():
		var button := buttons[i] as Button
		button.text = "%s [%d]: %s" % [modules[i].title, i + 1, modules[i].get_state_text()]
		button.disabled = not modules[i].can_activate()


func _add_button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	# Keep keyboard focus off the buttons, otherwise Space would press the last clicked one.
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	parent.add_child(button)
	return button
