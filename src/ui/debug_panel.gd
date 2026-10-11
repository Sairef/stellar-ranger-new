class_name DebugPanel
extends CanvasLayer

## Debug tools in the top right corner: simulation speed and traffic statistics.
## The place for future manual triggers (e.g. starting an invasion by hand).

@export var spawner: TrafficSpawner

const TIME_SCALES: Array[float] = [1.0, 2.0, 4.0, 8.0]

var _stats: Label


func _ready() -> void:
	var panel := PanelContainer.new()
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)

	var title := Label.new()
	title.text = "Debug"
	title.modulate = Color(1, 1, 1, 0.6)
	column.add_child(title)

	var speed_row := HBoxContainer.new()
	column.add_child(speed_row)
	var speed_label := Label.new()
	speed_label.text = "Time"
	speed_row.add_child(speed_label)
	var group := ButtonGroup.new()
	for time_scale in TIME_SCALES:
		var button := Button.new()
		button.text = "x%d" % int(time_scale)
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = is_equal_approx(Engine.time_scale, time_scale)
		# Keep keyboard focus off the buttons, otherwise Space would press the last clicked one.
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func() -> void: Engine.time_scale = time_scale)
		speed_row.add_child(button)

	_stats = Label.new()
	column.add_child(_stats)

	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 12)


func _process(_delta: float) -> void:
	var tree := get_tree()
	var docked := 0
	for node in tree.get_nodes_in_group(Ship.ALL_SHIPS_GROUP):
		if (node as Ship).is_docked():
			docked += 1
	var lines := PackedStringArray([
		"FPS %d" % Engine.get_frames_per_second(),
		"Ships in space %d, docked %d" % [tree.get_node_count_in_group(Autopilot.SHIP_GROUP), docked],
		"Traders %d   Miners %d   Patrols %d" % [
			tree.get_node_count_in_group(TraderRoutine.GROUP),
			tree.get_node_count_in_group(MinerRoutine.GROUP),
			tree.get_node_count_in_group(NpcRoutine.GROUP),
		],
	])
	if spawner != null:
		lines.append("Through gates: %d in, %d out" % [spawner.arrivals, spawner.departures])
	_stats.text = "\n".join(lines)
