@tool
class_name Wreck
extends SpaceBody

## Something in space to loot (LootOrder, DroneBay): what is left of a destroyed ship (tumbling
## debris with what was in its hold plus placeholder loot), or a cargo container a ship dropped.
## The player does not know what is inside until the player's ship or one of its drones comes
## within INSPECT_RANGE (`inspected`, set by PlayerController). Once emptied, it is gone.
## Left alone for long, it is collected by the system scavenger (see SalvageService).
## A wreck is an obstacle like any other: ships fly around it.

const GROUP := &"wrecks"
## How close the player's ship or drones must come to see what is inside, in meters.
const INSPECT_RANGE := 1000.0
## A ship drops new items into its last container if it is still this close (from the hull).
const MERGE_DISTANCE := 60.0
## Gap between a ship's hull and a container it drops, in meters.
const DROP_GAP := 12.0
const CONTAINER_RADIUS := 3.0
const CONTAINER_COLOR := Color(0.75, 0.6, 0.3)

@export var debris_color := Color(0.3, 0.3, 0.3):
	set(value):
		debris_color = value
		_queue_rebuild()
## A dropped cargo container rather than debris.
@export var is_container := false:
	set(value):
		is_container = value
		_queue_rebuild()

var cargo := Cargo.new()
## Seconds since it appeared.
var age := 0.0
## True once the player knows what is inside.
var inspected := false
## The ship that dropped this container (unset for wrecks).
var dropped_by := ObjectRef.new()

## Tumbling speed in radians per second (visual only).
const SPIN := 0.2

var _pivot: Node3D
var _spin_axis := Vector3.UP


## The wreck of `ship`: its cargo plus placeholder loot (none from drones). The ship's hold is
## emptied into it.
static func from_ship(ship: Ship) -> Wreck:
	var wreck := Wreck.new()
	wreck.display_name = "Wreck of %s" % ship.display_name
	wreck.radius = ship.radius
	wreck.debris_color = ship.hull_color.darkened(0.6)
	ship.cargo.move_to(wreck.cargo)
	if not ship.is_drone:
		wreck.cargo.add(Items.LOOT_1, 3)
		wreck.cargo.add(Items.LOOT_2, 2)
	return wreck


## An empty cargo container dropped by `ship`.
static func make_container(ship: Ship) -> Wreck:
	var container := Wreck.new()
	container.display_name = "Cargo container"
	container.radius = CONTAINER_RADIUS
	container.is_container = true
	container.debris_color = CONTAINER_COLOR
	container.dropped_by = ObjectRef.to(ship)
	container.inspected = true  # Whoever dropped it knows what is inside.
	return container


func _ready() -> void:
	super()
	add_to_group(GROUP)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _pivot == null:
		return
	_pivot.rotate(_spin_axis, SPIN * delta)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	age += delta
	if cargo.is_empty():
		queue_free()  # Looted: nothing left worth showing.


func _build_visuals() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(display_name)
	_spin_axis = Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
	_pivot = add_generated(Node3D.new())
	var material := make_material(debris_color, 0.5, 0.8)
	var r := radius
	if is_container:
		add_mesh(box(Vector3(1.1, 0.8, 1.4) * r), material, Vector3.ZERO, _pivot)
		add_mesh(sphere(0.12 * r), make_glow_material(Color(0.4, 0.9, 1.0), 3.0), Vector3(0, 0.45 * r, 0), _pivot)
		return
	for i in 5:
		var size := Vector3(rng.randf_range(0.2, 0.6), rng.randf_range(0.1, 0.3), rng.randf_range(0.2, 0.7)) * r
		var offset := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * 0.35 * r
		var piece := add_mesh(box(size), material, offset, _pivot)
		piece.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
	add_mesh(sphere(0.08 * r), make_glow_material(Color(1.0, 0.45, 0.15), 3.0), Vector3.ZERO, _pivot)
