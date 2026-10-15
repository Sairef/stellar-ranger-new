---
name: recurring-findings
description: Review findings that keep coming back in Stellar Ranger changes (stale doc comments, event cleanup on finish, magic column indices); check these first in every review
metadata:
  type: feedback
---

Patterns seen in reviews; check them first.

1. **Behavior changed, function doc not.** The class header gets rewritten, but the one-line doc
   on the function whose rule changed is left stale (2026-10-15: `CombatRoutine._best_target`
   still said "within detection range" after territory replaced it).
   **Why:** the main session updates headers and CLAUDE.md diligently but misses the inner docs.
   **How to apply:** for every changed condition, read the doc line directly above its function.

2. **An event's `_finish()` forgets what the old code cleaned up.** When logic moves out of an
   event into a shared service (Garrison), the cleanup the event did on finish (clearing its
   launch queue) is easily lost.
   **How to apply:** diff the removed `_finish()` lines against the new ones; ask "what is still
   pending in the service when the event ends?"

3. **Magic column indices in UI tables** (`HostileList`: some columns have `COLUMN_*`, others are
   raw ints that shift when a column is inserted).
   **How to apply:** when a column is added, every index should be a named constant.

Related: [[decision-garrison]].
