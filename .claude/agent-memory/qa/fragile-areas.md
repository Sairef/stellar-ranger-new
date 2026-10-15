---
name: fragile-areas
description: Where Stellar Ranger bugs cluster (garrison/raid/invasion overlap, UI thresholds, HUD layout on non-16:9 canvases) and the bug patterns seen so far
metadata:
  type: project
---

Bug patterns found in hunts (first: 2026-10-15, garrison / raid squad / ship purchase / HUD change):

- **Shared queues between event callers.** `Garrison` keeps one undock queue fed by `launch()` (raid
  squads) and `launch_all()` (invasions); `cancel()` by one caller must not keep home a ship the other
  caller needs. Fixed by launch_all taking ownership of queued refs; covered by
  raid_checks "A raid ends after an invasion called its squad". Probe any new caller of the queue.
- **An event's `_finish()` must undo its pending launches.** Invasion._finish once forgot to cancel
  the garrison queue (ships kept undocking after the all clear). Check every new event's finish path.
- **Threshold UI fixes need measuring at the default camera.** `PlayerController.MAX_MARKER_SHARE`
  (0.8) did not hide the docked station's ring: from the port at the default camera distance (400) the
  ring is ~72% of the screen height. Measure the real value before trusting a cap.
- **HUD layout depends on the canvas aspect.** stretch canvas_items + expand: width stays 1152,
  height grows on squarer windows, the minimap grows with height (MINIMAP_SHARE) and squeezes the
  banner between it and the hostile list (640 wide). Square canvas -> banner 49 px wide, off the top.
- **Raid squad bounces home** when no raider is inside the field's territory at launch (only with
  short `response_delay` in tests; at 180 s raiders are there). Squad scheduling counts that as
  "squad home while raiders remain" and sends another after the delay.

**Why:** these are the places where a change "looked done" but the overlap case or the real
numbers were not checked.
**How to apply:** start the next hunt by re-probing these; see [[testing-tips]] for how.
