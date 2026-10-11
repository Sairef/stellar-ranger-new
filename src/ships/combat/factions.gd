class_name Factions
extends RefCounted

## Who is hostile to whom. A placeholder until there are real factions and reputation:
## pirates are hostile to everyone, everyone else is at peace.

const PLAYER := &"player"
const NEUTRAL := &"neutral"
const PIRATE := &"pirate"


static func are_hostile(a: StringName, b: StringName) -> bool:
	if a == b:
		return false
	return a == PIRATE or b == PIRATE
