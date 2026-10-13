class_name Items
extends RefCounted

## Item ids: dumb placeholders for playtests. Every piece takes one place in a hold.
## Real items (kinds, sizes, quality, prices) come with the economy.

const ORE := &"ore"
const LOOT_1 := &"loot_1"
const LOOT_2 := &"loot_2"

const NAMES := {
	ORE: "Ore",
	LOOT_1: "Loot 1",
	LOOT_2: "Loot 2",
}


static func name_of(item: StringName) -> String:
	return NAMES.get(item, String(item))
