---
name: decision-garrison
description: Architecture decision 2026-10-14 - one Garrison component per military station owns its ships; Invasion and PirateRaids (raid response squad) both launch from it. Implemented 2026-10-15.
metadata:
  type: project
---

Decided 2026-10-14 (raid response squad fork, options: A = PirateRaids owns its own squad,
B = shared Garrison): **B**. A `Garrison` node is a child of the military station (Bastion
Outpost), found with `Garrison.of(station)` (by type, not node name) and never stored: callers
keep the station NodePath and look the garrison up each use. It owns the composition (full
strength per class), the ships (ObjectRefs), the defender factory (the one place defenders are
made, like `PirateRaids.create_pirate()`), top-up before each launch, and the undock queue (one by
one as ports free). `launch(sizes, territory)` / `launch_all()` / `cancel(refs)` / `is_out(ship)`.
Events (Invasion, PirateRaids) keep only their timing and announcements.
Companion brain rule: a CombatRoutine with a territory knows every hostile inside it (territory
replaces detection range); with home + territory it docks home once the territory is clear.

**Why:** two pools of military ships at one station would duplicate the factory and the undock
loop, make a docked raid squad sit out an invasion, and split state that save games and the
off-screen simulation will want keyed by station id ("Bastion has N ships"). Station destroyed ->
garrison node gone with it, no extra bookkeeping.

**How to apply:** new events that need the military (escorts, hired wings, sector defense) go
through Garrison, not their own ship factories. Watch in reviews for: storing the Garrison node,
events creating defender ships directly, a second undock-queue loop. Open design knob: top-up is
instant (losses do not weaken the next event); a rebuild time would be a Garrison property.
Known gaps accepted then: ships flying home when launch_all() runs and docking afterwards stay
docked; squad ships whose station vanished keep roaming the field.

Implementation review 2026-10-15 (matched the shape; all suites green). Follow-ups raised:
every event that launches must cancel its still-queued ships when it ends (Invasion did not:
launch_all() should return its refs like launch()); `cancel()` erases by ObjectRef *instance*, so
one event can cancel a ship another event re-tasked. When a third task appears (escort, sector
defense), give Garrison a per-ship task/owner instead of events sharing the queue.
See [[recurring-findings]].
