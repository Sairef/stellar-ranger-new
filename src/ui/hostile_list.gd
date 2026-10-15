class_name HostileList
extends PanelContainer

## Every hostile ship in the system, nearest first, in a scrolling table (no limit: the one worth
## attacking may be the ninth): name, class, distance, hit chances right now (the player's ship
## on it / it on the player's ship, see Hud.odds_text()), the same at the distance the player's
## ship would fight it at (PlayerController.attack_distance(): what closing in or keeping away
## would change), shield / armor and whom it attacks ("YOU" in red when it is the player's ship).
## The ship the player's ship attacks is red. Click a row to
## select that ship, double-click it to attack. Picking one ship out of a crowded fight in 3D is
## hard; the table does not care how crowded the fight is.
## Hidden while docked (the station window is there) and while the tactical map is open (it gets
## the whole screen, and its icons are clicked directly).

## Seconds between refreshes of the table.
const REFRESH_INTERVAL := 0.25
const TITLES: Array[String] = ["Ship", "Class", "Distance", "Hit %", "", "S / A", "Attacking"]
const WIDTHS: Array[int] = [0, 60, 70, 70, 76, 64, 0]
## Columns (tests and tools read them too).
const COLUMN_NAME := 0
const COLUMN_CLASS := 1
const COLUMN_DISTANCE := 2
const COLUMN_HIT := 3
const COLUMN_FORECAST := 4
const COLUMN_HEALTH := 5
const COLUMN_ATTACKING := 6
const SIZE := Vector2(560, 250)
const ATTACK_COLOR := Color(1.0, 0.35, 0.3)

var controller: PlayerController
## The tactical map: the list hides while it is open.
var map: TacticalMap

var _title: Label
var _tree: Tree
var _refresh_in := 0.0
## True while the table selects a row itself (following the selection), not the player.
var _syncing := false


func _init() -> void:
	custom_minimum_size = SIZE


func _ready() -> void:
	var column := VBoxContainer.new()
	add_child(column)
	_title = Label.new()
	column.add_child(_title)

	_tree = Tree.new()
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.columns = TITLES.size()
	_tree.column_titles_visible = true
	_tree.hide_root = true
	_tree.select_mode = Tree.SELECT_ROW
	_tree.scroll_horizontal_enabled = false
	# Keep the keyboard for the game (Q/W/E, Space...).
	_tree.focus_mode = Control.FOCUS_NONE
	for i in TITLES.size():
		_tree.set_column_title(i, TITLES[i])
		_tree.set_column_expand(i, WIDTHS[i] == 0)
		if WIDTHS[i] > 0:
			_tree.set_column_custom_minimum_width(i, WIDTHS[i])
	_tree.create_item()
	_tree.item_selected.connect(_on_row_selected)
	_tree.item_activated.connect(_on_row_activated)
	column.add_child(_tree)
	refresh()


func _process(delta: float) -> void:
	visible = controller != null and not controller.is_docked() and (map == null or not map.is_open)
	if not visible:
		_refresh_in = 0.0  # Up to date as soon as it shows again.
		return
	_refresh_in -= delta
	if _refresh_in <= 0.0:
		_refresh_in = REFRESH_INTERVAL
		refresh()


## Hostile ships out in space, nearest first (to the player's ship, if there is one).
func hostiles() -> Array[Ship]:
	var own := controller.ship if controller.has_ship() else null
	var result: Array[Ship] = []
	for node in get_tree().get_nodes_in_group(Autopilot.SHIP_GROUP):
		var other := node as Ship
		if other != own and Factions.are_hostile(Factions.PLAYER, other.faction):
			result.append(other)
	if own != null:
		var from := own.global_position
		result.sort_custom(func(a: Ship, b: Ship) -> bool:
			return from.distance_squared_to(a.global_position) < from.distance_squared_to(b.global_position))
	return result


## The table's rows, top to bottom (for tests and tools).
func rows() -> Array[TreeItem]:
	return _tree.get_root().get_children()


