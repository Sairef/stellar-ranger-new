All docs and comments should be English only.

## Project

Single-player 3D space sandbox in Godot 4.7 (GDScript, Jolt physics). The game concept,
design pillars and milestone plan are in `docs/concept.md` — read it before design work.

## Layout

- `src/ships/` — `Ship` (flight model), `Autopilot` (obstacle/traffic avoidance), `NpcRoutine`.
- `src/ships/orders/` — `ShipOrder` and its subclasses. Player and NPCs control ships only
  through `Ship.give_order()` (pillar "Same rules for everyone").
- `src/world/` — `SpaceBody` (base for static objects: a navigation sphere plus generated
  placeholder visuals) and its subclasses `Asteroid`, `Station`, `Gate`; `AsteroidField`;
  labels, sky and gate shaders. `src/player/` — input and camera. `src/ui/` — HUD.
  `src/debug/` — debug overlays.
- `scenes/systems/home_system.tscn` — main scene: the first star system.
- `scenes/sandbox/flight_sandbox.tscn` — a small test bed for flight and navigation.
- `tests/` — headless scenario tests.

## Tests

Navigation scenarios run headless, faster than real time:

```
D:/Godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . --fixed-fps 60 res://tests/nav_scenarios.tscn
```

Exit code 0 means all scenarios passed. Run `--headless --path . --import` first if new
`class_name` scripts were added while the editor was closed. Camera controls have their own
checks in `res://tests/camera_checks.tscn` (same command).

## Driving the running game (godot-ai MCP)

The MCP input emulator cannot drag the mouse, so the camera also listens to the keyboard:
`game_manage` `input_key` with `"Kp 4"` / `"Kp 6"` / `"Kp 8"` / `"Kp 2"` rotates by exactly 15
degrees, `"Kp Add"` / `"Kp Subtract"` zooms one step, `"Up"` etc. rotate while held.
Mouse wheel and clicks work through `input_mouse`. `get_node_info` with `path: "Camera"`
shows the camera state; `editor_screenshot` with `source: "game"` captures the frame.
