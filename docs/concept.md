# Stellar Ranger — Game Concept

> Status: draft v0.1 (2026-10-11). This is a living document: the "Open questions" section is expected to shrink over time.

## One-liner

A single-player 3D space sandbox where the galaxy lives by its own rules and does not care about you. You start as one pilot among thousands, and by the same rules as everyone else you can grow into the owner of fleets and stations.

## References

| Game | What we take | What we leave |
|---|---|---|
| **Kenshi** | Indifferent world, "you are nobody" start, learn-by-doing skills, captivity as a consequence of defeat | Body simulation, squad of on-foot characters |
| **X4** | Simulated economy, gate network, fleets and stations in the endgame, slow background conflict | Cockpit flight as the main way to play |
| **EVE Online** | Command-based ship control, skill-gated equipment, real ship loss, escape pod | Multiplayer, time-based skill training, per-faction loyalty currencies |
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
- **Money:** one currency for the whole galaxy, the credit. Everyone pays and gets paid in credits: the player, NPCs, every faction, every station. There are no per-faction currencies.
- **Reputation:** tracked per faction. Helping a faction (for example, destroying its enemies near its members) raises reputation with it and pays credits.
- **Endgame:** owning multiple ships, fleets and stations. Control shifts from pilot-level commands to strategic, RTS-like management. This is optional: a player may stay a lone pilot forever.

## Control model

