# First real feedback: the first 30 minutes

Blind playtest of the home system by Claude, 2026-10-14. No docs were read beforehand; everything
was learned from the HUD. About 26 minutes of real time, more in game time (travel and waiting
ran at x3-x8, fights at x0.05-x0.5 to make up for slow reactions). The story, quests and the single
system were out of scope by request.

## Verdict

The first ~10 minutes are good: it is clear what to do, and small wins come one after another.
Then a pirate raid arrived, and the next ~15 minutes were mostly waiting and frustration. The
mechanics themselves work; what breaks the game is how they combine.

## How the session went

- **Start.** 0 credits, a combat ship (small) and a mining ship (small, hold 200) at Halcyon
  Exchange. Figured out the controls in a couple of minutes without docs.
- **Mining.** Picked a rock on the minimap and pressed F; the hold filled in about 1.5 game
  minutes. Sold it for **200 cr**.
- **First pirate.** A lone small pirate, 85% hit chance on both sides. It fled at 0 shield, I
  chased it down and killed it: **100 cr** bounty. Drones (T) collected the wrecks for another
  **25 cr**; the armor repair cost 11.
- **Second hold.** 514 cr in hand, bought the shield booster for 500.
- **The raid.** Four pirates (one medium 40/20, three small 28/14) arrived and **camped the
  asteroid field until the end of the session**. While I waited docked at x8, about 70 ships went
  through the gates, and the pirates never left.
- **First death.** Attacked the group; all four switched to me. Lost the ship and the 500 cr
  booster with it. My mistake, not latency.
- **Second death.** Tried to mine at the edge of the field; at x4 I did not react in time and
  lost the mining ship. **Took +1000 cr once here**, as allowed for latency deaths.
- **Second fight.** Bought the afterburner and the booster and went in again. The medium keeps
  350-425 m and hits me 40-60% from a range where I cannot hit it. The trade was 4 damage dealt
  for 7 taken. Escaped on the afterburner (250 m/s): the pirates fell back to 480 m and stopped
  hitting. **The most alive moment of the session.**

## What works

- **No tutorial needed.** All keys are on screen, unavailable actions are greyed out, and a hint
  line sits at the bottom.
- **The hostile list** with "Attacking: YOU" and "Hit %: me/it" is the best part of the UI. Every
  combat decision was made from it.
- **Picking targets** by clicking the minimap and the tactical map is convenient.
- **Escape pod and a free starter ship.** Death punishes but does not reset the game. Pirates
  leave the pod alone, which feels right.
- **Prices in peaceful time feel right.** A module costs 2-2.5 holds, a first goal for 5-7
  minutes. The 1500 cr upgrade is a fine long-term goal.
- **Emergent moments.** Pirates chased my loot drone and gave me a head start. The afterburner
  escape is genuinely tense.

## What does not work (by importance)

1. **A raid turns into an endless siege.** Four pirates with a medium cannot be beaten by a small
   ship. The field becomes their camp, the system has no defense, and they never leave on their
   own. The only "move" left to the player is waiting docked at x8. In the first half hour this is
   a wall.
2. **Losing the mining ship loses mining for good.** The station only offers "Upgrade to medium";
   there is no way to buy a ship, and the combat ship has no laser. Together with point 1 this is
   a dead end: nothing to mine with, and fighting is hopeless.
3. **A small ship has no answer to a medium.** The medium holds the range where it hits and I do
   not. Maybe by design, but the game does not explain it: you just lose the damage trade.
4. **Mining is fully passive:** press F and wait. Fine in peaceful time, but the only tension
   comes from pirates, and it is binary: either nothing happens or you die.
5. **The UI overlaps itself:**
   - the red "Hostile ships in the system" message covers the Undock button;
   - the hostile list covers the station window (it reads "Combat s|hip");
   - on the tactical map about half the area is hidden under the HUD, the hostile list and the
     debug panel;
   - the selection ring of the docked station is a yellow circle the size of the screen.
6. **The second station (Bastion Outpost) is a copy of the first:** same goods, same prices, no
   reason to fly there. Gates can be selected but there is no jump: a promise the game does not
   keep.

## Bare-minimum fixes I would do first

1. A raid ends on its own: pirates leave after N minutes or after a few attacks. Another option:
   while the player flies a small ship, a raid has at most 2 ships.
2. Stations sell a basic mining ship and a basic combat ship for a couple of holds.
3. Hide the hostile list and the debug panel while docked and while the map is open, and move the
   system message off the Undock button.
