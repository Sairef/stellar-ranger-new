# Playtest notes

What playtests showed, newest first. Decisions that follow go into `concept.md`.

## 2026-10-14: still flat after "The first hour"

The user played the third milestone build (modules, prices, raids, sounds): still "nothing", no
hook. Claude played about 15 minutes of game time (two raids, the second with both modules, and an
invasion), and an independent advisor reviewed the code and the numbers; the two diagnoses agreed.

What happened:
- Start: 0 credits, a combat ship that cannot mine, nothing to do until the first raid (~2 min).
- Raid 1: armed traders, miners and a patrol had nearly killed both pirates before the player got
  there; one hit on a pirate at 0/7 paid the full 100 cr.
- Raid 2, with the afterburner and the shield booster: the same. The afterburner only shortened
  the flight; the booster said "not needed" all fight.
- Invasion: three targets picked, all three died before the player arrived; no credits. The
  garrison won in about 70 s.
- About 6 decisions in all, every one "whom to pick" or "press 1 to get there sooner"; no moment
  where the outcome depended on the player, no moment of danger.

Numbers: DPS 1.05 / 1.5 / 1.95, HP 42 / 60 / 78, so every same-class duel took ~40 s whatever
anyone did; the hit chance was a constant, so Orbit / Approach / Stop changed nothing. Alone
against two small pirates a starter ship dies in ~20 s (~34 s with the booster): danger was
binary, either the world fought for you or you died, with no decision either way. The afterburner
is sustainable on its energy (40 per 10 s cycle, 50 recharged): always press it.

Why, most important first:
1. The fight had no variable the player controls: modules added HP and an exit on top of a fixed
   exchange rate. EVE's command combat works through geometry (range, tracking); the orders were
   copied, the geometry was not.
2. The world was self-sufficient: everyone armed, raiders left on their own, the garrison won
   alone, nothing persisted.
3. Nothing to want: one good, one price, four purchases each strictly better, in a fixed order.
4. Command control of a single ship is its weakest form (an RTS with one unit).
5. Process: many systems at bare minimum, none deep; the placeholder rule was applied to the
   degrees of freedom of mechanics (one hit constant, one orbit distance), which are what
   decisions are made of, not content. No pillar says what a minute of play should feel like, and
   the key scene casts the player as an extra on the flank.

Measured before deciding: the angular velocity between two ships in AttackOrders (headless, weapons
off). Ships that want the same distance circle each other (small: 1.1 rad/s, constant); ships that
want different distances end up in a near-parallel chase (0.06-0.2 rad/s) where the faster one gets
roughly its distance; high angular velocity against a large ship only when it sits still. So
tracking would rarely matter in fights between classes and would be invisible to the player.

Decision: the fourth milestone, "Decisions in a fight" (`concept.md`): hit chance by distance and
target size, Z / X for the distance, hit chances in the HUD, raiders stay until destroyed, traders
and miners unarmed. Advisor points taken: one hit-chance function for the weapon and the HUD, a
floor for the size factor, hit chances in the hostile list, the best band on the maps, success
measured by whether the player changes the distance unprompted. Not taken: its flatter medium band
(a small ship could never beat a medium one), bracket keys (Z / X sit under the left hand next
to the other order keys).

## 2026-10-14: the build feels flat

The user played and felt the build was "nothing": no hook. Claude then played two invasions
itself (driving the game through the editor, with a recorder logging shield, armor, shots, hits
and kills every second). Placeholder art was not the problem: the game had nothing for the
player to do.

What happened:
- Invasion 1, small combat ship. Approach to the gate flew straight into the enemy fleet (no
  warning); dead about 10 s after first contact, before the first order. The pod crawled 2.5 km at
  30 m/s (about 85 s), and the garrison won the whole 90 s battle meanwhile: the key scene was
  spent in the pod. The death itself was silent: the HUD just said "Escape pod".
- Loot all: 15 wrecks in about 3 minutes, 3 key presses, 75 credits, nothing to spend them on
  (upgrades were free, no damage to repair).
- Invasion 2, large ship (free upgrade, as any player would take): 40 s of travel, a kill 8 s
  after pressing E with nothing to do meanwhile (+1 credit), then a chase after the enemy large
  ship closing at 4 m/s from 1.9 km: about 4.5 minutes to get into range.
- In about 6 minutes of game time: some 30 s of fighting and 2 decisions, both "whom to shoot".

Why, most important first:
1. The player is a spectator: auto-fire, autopilot, auto-engage. Command-based control needs
   decisions on top of orders (EVE: modules, capacitor, range; FTL: power, timing; Starsector:
   flux). Doubling health after "fights end too fast" lengthened fights with nothing in them.
2. Nothing to want, nothing to lose: 1 credit for anything, free upgrades, a free ship. The "price
   1" placeholder rule is fine for content, but it makes a loop impossible to playtest: the
   motivation of "earn, then buy" is those numbers.
