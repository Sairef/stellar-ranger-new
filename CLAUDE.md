All docs and comments should be English only.

## Project

Single-player 3D space sandbox in Godot 4.7 (GDScript, Jolt physics). The game concept,
design pillars and milestone plan are in `docs/concept.md` — read it before design work.

Current stage: playtests of how mechanics feel. Build the mechanic properly, but stub the content
with the dumbest placeholders ("Loot 1", size 1): no item variety, drop tables, multiple
currencies or balancing unless asked. Prices and rewards are the exception: give them a size that
makes the loop work (what things cost against what the player earns is part of the mechanic being
playtested, see "Third milestone" in `docs/concept.md`). Propose the bare-minimum version of a
feature first.

## Layout

- `src/core/` — `WorldRegistry` (the `World` autoload: ids of world objects) and `ObjectRef`.
- `src/ships/` — `Ship` (flight model, docking, jumping, shield/armor, cargo, escape pod),
  `Autopilot`
  (obstacle/traffic avoidance), NPC brains (`NpcRoutine` for patrols/orbits, `TraderRoutine`,
  `MinerRoutine`, `CombatRoutine`, `ScavengerRoutine`, `DroneRoutine`), `TrafficSpawner`
  (traders arriving through gates), `DroneBay` (cargo drones), `MiningLaser` (only ships with
  one can mine), `ShipClass` (placeholder small/medium/large ships: size, numbers, hold; an
  upgrade moves a ship one class up; also where each class's weapon hits best), `miner_ship.tscn`
  (a laser, no weapon: NPC miners), the player's loadouts: `player_ship.tscn` (combat ship
  with a weapon and a drone bay; also the starter ship a pod gets at a station) and
  `player_miner.tscn` (the mining ship with a bigger hold).