## Rebuilds the table from what is in space right now.
func refresh() -> void:
	var ships := hostiles()
	_title.text = "Hostiles (%d)" % ships.size()
	var own_gap := controller.attack_distance()
	_tree.set_column_title(COLUMN_FORECAST, "At %.0f m" % own_gap if own_gap > 0.0 else "")
	var root := _tree.get_root()
	var items := root.get_children()
	while items.size() < ships.size():
		items.append(_tree.create_item(root))
	while items.size() > ships.size():
		items.pop_back().free()

	var own := controller.ship if controller.has_ship() else null
	var attacked := controller.attack_target()
	var selected := controller.selected
	_syncing = true
	_tree.deselect_all()
	for i in ships.size():
		_fill(items[i], ships[i], own, ships[i] == attacked, own_gap)
		if ships[i] == selected:
			items[i].select(0)
	_syncing = false


## `own_gap`: the distance the player's ship would fight at (0 without a weapon).
func _fill(item: TreeItem, ship: Ship, own: Ship, attacked: bool, own_gap: float) -> void:
	item.set_metadata(COLUMN_NAME, WorldRegistry.id_of(ship))
	item.set_text(COLUMN_NAME, ship.display_name)
	item.set_text(COLUMN_CLASS,
			ShipClass.name_of(ship.ship_class) if ship.ship_class != ShipClass.Size.CUSTOM else "")
	var gap := ""
	if own != null:
		gap = "%.0f m" % (own.global_position.distance_to(ship.global_position) - own.radius - ship.radius)
	item.set_text(COLUMN_DISTANCE, gap)
	item.set_text_alignment(COLUMN_DISTANCE, HORIZONTAL_ALIGNMENT_RIGHT)
	item.set_text(COLUMN_HIT, _hit_text(own, ship))
	item.set_text_alignment(COLUMN_HIT, HORIZONTAL_ALIGNMENT_CENTER)
	item.set_text(COLUMN_FORECAST, _forecast_text(own, ship, own_gap))
	item.set_text_alignment(COLUMN_FORECAST, HORIZONTAL_ALIGNMENT_CENTER)
	item.set_text(COLUMN_HEALTH, "%d / %d" % [ceili(ship.shield), ceili(ship.armor)])
	var target: Ship = ship.current_order.get_attack_target() if ship.current_order != null else null
	var at_you := target != null and target == own
	item.set_text(COLUMN_ATTACKING, "YOU" if at_you else Autopilot.name_of(target) if target != null else "")
	_paint(item, COLUMN_ATTACKING, at_you)
	_paint(item, COLUMN_NAME, attacked)


## "85 / 21": the player's ship's hit chance on `ship` / its hit chance on the player's ship, in
## percent; "-" for a side that is unarmed or out of range.
func _hit_text(own: Ship, ship: Ship) -> String:
	if own == null:
		return ""
	return "%s / %s" % [_percent(own, ship), _percent(ship, own)]


## The same at `gap`, the distance the player's ship would fight `ship` at; empty if it has no
## weapon (`gap` 0).
func _forecast_text(own: Ship, ship: Ship, gap: float) -> String:
	if own == null or gap <= 0.0:
		return ""
	return "%s / %s" % [_percent_at(own, ship, gap), _percent_at(ship, own, gap)]


func _percent(shooter: Ship, target: Ship) -> String:
	if not shooter.is_armed() or not shooter.get_weapon().in_range(target):
		return "-"
	return "%d" % roundi(shooter.get_weapon().hit_chance_against(target) * 100.0)


func _percent_at(shooter: Ship, target: Ship, gap: float) -> String:
	if not shooter.is_armed():
		return "-"
	var chance := shooter.get_weapon().hit_chance_at(gap, target)
	return "%d" % roundi(chance * 100.0) if chance > 0.0 else "-"


func _paint(item: TreeItem, column: int, red: bool) -> void:
	if red:
		item.set_custom_color(column, ATTACK_COLOR)
	else:
		item.clear_custom_color(column)


func _row_ship(item: TreeItem) -> Ship:
	return WorldRegistry.find(item.get_metadata(COLUMN_NAME)) as Ship if item != null else null


func _on_row_selected() -> void:
	if _syncing:
		return
	var ship := _row_ship(_tree.get_selected())
	if ship != null:
		controller.select(ship)


func _on_row_activated() -> void:
	var ship := _row_ship(_tree.get_selected())
	if ship != null:
		controller.select(ship)
		controller.attack_selected()
