---
name: testing-tips
description: Practical know-how for QA hunts in Stellar Ranger - headless viewport size, probe workflow, flaky chaos coverage, concurrent edits by the main session
metadata:
  type: feedback
---

- **Probe first in `tests/scratch/`** (gitignored): a throwaway suite + .tscn extending
  check_suite.gd, with prints of internal state (`obj.get("_queue")`, `obj.call("_private")`), then
  port the confirmed failing checks into the real suites. Fast to iterate.
- **The headless window is 1152x1152** (visible rect square) unless a test sets
  `get_window().size`; layout checks must set it explicitly and restore it afterwards.
  `get_window().size = Vector2i(w, h)` does change the visible rect headless.
- **chaos_checks coverage checks are flaky**: "drone: 0" failed in 1 of 2 runs (seed 2024, physics
  differs run to run). Rerun before reporting a chaos failure as a game bug.
- **The main session edits src/ while QA runs** (it fixes tech-lead findings in parallel). Re-read
  the diff of a file before reporting; a probe that "passes" may be passing on new code. Report
  fixed-meanwhile bugs as such and add regression checks for them.
- Raid/invasion scenarios: disable weapons of every ship (`weapon.enabled = false`) to keep fights
  from ending the event; `take_hit(1000)` kills small pirates; tree order is Stations (Garrison)
  < Invasion < PirateRaids, so in one tick the garrison undocks before the events act.

**Why:** learned in the 2026-10-15 hunt; each one cost a rerun or a false lead.
**How to apply:** follow these when writing headless checks; see [[fragile-areas]].
