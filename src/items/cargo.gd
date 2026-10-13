class_name Cargo
extends RefCounted

## A cargo hold: pieces of items stacked by id (see Items), every piece takes one place.
## Ships have one sized by Ship.cargo_capacity; wrecks and containers have one without a limit.

## How many pieces the hold can take.
var capacity := INF

## Item id -> number of pieces. Stacks keep the order in which items first came in.
var _stacks := {}


func _init(p_capacity := INF) -> void:
	capacity = p_capacity


func count(item: StringName) -> int:
	return _stacks.get(item, 0)


## Ids of the items in the hold.
func items() -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(_stacks.keys())
	return result


func is_empty() -> bool:
	return _stacks.is_empty()


## Pieces in the hold.
func total() -> int:
	var sum := 0
	for item: StringName in _stacks:
		sum += _stacks[item]
	return sum


## Free places left.
func room() -> float:
	return maxf(0.0, capacity - total())


## Adds as many of `amount` pieces as fit. Returns how many went in.
func add(item: StringName, amount: int) -> int:
	var added := mini(amount, int(room())) if room() < amount else amount
	if added > 0:
		_stacks[item] = count(item) + added
	return added


## Takes out up to `amount` pieces. Returns how many came out.
func remove(item: StringName, amount: int) -> int:
	var removed := mini(amount, count(item))
	if removed <= 0:
		return 0
	if removed == count(item):
		_stacks.erase(item)
	else:
		_stacks[item] -= removed
	return removed


func clear() -> void:
	_stacks.clear()


## Moves everything that fits into `target`, but no more than `limit` pieces.
## Returns the number of pieces moved.
func move_to(target: Cargo, limit := INF) -> int:
	var moved := 0
	for item in items():
		var amount := count(item) if limit - moved >= count(item) else int(limit - moved)
		amount = target.add(item, amount)
		remove(item, amount)
		moved += amount
	return moved


## "Loot 1 x3, Ore x20", or "nothing".
func describe() -> String:
	if is_empty():
		return "nothing"
	var parts := PackedStringArray()
	for item in items():
		parts.append("%s x%d" % [Items.name_of(item), count(item)])
	return ", ".join(parts)
