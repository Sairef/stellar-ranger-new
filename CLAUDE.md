All docs and comments should be English only.

## Project

Single-player 3D space sandbox in Godot 4.7 (GDScript, Jolt physics). The game concept,
design pillars and milestone plan are in `docs/concept.md` — read it before design work.

## Layout

- `src/ships/` — `Ship` (flight model), `Autopilot` (obstacle/traffic avoidance), `NpcRoutine`.
- `src/ships/orders/` — `ShipOrder` and its subclasses. Player and NPCs control ships only
  through `Ship.give_order()` (pillar "Same rules for everyone").
- `src/world/` — asteroids, labels, sky shader. `src/player/` — input and camera.
  `src/ui/` — HUD. `src/debug/` — debug overlays.
- `scenes/sandbox/flight_sandbox.tscn` — main scene, a test bed for flight and navigation.
- `tests/` — headless scenario tests.

## Tests

Navigation scenarios run headless, faster than real time:

```
D:/Godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . --fixed-fps 60 res://tests/nav_scenarios.tscn
```

Exit code 0 means all scenarios passed. Run `--headless --path . --import` first if new
`class_name` scripts were added while the editor was closed.
