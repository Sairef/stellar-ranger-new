class_name HostileList
extends PanelContainer

## Every hostile ship in the system, nearest first, in a scrolling table (no limit: the one worth
## attacking may be the ninth): name, class, distance, shield / armor and whom it attacks ("YOU"
## in red when it is the player's ship). The ship the player's ship attacks is red. Click a row to
## select that ship, double-click it to attack. Picking one ship out of a crowded fight in 3D is
## hard; the table does not care how crowded the fight is.

## Seconds between refreshes of the table.
const REFRESH_INTERVAL := 0.25
const TITLES: Array[String] = ["Ship", "Class", "Distance", "S / A", "Attacking"]
const WIDTHS: Array[int] = [0, 76, 80, 70, 0]
const SIZE := Vector2(480, 250)
const ATTACK_COLOR := Color(1.0, 0.35, 0.3)

var controller: PlayerController

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
		_fill(items[i], ships[i], own, ships[i] == attacked)
		if ships[i] == selected:
			items[i].select(0)
	_syncing = false


func _fill(item: TreeItem, ship: Ship, own: Ship, attacked: bool) -> void:
	item.set_metadata(0, WorldRegistry.id_of(ship))
	item.set_text(0, ship.display_name)
	item.set_text(1, ShipClass.name_of(ship.ship_class) if ship.ship_class != ShipClass.Size.CUSTOM else "")
	var gap := ""
	if own != null:
		gap = "%.0f m" % (own.global_position.distance_to(ship.global_position) - own.radius - ship.radius)
	item.set_text(2, gap)
	item.set_text_alignment(2, HORIZONTAL_ALIGNMENT_RIGHT)
	item.set_text(3, "%d / %d" % [ceili(ship.shield), ceili(ship.armor)])
	var target: Ship = ship.current_order.get_attack_target() if ship.current_order != null else null
	var at_you := target != null and target == own
	item.set_text(4, "YOU" if at_you else Autopilot.name_of(target) if target != null else "")
	_paint(item, 4, at_you)
	_paint(item, 0, attacked)


func _paint(item: TreeItem, column: int, red: bool) -> void:
	if red:
		item.set_custom_color(column, ATTACK_COLOR)
	else:
		item.clear_custom_color(column)


func _row_ship(item: TreeItem) -> Ship:
	return WorldRegistry.find(item.get_metadata(0)) as Ship if item != null else null


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
