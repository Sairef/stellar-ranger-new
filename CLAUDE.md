All docs and comments should be English only.

## Project

Single-player 3D space sandbox in Godot 4.7 (GDScript, Jolt physics). The game concept,
design pillars and milestone plan are in `docs/concept.md` — read it before design work.

## Layout

- `src/core/` — `WorldRegistry` (the `World` autoload: ids of world objects) and `ObjectRef`.
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
- `tests/` — headless scenario tests; `tests/support/` — shared test helpers.

## Tests

Navigation scenarios run headless, faster than real time:

```
D:/Godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . --fixed-fps 60 res://tests/nav_scenarios.tscn
```

Exit code 0 means all scenarios passed. Run `--headless --path . --import` first if new
`class_name` scripts were added while the editor was closed. Camera controls have their own
checks in `res://tests/camera_checks.tscn`, mouse picking in `res://tests/picking_checks.tscn`
combat in `res://tests/combat_checks.tscn`, and `res://tests/chaos_checks.tscn` removes random
world objects at random moments while the home system runs (same command). Every suite fails
on any error logged during the run (`tests/support/error_log.gd`). Spawn ships with
`Ship.enter_space()`, not add_child + move: physics may push apart bodies that briefly overlap.

## World objects and references

Ships, stations, gates, rocks and wrecks (later pods, loot) can vanish at any moment. Each has a
stable `object_id` in the `World` registry (`src/core/world_registry.gd`).
- Anything that keeps a reference to a world object longer than one frame stores an `ObjectRef`
  (`ObjectRef.to(node)`), never the node, and calls `resolve()` when it needs the object. That
  returns the live object or null, never a freed one. Expose it as a property with a getter
  (see `ApproachOrder.target`, `PlayerController.selected`), so callers just read a node or null.
- A raw node reference is fine within one frame: taken from a group, the registry or a resolve().
- Why: a freed object compares equal to `null`, and passing one to a typed parameter fails on the
  call itself. Ids are also what save games and off-screen simulation will need.
- New world object types: add `object_id` and register in `_enter_tree`/`_exit_tree` (see
  `SpaceBody`, `Ship`), then cover them in `tests/chaos_checks.gd`.
- Lambdas must not capture nodes that may vanish; track them through signals.

## Driving the running game (godot-ai MCP)

The MCP input emulator cannot drag the mouse, so the camera also listens to the keyboard:
`game_manage` `input_key` with `"Kp 4"` / `"Kp 6"` / `"Kp 8"` / `"Kp 2"` rotates by exactly 15
degrees, `"Kp Add"` / `"Kp Subtract"` zooms one step, `"Up"` etc. rotate while held.
Mouse wheel and clicks work through `input_mouse`. `get_node_info` with `path: "Camera"`
shows the camera state; `editor_screenshot` with `source: "game"` captures the frame.
