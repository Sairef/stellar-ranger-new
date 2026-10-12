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
- **Auto-engage.** When the player's ship has no order and its weapon opens fire at a hostile it has not fought yet, the ship attacks it (comes into range and circles it), so a fight goes on after the first kill. It never overrides an order the player gave, and after Stop the ship does not go back for the target it was fighting. This is a decision of the player's "brain" (`PlayerController`), issued as an ordinary Attack order; NPC brains make their own (`CombatRoutine` hunts within detection range).

## Defeat and loss

- When the ship is destroyed, the pilot survives in an **escape pod** with a weak, very slow engine. The ship and its fitted equipment are lost.
- The player can limp toward a station or **broadcast an SOS**.
- The SOS is a real event in the simulation: actual nearby ships decide whether to respond. Allies or neutrals may pick the pilot up and deliver them to a station. Rarely, pirates answer instead, and the player ends up in captivity (Kenshi-style consequences).
- Symmetry with pillar 2: NPC pilots also eject in pods. The player can rescue them (reputation) or capture them.

## The world

- **Galaxy:** star systems connected by gates.
- **System layout:** objects lie near a common "ecliptic" plane with a moderate vertical spread (a few degrees as seen from the system center, i.e. a few hundred meters at 3 km). Fully flat looks like a 2D game in 3D clothes; fully random 3D is disorienting and hard to show on a map. A future system map can be a top-down view with height "stalks". Asteroid fields are thick volumes.
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
- **World objects have stable ids.** Anything can vanish (destroyed, jumped out, mined out), so long-lived references (order targets, the selection, locks) store ids and resolve them when needed. The same ids are what save games and the off-screen simulation of other systems will refer to. A chaos test removes random objects at random moments to keep this honest.

## Open questions

- **Quality details.** Is quality a continuous value with tiers on top? Does the producer's skill or station level also affect it? Can the player deliberately hunt for high-quality ore?
- **Anti-grind for learn-by-doing.** How do we prevent "mine one rock forever" exploits? Diminishing returns, experience only from meaningful actions, risk-weighted experience?
- **Captivity.** What does gameplay as a pirate captive look like, and how does the player get out?
- **Ship loss economy.** Is there insurance? Is cargo dropped in the wreck? How expensive is a new start?
- **Time.** Real time with pause? Time acceleration for long travel (X4's SETA)?
- **Travel inside a system.** Distances and speeds; is there a warp / cruise mode? For now the home system is compact (~7 km across, about a minute to cross at 120 m/s).
- **Eternal Enemy.** Who are they, what do they want, can they actually win territory?
- **Factions.** How many, and what makes each one distinct?
- **Visual style.** Which style is achievable for a small team (stylized, low-poly, procedural)?
- **When the invaders win.** Right now they just besiege the military station and the system stays on alert forever (traders never leave the docks). Should the system change hands, should more defenders come from neighbouring systems, should traffic route around it?
- **Enemy target priority.** In the invasion the player sometimes draws almost the whole enemy fleet and dies at once, although allies are close: it feels unfair. Cause: an NPC fighter (`CombatRoutine`) attacks the nearest hostile within detection range and stays on it until it is gone, so a player who flies ahead becomes the target of every invader, and nobody switches when allies arrive. Ideas for attackers: a threat score instead of plain distance (who is shooting me, who damaged me, the target's role and value), a cap on attackers per target to spread the fire, re-picking the target every few seconds, wing roles (some on the station, some on escorts). Priorities depend on the role, not one formula for every fighter: "same rules for everyone" is about mechanics (orders, weapons, damage), while each brain weighs targets its own way. A garrison defends its station first (once stations can be attacked, whoever attacks the station comes first), and roles inside it may differ: fighters clear out the small ships, bigger ships focus on enemies closer to their own size. Tune in dedicated playtests.
- **Sensors and labels.** Fading ship name labels by distance from the camera felt odd: what you see depended on where the camera was, not on what your ship knows. For now all labels are always visible (debugging). Probably visibility of ships and their labels should come from the player ship's sensors / radar (detection range, maybe signature size). Revisit when ships get sensors.

## Later, with multiple systems

- **Following through gates.** Approaching or orbiting a ship that jumps out should be able to follow it through the gate into the next system. With a single system the order simply ends when the target leaves.

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
2. ✅ Static world: the home system (`scenes/systems/home_system.tscn`) with two stations (trade, military), three gates and an asteroid field in a corner. Field rocks keep wide gaps, so ships can fly through it. Docking and gate jumps come later.
3. ✅ NPC routines (miner, trader, patrol) using the same order system. Ships dock at stations and jump through gates via corridors (one ship per corridor at a time); traders arrive and leave through gates, miners shuttle between their station and the field. A debug panel speeds up time and shows traffic stats.
4. ✅ Combat: weapons, health, destruction, wrecks. Placeholder numbers until there is real equipment: every ship has one auto-firing weapon (75% hit chance, 1 damage, 2 shots/s, 600 m), 20 shield and 10 armor (no separate hull). Weapons fire at the ordered target (Attack order), otherwise at the nearest hostile in range, so everyone defends themselves. Factions are a placeholder: pirates are hostile to all. A destroyed ship leaves a wreck holding "Loot". Abstract beam visuals. Test bed: `scenes/sandbox/combat_sandbox.tscn`. Not yet: line of sight, escape pods, reputation for attacking neutrals.
5. ✅ Invasion event and NPC threat reactions. Started by hand with a button on the debug panel, never automatically (for now). A gate warms up and the system goes on alert; traders shelter at the nearest station or flee through the safest gate, miners run home, patrols head for the gate; the fleet (6 fighters + a leader) comes out of the membrane; the military station launches its garrison (8). After the last invader the alert is lifted and everyone goes back to work. Balance is tuned so the defense usually wins, but not always: the player's help can decide it.
6. Loot drones and faction currency.