- `src/ships/modules/` — `ShipModule` (a part the pilot switches on, keys 1, 2, ...; runs on the
  ship's energy) and its subclasses `Afterburner` and `ShieldBooster`.
- `src/items/` — `Items` (placeholder item ids) and `Cargo` (a hold: pieces, one place each).
- `src/audio/` — `Sfx`: placeholder sound effects synthesized in code (no audio files).
- `src/ships/combat/` — `Weapon` (auto-firing, a child node in `ship.tscn`; its hit chance
  depends on distance and target size, `hit_chance_against()`, which the HUD shows too), `Factions`
  (placeholder hostility), placeholder effects (`CombatEffects`, `FadingEffect`).
- `src/ships/orders/` — `ShipOrder` and its subclasses. Player and NPCs steer ships only
  through `Ship.give_order()` (pillar "Same rules for everyone"); momentary acts next to the order
  (`Ship.activate_module()`, `Ship.jettison()`) are Ship methods both sides call. Docking and gate jumps go
  through structure corridors (`SpaceBody` corridor API, one ship per corridor at a time; waiting
  ships line up below the corridor in order of arrival).
- `src/world/` — `SpaceBody` (base for static objects: a navigation sphere plus generated
  placeholder visuals) and its subclasses `Asteroid`, `Station`, `Gate`, `Wreck` (wrecks and
  dropped cargo containers: things to loot); `AsteroidField`; `SystemSecurity` (hostiles around
  and the invasion alert NPCs react to), `Invasion` (the event, started by a debug button),
  `PirateRaids` (pirates raiding the asteroid field on a timer; `create_pirate()` is the one place
  pirates are made), `SalvageService` (the scavenger), `StationServices` (what a docked ship can
  buy and sell: repairs, modules, upgrades, cargo), `Bounties` (credits for destroyed hostiles);
  labels, sky and gate shaders. `src/player/` — input and camera; `PlayerController`
  also keeps the player's credits and fleet (the ship flown, other owned ships, boarding).
  `src/ui/` — HUD, the cargo window, the station window (while docked), the hostile list, the
  tactical map (M: top-down view with icons; its camera replaces the controller's while open),
  the minimap (bottom right, follows the ship; both maps draw and pick with `MapPainter`) and
  the debug panel (time scale, traffic stats; home of manual
  debug triggers).
  `src/debug/` — debug overlays, test-bed scene scripts, `PlayerRespawner`.
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
checks in `res://tests/camera_checks.tscn`, mouse picking (3D view, map and minimap) in `res://tests/picking_checks.tscn`,
combat (hit chance by distance, bounties, modules, sounds too) in `res://tests/combat_checks.tscn`, loot (cargo, drones,
loot orders, the scavenger) in `res://tests/loot_checks.tscn`, stations and the player's loop
(docking, repairs, modules, upgrades, selling, boarding, mining, the escape pod, shield recharge)
in `res://tests/station_checks.tscn`, the invasion in `res://tests/invasion_checks.tscn`, pirate
raids in `res://tests/raid_checks.tscn`, the game as it really boots in
`res://tests/startup_checks.tscn` (its main scene contains the home system: references set by a
scene resolve at boot), and `res://tests/chaos_checks.tscn` removes random world objects at random
moments while the home system runs (same command). Suites extend `tests/support/check_suite.gd`
(checks, a scenario world, simulation helpers); every suite fails on any error logged during the
run (`tests/support/error_log.gd`). Suites that run the home system for something other than
raids switch `PirateRaids.auto` off, so a raid does not turn up in the middle. Spawn ships with
`Ship.enter_space()` and wrecks/bodies with `SpaceBody.enter_space()`, not add_child + move:
for a physics tick the body sits at the parent's origin and may push whatever is there.
Simulated mouse events need viewport coordinates: `get_viewport().push_input(event, true)`
(headless, the window is scaled, and screen coordinates land far off).

## World objects and references

Ships (drones too), stations, gates, rocks, wrecks and containers (later pods) can vanish at
any moment. Each has a
stable `object_id` in the registry (`src/core/world_registry.gd`, owned by the `World` autoload).
Use its static functions (`WorldRegistry.find()`, `id_of()`), not the autoload's global name:
the editor's script analyzer may not know that name (e.g. after adding the autoload via MCP),
and then every script using it, @tool ones included, fails to compile in the editor.
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
The Debug panel's Time buttons (x0.25 to x8) make up for the latency of a driving agent: slow
down for fights, speed up for travel.

## Team (subagents)

`.claude/agents/` holds a game studio team. The main session writes the code; the agents design,
review, test and play. Call them on your own initiative and freely (cost is not a concern):
- `producer`: what to do next, its bare-minimum version, what to cut, debt from playtests.
- `game-designer`: why build it, pillars, the player's experience; design forks; judges playtest
  reports against the milestone's goal.
- `systems-designer`: the spec (rules, numbers, edge cases, acceptance criteria), measured in
  throwaway scenes under `tests/scratch/` (gitignored); checks the implementation against it.
- `ux-designer`: the production interface (the current UI is a debug prototype); writes to
  `docs/ui/`.
- `qa`: breaks the change and pins each bug with a failing check (edits only `tests/`).
- `tech-lead`: correctness, architecture and the rules of this file; architecture forks.
- `playtester`: plays blind through godot-ai and reports how it feels.
- `modeler`: low-poly models as Blender Python scripts (`art/`), built headless into
  `assets/models/*.glb`; the main session integrates them. The official Blender MCP (`Blender`
  server) reaches the Blender the user keeps open: the modeler shows its models there.

The usual flow for a mechanic: producer and game-designer, then systems-designer (and ux-designer
if the player sees it), then the main session implements, then qa and tech-lead in parallel,
fixes, then the playtester, and the game-designer reads its report against the goal; then the
user plays. Small fixes skip the design steps. The playtester and the ux-designer need the game
window: first check that the user is not playing (ask if unsure), and never run both at once.
Agents cannot ask the user: they return open questions, and the main session asks. The main
session weighs their advice (it is not an order), tells the user in short what was taken and what
was not, and saves playtest reports verbatim in `docs/playtests/`. QA and the tech lead keep their
own memory in `.claude/agent-memory/` (committed). Agents get CLAUDE.md but not the main
session's auto memory: knowledge they need goes into their agent file or here.
