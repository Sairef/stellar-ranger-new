class_name Factions
extends RefCounted

## Who is hostile to whom. A placeholder until there are real factions and reputation:
## pirates and invaders (the "Eternal Enemy") are hostile to everyone, everyone else is at peace.

const PLAYER := &"player"
const NEUTRAL := &"neutral"
const PIRATE := &"pirate"
const INVADER := &"invader"

const HOSTILE_TO_ALL: Array[StringName] = [PIRATE, INVADER]


static func are_hostile(a: StringName, b: StringName) -> bool:
	if a == b:
		return false
	return a in HOSTILE_TO_ALL or b in HOSTILE_TO_ALL