3. No threat without the debug button: no pirates in the home system. "The galaxy does not care"
   turned into "the galaxy does nothing to you".
4. No consequences: after an invasion everything goes back to how it was.
5. No feedback: no sound at all, a silent death, a tiny ship, panels over 40% of the screen.
6. From each reference the simulation scaffolding was taken, not what hooks: EVE without the
   danger of other players, Space Rangers without quests and events, X4 without the empire,
   Kenshi without brutality and without the squad.
7. Many systems were built, but "is it fun" was never a check: notes judged the world ("alive",
   "tolerable"), not the player (what did I decide, want, fear).

Decision: the third milestone, "The first hour" (`concept.md`): modules on energy, prices and
bounties of a real size, pirate raids on the field, placeholder sounds. An advisor review moved a
few things: pirates do not put the whole system on alert (only miners nearby and patrols react),
bounties are paid for hits, not shots, and are big enough that hunting pays like mining.

Bugs found on the way: an escape pod accepted Attack (fixed: only an armed ship can attack); the
selection ring around a station seen from close by covers half the screen (open).

## 2026-10-14: a large ship cannot catch a large enemy

Invasion near Bastion Outpost, the player in a large ship. After a few small kills together
with the garrison the player picked the large invader. It flew away, the player never caught up,
and the garrison's small and medium ships destroyed it. That felt very strange.

Why, from the code: the enemy picks its own target and ignores who attacks it, so it went after
a garrison ship and away from the player; both large ships fly 84 m/s, so a target that flies
away cannot be caught at all; the Attack order circled toward the target's current position
instead of where it would be; every class had the same 600 m weapon range, so the large ship had
nothing to make up for its speed.

Options considered: a chase with an intercept; weapon range by class; threat (enemies prefer
whoever shoots them, harder hitters first); tackle like EVE's webs and scramblers (later, with
modules); an afterburner (an active choice in a fight); range ring and "out of range" in the HUD;
a share of the reward for everyone who attacked.

Done (to try):
- Weapon range by class: small 420 m, medium 600 m, large 780 m. A large ship hits from farther
  away instead of chasing.
- The Attack order chases a target at the edge of range: straight to the intercept point, then
  circles again. Measured: only 0-10% faster to get in range than before (the old approach flew
  almost straight anyway), so most of the gain comes from the range.
- A faint weapon range ring around the player's ship on the minimap and the tactical map.

Open: none of this helps when the enemy flies away after someone else at the same speed (that was
part of this case). If it still feels wrong, try threat next.

## 2026-10-14: awareness

- Not seeing everything that goes on around the ship feels uncomfortable, even to a player used
  to space and 3D games. Added a minimap in the bottom right corner: the tactical map's icons,
  centered on the ship, clickable, zoomed with the wheel.

## 2026-10-13: second milestone "The loop"

Build: docking, repairs and upgrades, selling, the escape pod, the mining ship, enemy target
priority (see `concept.md`, "Second milestone").

- **Combat feels tolerable.**
- **The system feels alive.**
- **Mining in a large ship is dull.** Nothing happens while the laser works and the hold fills.
  How others avoid this:
  - EVE: mining is never safe. A PvP player may show up at any moment, and NPC pirates spawn
    in the belts, so the miner keeps watching.
  - X4: mining can be automated. The player gives miners orders and does something else.
  - Space Rangers: there is no mining at all.

  Open: needs thinking. Ideas to consider, nothing decided:
  - Risk in the field: pirates now and then come to the asteroid field to hunt miners (EVE).
  - Automation: hire or buy miners and send them to work with orders, as the start of
    "from pilot to power" (X4). In X4 this works even for the player's own ship: hire a pilot,
    give the order, and the ship mines while the player sits in it, looks at the map, commands
    other ships, or leaves to make tea. Here that would be the NPC brain (`MinerRoutine`)
    flying the player's ship, which pillar "Same rules for everyone" makes natural.
  - Decisions while mining: rocks of different quality worth seeking out (ties into "item
    quality comes from materials").
  - Balance: the hold should fill in about the same time on any class, say 40-60 s, so an
    upgrade never makes mining slower, only more profitable per trip. Example: a small miner
    holds 100 and its laser gives 20 per cycle, a large one holds 1000 and gives 200 per cycle.
    In this build the laser gave the same 4 pieces per second on every class while the hold
    doubled with each class: about 50 s for a small miner (hold 200), 100 s for a medium one and 200 s for a
    large one. That is probably a big part of why mining in a large ship felt dull.
    Done (bare minimum): the laser's output now grows with the hold (`MiningLaser.mining_rate()`),
    so every class fills its hold in about 50 s. Exact numbers and mining in cycles wait for
    real balancing.
