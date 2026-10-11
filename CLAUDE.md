All docs and comments should be English only.

## Project

Single-player 3D space sandbox in Godot 4.7 (GDScript, Jolt physics). The game concept,
design pillars and milestone plan are in `docs/concept.md` — read it before design work.

## Layout

- `src/ships/` — `Ship` (flight model, docking, jumping, shield/armor), `Autopilot`
  (obstacle/traffic avoidance), NPC brains (`NpcRoutine` for patrols/orbits, `TraderRoutine`,
  `MinerRoutine`, `CombatRoutine`), `TrafficSpawner` (traders arriving through gates).
- `src/ships/combat/` — `Weapon` (auto-firing, a child node in `ship.tscn`), `Factions`
  (placeholder hostility), placeholder effects (`CombatEffects`, `FadingEffect`).
- `src/ships/orders/` — `ShipOrder` and its subclasses. Player and NPCs control ships only
  through `Ship.give_order()` (pillar "Same rules for everyone"). Docking and gate jumps go
  through structure corridors (`SpaceBody` corridor API, one ship per corridor at a time).
- `src/world/` — `SpaceBody` (base for static objects: a navigation sphere plus generated
  placeholder visuals) and its subclasses `Asteroid`, `Station`, `Gate`, `Wreck`; `AsteroidField`;
  labels, sky and gate shaders. `src/player/` — input and camera. `src/ui/` — HUD and the
  debug panel (time scale, traffic stats; home of manual debug triggers).
  `src/debug/` — debug overlays and test-bed scene scripts.
- `scenes/systems/home_system.tscn` — main scene: the first star system.
- `scenes/sandbox/flight_sandbox.tscn` — a small test bed for flight and navigation.
- `scenes/sandbox/combat_sandbox.tscn` — combat test bed: the player, a pirate, debug buttons.
- `tests/` — headless scenario tests.

## Tests

Navigation scenarios run headless, faster than real time:

```
D:/Godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . --fixed-fps 60 res://tests/nav_scenarios.tscn
```

Exit code 0 means all scenarios passed. Run `--headless --path . --import` first if new
`class_name` scripts were added while the editor was closed. Camera controls have their own
checks in `res://tests/camera_checks.tscn`, mouse picking in `res://tests/picking_checks.tscn`
and combat in `res://tests/combat_checks.tscn` (same command). Spawn ships with
`Ship.enter_space()`, not add_child + move: physics may push apart bodies that briefly overlap.

## Freed objects (ships die, jump out)

Any reference to a ship, a selection or an order target may point to a freed object.
- A freed object compares equal to `null`: use `is_instance_valid()` to test it, and
  `is_same()` when "nothing" must be told apart from "freed".
- Passing a freed object to a typed parameter (`func f(node: Node)`) fails on the call itself,
  before any check inside. Helpers that may receive one take `Variant` and check validity
  (`Autopilot.name_of()`, `radius_of()`).
- Lambdas must not capture ships that may be freed; track them through signals.

## Driving the running game (godot-ai MCP)

The MCP input emulator cannot drag the mouse, so the camera also listens to the keyboard:
`game_manage` `input_key` with `"Kp 4"` / `"Kp 6"` / `"Kp 8"` / `"Kp 2"` rotates by exactly 15
degrees, `"Kp Add"` / `"Kp Subtract"` zooms one step, `"Up"` etc. rotate while held.
Mouse wheel and clicks work through `input_mouse`. `get_node_info` with `path: "Camera"`
shows the camera state; `editor_screenshot` with `source: "game"` captures the frame.