- Command-based, not twitch-based: approach, orbit, keep at range, attack, dock, mine, loot, jump through gate.
- The player uses the **same order system as the AI**. A player is "an NPC whose decisions are made by a human".
- This scales naturally into fleet management: the player issues the same orders to owned ships.
- **Auto-engage.** When the player's ship has no order and its weapon opens fire at a hostile it has not fought yet, the ship attacks it (comes into range and circles it), so a fight goes on after the first kill. An Attack order whose target gets to the edge of weapon range stops circling and chases it: it flies straight to where the target will be (an intercept), for NPCs too. It never overrides an order the player gave, and after Stop the ship does not go back for the target it was fighting. This is a decision of the player's "brain" (`PlayerController`), issued as an ordinary Attack order; NPC brains make their own (`CombatRoutine` hunts within detection range). The ship under attack is marked with red corner brackets (whoever picked it), and an automatic pick says why in the order line ("auto: nearest hostile in range").
- **Picking a target in a crowded fight.** Clicking one ship out of a dozen in 3D is hard, so there are two more ways. The hostile list shows every hostile ship (no limit, it scrolls), nearest first, with class, distance, shield/armor and whom it attacks ("YOU" in red); a click selects, a double click attacks. The tactical map (M) shows the system from above with icons instead of models (red hostiles, cyan player, gray others, bigger icons for bigger classes) and zooms at the cursor, so a fight can be zoomed apart; clicks and order keys work there as in 3D, and the game keeps running. Later the map is also the place to command fleets.
- **Distance: the main decision inside a fight.** How well a weapon hits depends on where the target is: each class's weapon hits best in its own band of distances (small guns close up, big guns farther out, as they cannot follow a target that close) and worse outside it, and big guns hit small ships worse. So a fight between classes is decided by who gets their distance: a small ship beats a large one only if it gets close and stays there, the large one wins if it keeps the small one away. Speed and the afterburner decide who gets their way. Attacks start at the weapon's best distance; Z / X fight closer / farther (the attack under way and later ones). The HUD shows both sides' hit chances right now ("You hit 85%   It hits you 22%", also in the hostile list), the same numbers the weapons fire with, and the maps shade the best band around the player's ship. Angular velocity (EVE's tracking) is left out on purpose: measured in duels, ships that want different distances end up in a near-parallel chase where it is close to zero, so it would rarely matter and could not be seen or steered.
- **Modules: decisions inside a fight.** Orders say where to fly and whom to fight; modules are what the pilot does at the right moment on top of that. A ship runs them on its energy, which recharges by itself (a capacitor, as in EVE): the afterburner (catch a ship that runs, or get away), the shield booster (survive one more volley). Keys 1, 2, ... in the order the modules were fitted. Stations sell them; a destroyed ship loses them. NPC brains use the same call (not yet: no NPC fits modules for now).
- **Seeing what goes on around.** A minimap in the bottom right corner shows the same icons as the tactical map, always centered on the player's ship: click selects, double click approaches or flies to the point, the wheel zooms. A faint circle around the ship (on the tactical map too) shows how far its weapon reaches. Not seeing the surroundings felt uncomfortable in a playtest, even to a player used to space and 3D games.

## Defeat and loss

- When the ship is destroyed, the pilot survives in an **escape pod** with a weak, very slow engine. The ship and its fitted equipment are lost.
- The player can limp toward a station or **broadcast an SOS**.
- The SOS is a real event in the simulation: actual nearby ships decide whether to respond. Allies or neutrals may pick the pilot up and deliver them to a station. Rarely, pirates answer instead, and the player ends up in captivity (Kenshi-style consequences).
- Symmetry with pillar 2: NPC pilots also eject in pods. The player can rescue them (reputation) or capture them.

## The world

- **Galaxy:** star systems connected by gates.
- **Gates:** the ring model is a placeholder. The idea is expanding gates: closed, a gate is a compact block of four modules around a small core. When a ship comes to jump, the gate activates: the modules slide apart into a ring wide enough for that ship (any size), a glowing membrane fills it, the ship flies through and the gate closes again. Arrivals work the same way: the gate opens, the ship comes out, the gate closes. This also gives the invasion its warning: the gate opens as wide as the biggest ship of the incoming fleet.
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
> When the battle is over, the player launches cargo drones that collect loot from the wrecks, and receives credits for destroying the faction's enemies alongside its members.

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
- **Ship loss economy.** Is there insurance? How expensive is a new start? For now (placeholder): the cargo stays in the wreck, credits stay with the pilot, the ship's class and modules are lost, and a pilot who docks in an escape pod gets a free small combat ship. Whether that is too harsh for the first hour is a question for the playtest (third milestone).
- **Time.** Real time with pause? Time acceleration for long travel (X4's SETA)?
- **Travel inside a system.** Distances and speeds; is there a warp / cruise mode? For now the home system is compact (~7 km across, about a minute to cross at 120 m/s).
- **Eternal Enemy.** Who are they, what do they want, can they actually win territory?
- **Factions.** How many, and what makes each one distinct?
- **Visual style.** Which style is achievable for a small team (stylized, low-poly, procedural)?
- **When the invaders win.** Right now they just besiege the military station and the system stays on alert forever (traders never leave the docks). Should the system change hands, should more defenders come from neighbouring systems, should traffic route around it?
- **Enemy target priority.** In the invasion the player sometimes draws almost the whole enemy fleet and dies at once, although allies are close: it feels unfair. Cause: an NPC fighter (`CombatRoutine`) attacks the nearest hostile within detection range and stays on it until it is gone, so a player who flies ahead becomes the target of every invader, and nobody switches when allies arrive. Ideas for attackers: a threat score instead of plain distance (who is shooting me, who damaged me, the target's role and value), a cap on attackers per target to spread the fire, re-picking the target every few seconds, wing roles (some on the station, some on escorts). Priorities depend on the role, not one formula for every fighter: "same rules for everyone" is about mechanics (orders, weapons, damage), while each brain weighs targets its own way. A garrison defends its station first (once stations can be attacked, whoever attacks the station comes first), and roles inside it may differ: fighters clear out the small ships, bigger ships focus on enemies closer to their own size. Tune in dedicated playtests.
- **NPC life.** Why NPCs live, whether they earn and spend money, names, pilots changing ships: see `docs/npc_life.md`.
- **Combat rewards.** How to share a reward fairly among everyone who took part in a fight: see `docs/combat_rewards.md`.
- **Sensors and labels.** Fading ship name labels by distance from the camera felt odd: what you see depended on where the camera was, not on what your ship knows. For now all labels are always visible (debugging). Probably visibility of ships and their labels should come from the player ship's sensors / radar (detection range, maybe signature size). Revisit when ships get sensors. The name labels are a debugging aid anyway: later they go away in favor of a clearer "ships are there" indication; picking a target in a crowded fight is done with the hostile list and the tactical map.

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
- Credits for helping in combat.

Not included yet: multiple systems, full economy, skills, ship fitting UI, station ownership, escape pods.

Draft step order:
1. ✅ A ship in 3D space that moves by commands (move to / approach / orbit / stop), plus camera. Ships fly around obstacles (asteroids) and avoid colliding with each other. Covered by `tests/nav_scenarios.tscn`. Known limit: dense asteroid fields will need real path planning.
2. ✅ Static world: the home system (`scenes/systems/home_system.tscn`) with two stations (trade, military), three gates and an asteroid field in a corner. Field rocks keep wide gaps, so ships can fly through it. Docking and gate jumps come later.
3. ✅ NPC routines (miner, trader, patrol) using the same order system. Ships dock at stations and jump through gates via corridors (one ship per corridor at a time); traders arrive and leave through gates, miners shuttle between their station and the field. A debug panel speeds up time and shows traffic stats.
4. ✅ Combat: weapons, health, destruction, wrecks. Placeholder numbers until there is real equipment: every ship has one auto-firing weapon (75% hit chance, 1 damage, 2 shots/s, 600 m; the hit chance depends on distance and target size since the fourth milestone), 40 shield and 20 armor (no separate hull; doubled after a playtest, fights ended too fast). Weapons fire at the ordered target (Attack order), otherwise at the nearest hostile in range, so everyone defends themselves. Factions are a placeholder: pirates are hostile to all. A destroyed ship leaves a wreck holding "Loot". Abstract beam visuals. Test bed: `scenes/sandbox/combat_sandbox.tscn`. Not yet: line of sight, escape pods, reputation for attacking neutrals.
5. ✅ Invasion event and NPC threat reactions. Started by hand with a button on the debug panel, never automatically (for now). A gate warms up and the system goes on alert; traders shelter at the nearest station or flee through the safest gate, miners run home, patrols head for the gate; the fleet (6 fighters + a leader) comes out of the membrane; the military station launches its garrison (8). After the last invader the alert is lifted and everyone goes back to work. Balance is tuned so the defense usually wins, but not always: the player's help can decide it.
6. Loot drones and combat rewards.
   - ✅ Loot. Wrecks hold what was in the ship's hold plus placeholder loot ("Loot 1" x3, "Loot 2" x2); every piece takes one place in a hold, and ore is an item too. Items are dumb placeholders on purpose: this step is about how looting feels, not about what is looted. What is inside a wreck is unknown until the player's ship or one of its drones comes within 1 km. Two orders, as in X4: **Loot** (R) the selected wreck — the ship comes closer and a drone brings everything; **Loot all** (T) within 5 km — the ship tours the wrecks, sending drones to every one in range (600 m). Drones are small unarmed ships: they can be shot down (with their load, in a tiny wreck), but weapons and fighters pick armed targets first. When the hold gets full the cargo window opens (also I): items dropped from it go into a container behind the ship, which Loot all never picks up again (Loot on it still works). Wrecks and containers left alone for 10 minutes are collected by the system scavenger: it undocks from the trade station, loots them with the same order and drones, docks and is gone with the loot — unless someone destroys it, and then its wreck holds what it had collected. Debug button "Age wrecks +10 min".
   - ✅ Combat rewards (placeholder). Every ship that took part in destroying an enemy gets the reward (how to share it fairly is an open question, see `docs/combat_rewards.md`); for the player it is credits, shown in the HUD (first +1, bounties by class since the third milestone). No real factions or reputation yet; shooting down a neutral earns nothing.

Playtest: ship classes (`ShipClass`, placeholder numbers), to see how fleets of different sizes feel. Medium is the standard ship from before; small ones (fighters) are 30% faster and more agile but 30% weaker (shield, armor, damage, weapon range), large ones the other way round: too slow to chase anyone, they hit from farther away (small 420 m, medium 600 m, large 780 m; added after a playtest where a large ship could not catch a large enemy). Medium ships are twice the size of small ones, large ones four times. The invasion brings 4 small, 2 medium and 1 large ship, the garrison is 5 small, 2 medium and 1 large; patrols are small, miners small and medium, traders medium and large; pirates keep their own numbers (the player's ships got classes in the second milestone). To make room for big ships: ships dock with the nose at the port (big ones stop farther out), ships waiting for a port or a gate line up below it in order of arrival and go in one by one, nobody undocks while a ship is right outside the port, and big ships keep more distance from each other.

## Second milestone: "The loop"

Goal: make the scene repeatable, the first hour of play: fly out, fight or mine, loot, come back
to a station, repair, sell, get a better ship, go again. Placeholder numbers throughout.

1. ✅ Enemy target priority (bare minimum, `CombatRoutine`): at most 3 NPC fighters attack the same target while another target is free, and a fighter re-picks its target every few seconds, switching when a much better one turns up (closer, or less crowded), so a player who flies ahead no longer draws the whole enemy fleet.
2. ✅ Docking for the player: D docks at the selected station. While docked, the station window shows the ship and what the station offers; Undock leaves as soon as the port is free. Every station offers everything for now (`StationServices`).
3. ✅ Repairs and upgrades. The shield recharges by itself, 5% of its maximum every 10 s (in a fight too; to be revised with modules). Armor is repaired only at a station, for credits (as much as the credits pay for). NPC ships have no money yet, so docking repairs them for free. "Upgrade" turns the ship into the next class: small, medium, large (bigger, tougher, slower; the hold doubles with every step). The player now starts in a small ship. Prices: see the third milestone.
4. ✅ Selling: the station buys the whole hold, 1 credit per piece of anything (ore and loot).
5. ✅ Escape pod (player only): a destroyed player ship leaves the wreck (with its cargo) and an escape pod: tiny, slow (30 m/s), unarmed, and nobody shoots at it for now. The pod docks like a ship, and the station gives the pilot a free small combat ship. Credits stay with the pilot. NPC pods, SOS, rescue and captivity come later. The debug "Respawn player" button stays as a fallback for when even the pod is gone.
6. ✅ A second ship: the player also owns a mining ship, waiting docked at the trade station. Only ships with a mining laser can mine (F on a selected rock); the mining ship has no weapon and no drones, but twice the hold; NPC miners carry a laser too. The laser of a bigger ship mines faster in proportion to its hold, so any class fills its hold in the same time (about 50 s for the player's mining ship): an upgrade brings more ore per trip, never slower mining (after the first playtest, see `docs/playtest_notes.md`). At a station the player can board any own ship docked there; the one left behind stays docked.

Playtest: combat feels tolerable and the system alive, but mining in a large ship is dull. Notes and ideas: `docs/playtest_notes.md`.

Not yet: invasions on a timer. The defense station already tops its garrison up to full strength at the start of every invasion, and surviving defenders are repaired when they dock, so a timer would not bleed the defense dry.

## Third milestone: "The first hour"

Goal: the first hour of a lone pilot has to hook on its own. A squad and fleets come later ("From pilot to power"); in the first hour the player cannot afford to hire anyone, so the lone pilot's game must be good by itself. That is exactly where X4 and EVE lose newcomers.

Why (playtest of 2026-10-14, `docs/playtest_notes.md`): the build felt flat. The world lived, but the player had almost nothing to decide (auto-fire, autopilot, auto-engage: the only choice in a fight was whom to shoot), nothing to want or to lose (1 credit for anything, free upgrades, a free ship after death), no threat unless a debug button started an invasion, and no sound at all.

What should hook in the first hour:
- **Decisions in a fight**: modules on energy (see Control model). Buying one changes how the ship plays, not just its numbers.
- **Wants and stakes**: prices and rewards of a real size. A first module within minutes, a medium ship in about twenty, a large one by the end of the hour; losing the ship loses its class and modules.
- **Being small in a dangerous world**: pirates raid the asteroid field now and then. Keep mining or run, fight for the bounty or stay away: risk against reward is a decision even without a squad.
- **Situations the world makes by itself**: raids, invasions, miners in trouble. No quest givers: everything comes out of the simulation, so "the galaxy does not care" still holds.
- **Feedback**: sounds for shots, hits, explosions, modules, alarms, rewards; the loss of the ship is an event, not a silent change in the HUD.

Steps (placeholder numbers throughout, but their size matters):
1. ✅ Energy and modules. Every ship has 100 energy, recharging 5 per second. Afterburner: 40 energy, 6 s of 1.6 times the top speed and acceleration, 4 s cooldown. Shield booster: 50 energy, restores 35% of the maximum shield at once, 3 s cooldown, refused on a full shield. One of each per ship, for sale at every station.
2. ✅ Prices and bounties. Ore and loot sell for 1 credit a piece (a mining trip brings about 200); armor repair 3 credits a point; afterburner 400, shield booster 500; upgrade to medium 1500, to large 4000. A bounty for every destroyed hostile goes in full to every ship that hit it (hits, not shots: flying through a fight with auto-fire should not pay): small 100, medium 200, large 400, so hunting pays about as well as mining, with more risk. A destroyed ship is lost with its class and modules; the pod gets a free small ship, the credits stay. The debug panel gives +1000 credits, so playtests do not start with grinding.
3. ✅ Pirate raids. Every 3 to 5 minutes (the first one after 1.5 to 2.5) two or three small pirates, sometimes led by a medium one, come through a random gate with a warning, prowl the asteroid field and hunt anyone within 1.5 km of it; after 2.5 minutes the survivors leave through the nearest gate (since the fourth milestone they stay until destroyed). One raid at a time, none during an invasion. Pirates do not put the whole system on alert, that is for invasions: traders and traffic go on, miners run home when a pirate comes within 2.5 km (and stay docked while pirates are near the field), patrols hunt any hostile. The player's own miner gets only the warning: run or keep mining is the player's call. Debug button "Pirate raid".
4. ✅ Placeholder sounds, synthesized in code (`Sfx`): shots, hits on the shield and on the armor, explosions (deeper for bigger ships), modules, a refusal, the alarm for warnings, a coin for a reward, and the loss of the player's ship with a message on how to get a new one.

Playtest: does the first hour hook? Count decisions per minute, note where it gets boring and what you wanted. Watch the cost of death: losing a medium ship costs about half an hour of play, which may end a session instead of making a story (the softer option: the pod gets back the class it lost, modules are still lost).

Not yet: NPCs fitting and using modules, NPC money, reputation, more module types.

## Fourth milestone: "Decisions in a fight"

Goal: one fight that is interesting at normal speed with placeholder art, before any more breadth.

Why (second playtest of 2026-10-14, `docs/playtest_notes.md`): with modules, prices, raids and sounds the build still felt flat. The cause the third milestone did not touch: no variable the player controls changes the exchange rate of a fight (the hit chance and the orbit distance were constants), and the world neither needs nor threatens the player (everyone armed, raiders leave on their own, the garrison wins alone). Modules only added HP and an exit on top.

Steps (placeholder numbers, tuned in the combat sandbox):
1. ✅ Hit chance by distance and target size (`Weapon.hit_chance_against()`): 85% within the class's best band (gap between hulls: small 0-200 m, medium 250-450 m, large 350-650 m), less closer in (right next to the target: small 100%, medium 20%, large 15% of it) and farther out (40% of it at max range), times the square root of the target's radius over the shooter's (at most 1, at least 0.5). Every attack (NPCs too) circles at the middle of the best band: small 100 m, medium 350 m, large 500 m.
2. ✅ The player's distance: Z / X step it by 50 m (50 m up to 90% of weapon range), for the attack or orbit under way and later attacks; the order says "Attack Pirate 3 at 150 m". The HUD target lines and a hostile list column show both sides' hit chances; the maps shade the best band.
3. ✅ A world that needs the player: raiders stay until destroyed (a field nobody clears stays lost, its miners stay docked); traders, miners and the scavenger fly unarmed, so only patrols (two small ones, not replaced), the garrison and the player fight pirates.
4. ✅ Combat sandbox: buttons spawn small, medium and large pirates, switch the player's ship to the next class and fit it with modules.

Measured (headless): a small ship attacking a large one at its best distance wins (98 s, median gap 148 m); kept at 380 m it loses (44 s). The default invasion is still repelled without the player in 6 of 6 runs (68-100 s, the garrison loses 1-3 of 8).

Playtest: success if a player who has not read the numbers says "I should get closer" or "I need to stay away" within the first three fights, changes the distance during fights, uses the afterburner to take or break a distance (not only to travel), and once wins a fight they would have lost without that decision. If the hit numbers get read but the distance never gets changed, the lever is too weak or the keys too hidden. Watch: a large ship with a shield booster may out-heal two small pirates (the booster restores a share of the maximum shield); a small ship against a large one takes long (raise small damage if it drags); a large ship bought for 4000 cr may be a failed upgrade against raids of small ships. If fights still feel like waiting, the next candidate is a wing of one or two ships under the player's orders.

Not yet: angular velocity (tracking), weapon types, NPCs using modules, sharing bounties, invasions that need the player.
