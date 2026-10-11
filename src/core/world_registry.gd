class_name WorldRegistry
extends Node

## Registry of everything in the game world that can be referred to: ships, stations, gates,
## rocks, wrecks (later escape pods and loot). Available everywhere as the `World` autoload.
##
## Every such object gets a stable id. Code that keeps a reference to a world object for longer
## than one frame stores an ObjectRef (the id) and resolves it when it needs the object. An object
## that vanished (destroyed, jumped out, mined out, despawned) then simply resolves to null and
## can never be used by mistake. Ids are also what save games and off-screen simulation of other
## systems will refer to.
##
## An object is registered while it is in the scene tree. Leaving the tree counts as vanishing.

signal object_removed(id: int)

## id -> object
var _objects := {}
var _next_id := 1


## Id of `object`, assigning one on first use (even before it enters the tree). 0 for nothing.
func id_of(object: Variant) -> int:
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


## Called by world objects when they enter the scene tree.
func register(object: Node) -> void:
	_objects[id_of(object)] = object


## Called by world objects when they leave the scene tree.
func unregister(object: Node) -> void:
	var id: int = object.object_id
	if _objects.has(id):
		_objects.erase(id)
		object_removed.emit(id)


## The live object with this id, or null if there is none (any more).
func find(id: int) -> Node:
	var object = _objects.get(id)
	if not is_instance_valid(object):
		# Freed without leaving the tree (it never entered it): forget it.
		_objects.erase(id)
		return null
	return object


func count() -> int:
	return _objects.size()
