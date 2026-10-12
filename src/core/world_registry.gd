class_name WorldRegistry
extends Node

## Registry of everything in the game world that can be referred to: ships, stations, gates,
## rocks, wrecks (later escape pods and loot).
##
## Every such object gets a stable id. Code that keeps a reference to a world object for longer
## than one frame stores an ObjectRef (the id) and resolves it when it needs the object. An object
## that vanished (destroyed, jumped out, mined out, despawned) then simply resolves to null and
## can never be used by mistake. Ids are also what save games and off-screen simulation of other
## systems will refer to.
##
## An object is registered while it is in the scene tree. Leaving the tree counts as vanishing.
## The registry lives in the `World` autoload; use it through the static functions below
## (WorldRegistry.find() etc.), which do not depend on the autoload's global name being known
## (it is not, e.g., to @tool scripts compiled in the editor).

signal object_removed(id: int)

static var _instance: WorldRegistry = null

## id -> object
var _objects := {}
var _next_id := 1


func _init() -> void:
	# Not in _enter_tree(): when the game starts, the main scene is built (and its exported
	# references to ships are turned into ObjectRefs) before any node enters the tree.
	_instance = self


func _exit_tree() -> void:
	if _instance == self:
		_instance = null


## The registry instance (for its signals), or null outside the running game.
static func get_instance() -> WorldRegistry:
	return _instance


## Id of `object`, assigning one on first use (even before it enters the tree). 0 for nothing.
static func id_of(object: Variant) -> int:
	return _instance._id_of(object) if _instance != null else 0


## Called by world objects when they enter the scene tree.
static func register(object: Node) -> void:
	if _instance != null:
		_instance._objects[_instance._id_of(object)] = object


## Called by world objects when they leave the scene tree.
static func unregister(object: Node) -> void:
	if _instance != null:
		_instance._unregister(object)


## The live object with this id, or null if there is none (any more).
static func find(id: int) -> Node:
	return _instance._find(id) if _instance != null else null


static func count() -> int:
	return _instance._objects.size() if _instance != null else 0


func _id_of(object: Variant) -> int:
	if not is_instance_valid(object):
		return 0
	if not &"object_id" in object:
		push_error("%s is not a world object (no object_id), it cannot be referred to by id" % object)
		return 0
	var id: int = object.object_id
	if id == 0:
		id = _next_id
		_next_id += 1
		object.object_id = id
		_objects[id] = object
	return id


func _unregister(object: Node) -> void:
	var id: int = object.object_id
	if _objects.has(id):
		_objects.erase(id)
		object_removed.emit(id)


func _find(id: int) -> Node:
	var object = _objects.get(id)
	if not is_instance_valid(object):
		# Freed without leaving the tree (it never entered it): forget it.
		_objects.erase(id)
		return null
	return object
