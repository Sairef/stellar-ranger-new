# Combat rewards

> Status: stub, nothing decided yet.

Open question: how to share the reward for a fight fairly among everyone who took part in it.
Everything to whoever landed the killing blow, equal shares for everyone who shot at the target,
shares by the damage dealt, or something else; who pays it (the system, a faction, a station);
and so on.

For now (placeholder): every ship that hit a destroyed enemy gets the full bounty, the one
galactic currency, by the enemy's class: small 100, medium 200, large 400 credits (`Bounties`,
`Ship.helped_destroy`, `PlayerController.credits`). Hits, not shots: with auto-firing weapons,
flying through a fight should not pay. Shooting down a ship that is not hostile pays nothing.
