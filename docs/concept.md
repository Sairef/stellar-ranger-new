# Stellar Ranger — Game Concept

> Status: draft v0.1 (2026-10-11). This is a living document: the "Open questions" section is expected to shrink over time.

## One-liner

A single-player 3D space sandbox where the galaxy lives by its own rules and does not care about you. You start as one pilot among thousands, and by the same rules as everyone else you can grow into the owner of fleets and stations.

## References

| Game | What we take | What we leave |
|---|---|---|
| **Kenshi** | Indifferent world, "you are nobody" start, learn-by-doing skills, captivity as a consequence of defeat | Body simulation, squad of on-foot characters |
| **X4** | Simulated economy, gate network, fleets and stations in the endgame, slow background conflict | Cockpit flight as the main way to play |
| **EVE Online** | Command-based ship control, skill-gated equipment, real ship loss, escape pod, faction loyalty currency | Multiplayer, time-based skill training |
| **Space Rangers** | NPC pilots living the same life as the player, free choice of career, a war that runs on its own | Text quests, planetary battles, turn-based structure |
| **Star Citizen** | Crafting where item quality comes from the quality of materials | First-person gameplay, seamless planets |

## Design pillars

1. **The galaxy does not care.** The world runs whether or not the player is watching. Nothing is scripted around the player; stories emerge from systems.
2. **Same rules for everyone.** The player is one pilot among many. The player's ship obeys the same orders, physics, economy and consequences as NPC ships.
3. **You are what you practice.** Skills grow by doing. Skills decide what you can fly and fit.
4. **Ships are shells.** A ship is a replaceable body for the pilot. Losing it hurts, but it is not the end.
5. **From pilot to power.** The game scales from one ship under direct command to fleets and stations under strategic command.

## Player progression

- **Start:** a lone pilot with a cheap ship and no reputation.
- **Skills by use:** mining grants mining experience, which raises the mining skill, which unlocks better mining ships and modules. The same applies to combat, trading, piloting, salvaging, etc.
- **Equipment:** every ship and module has skill requirements; if you cannot use it, you cannot fit it.
- **Item quality comes from materials** (inspired by Star Citizen crafting). Ore and materials have a quality value, and manufactured items inherit quality from their inputs. Quality tiers (e.g. common / uncommon / rare / epic, shown as white / blue / purple ...) are a readable view of that value. A good item in loot is not magic: it came from a lucky batch. This keeps item quality inside the simulated economy.
- **Reputation:** tracked per faction. Helping a faction (for example, destroying its enemies near its members) raises reputation and earns that faction's currency, similar to EVE's loyalty points.
- **Endgame:** owning multiple ships, fleets and stations. Control shifts from pilot-level commands to strategic, RTS-like management. This is optional: a player may stay a lone pilot forever.

## Control model

- Command-based, not twitch-based: approach, orbit, keep at range, attack, dock, mine, loot, jump through gate.
- The player uses the **same order system as the AI**. A player is "an NPC whose decisions are made by a human".
- This scales naturally into fleet management: the player issues the same orders to owned ships.

## Defeat and loss

- When the ship is destroyed, the pilot survives in an **escape pod** with a weak, very slow engine. The ship and its fitted equipment are lost.
- The player can limp toward a station or **broadcast an SOS**.
- The SOS is a real event in the simulation: actual nearby ships decide whether to respond. Allies or neutrals may pick the pilot up and deliver them to a station. Rarely, pirates answer instead, and the player ends up in captivity (Kenshi-style consequences).
- Symmetry with pillar 2: NPC pilots also eject in pods. The player can rescue them (reputation) or capture them.

## The world

- **Galaxy:** star systems connected by gates.
- **Factions:** with territories, economies and relations to each other and to the player.
- **NPC roles:** miners, traders, patrols, pirates, etc. Each runs its own routine and reacts to threats.
- **Background story:** a slow-burning conflict with an "Eternal Enemy" that invades through gates. The pace is slow enough that the game does not play itself to an end, but the conflict never waits for the player.

## Target experience: the key scene

> A system lives its daily routine. Patrols fly their routes, miners work the asteroid fields, traders crawl from station to station or toward the gate.
>
> Suddenly the gate activates and a fleet of the Eternal Enemy comes through. Some NPCs rush back to dock, others flee the system. Patrols move to intercept; reinforcements may arrive later.
>
> The player, flying a combat ship, joins the fight, picking off small enemy ships on the flank while the military holds the line.
>
> When the battle is over, the player launches cargo drones that collect loot from the wrecks, and receives faction currency for destroying the faction's enemies alongside its members.

Every system in the first milestone exists to make this scene possible.

## Explicitly out of scope

- Multiplayer of any kind
- Planetary landing, ground combat
- Text quests
- Pilot body (injuries, aging, hunger, etc.)
- A chosen-one main questline the world waits on
- Manual twitch flight as the primary mode of play

## Technical direction (proposed)

- **Engine:** Godot 4.7, Jolt physics, GDScript.
- **Simulation is separate from presentation.** The galaxy is data updated in ticks. Only the system the player is in is rendered in 3D; other systems are simulated at lower fidelity. The simulation can run without graphics, be fast-forwarded and be tested automatically.
- **One order system** shared by the player and the AI (see Control model).

## Open questions

- **Quality details.** Is quality a continuous value with tiers on top? Does the producer's skill or station level also affect it? Can the player deliberately hunt for high-quality ore?
- **Anti-grind for learn-by-doing.** How do we prevent "mine one rock forever" exploits? Diminishing returns, experience only from meaningful actions, risk-weighted experience?
- **Captivity.** What does gameplay as a pirate captive look like, and how does the player get out?
- **Ship loss economy.** Is there insurance? Is cargo dropped in the wreck? How expensive is a new start?
- **Time.** Real time with pause? Time acceleration for long travel (X4's SETA)?
- **Travel inside a system.** Distances and speeds; is there a warp / cruise mode?
- **Eternal Enemy.** Who are they, what do they want, can they actually win territory?
- **Factions.** How many, and what makes each one distinct?
- **Visual style.** Which style is achievable for a small team (stylized, low-poly, procedural)?

## First milestone: "The Scene"

Goal: make the key scene playable in a single star system.

Includes:
- One system: a station, an asteroid field, a gate.
- Player ship with command-based control and a camera.
- NPC miners, traders and patrols running routines.
- Weapons, damage, destruction, wrecks.
- An invasion event through the gate, with NPCs reacting to the threat.
- Loot drones collecting from wrecks.
- Faction currency for helping in combat.

Not included yet: multiple systems, full economy, skills, ship fitting UI, station ownership, escape pods.

Draft step order:
1. ✅ A ship in 3D space that moves by commands (move to / approach / orbit / stop), plus camera. Ships fly around obstacles (asteroids) and avoid colliding with each other. Covered by `tests/nav_scenarios.tscn`. Known limit: dense asteroid fields will need real path planning.
2. Static world: station, asteroids, gate.
3. NPC routines (miner, trader, patrol) using the same order system.
4. Combat: weapons, health, destruction, wrecks.
5. Invasion event and NPC threat reactions.
6. Loot drones and faction currency.
