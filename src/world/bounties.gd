class_name Bounties
extends RefCounted

## Credits paid for destroying a hostile ship (pirates, invaders): every ship that hit it gets the
## full bounty, whoever finished it off (Ship.helped_destroy). Bigger ships are worth more.
## Shooting down a ship that is not hostile pays nothing. Placeholder numbers, set so that hunting
## pays about as well as mining (riskier, and more fun); who pays and how to share a reward fairly
## are open questions (docs/combat_rewards.md).

## Credits by class. A ship without a class has the standard numbers of a medium one.
const BY_CLASS := {
	ShipClass.Size.SMALL: 100,
	ShipClass.Size.MEDIUM: 200,
	ShipClass.Size.LARGE: 400,
	ShipClass.Size.CUSTOM: 200,
}


## The bounty `hunter` gets for helping to destroy `victim`.
static func reward(hunter: Ship, victim: Ship) -> int:
	if not hunter.is_hostile_to(victim):
		return 0
	return BY_CLASS.get(victim.ship_class, 0)
