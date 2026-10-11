class_name ObjectRef
extends RefCounted

## A reference to a world object by its id (see WorldRegistry).
##
## Keep these instead of nodes for anything that lives longer than one frame: order targets,
## the selection, the camera target, corridor locks, a miner's rock. resolve() returns the live
## object or null, never a freed one, so a vanished object cannot crash the code that referred
## to it, and the result is safe to pass to typed parameters.

var id := 0


## A reference to `object`; to nothing if it is null or already freed.
static func to(object: Variant) -> ObjectRef:
	var ref := ObjectRef.new()
	ref.id = World.id_of(object)
	return ref


## The live object, or null.
func resolve() -> Node3D:
	return World.find(id) as Node3D if id != 0 else null


## True if this refers to `object` (and it is alive).
func points_to(object: Variant) -> bool:
	return id != 0 and is_instance_valid(object) and object.get(&"object_id") == id


## True if this ever referred to something (alive or not).
func is_set() -> bool:
	return id != 0
