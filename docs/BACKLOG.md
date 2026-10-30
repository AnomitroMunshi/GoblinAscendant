# Goblin Ascendant — Backlog & Progress

Living file, updated by the lead as work lands. Newest log entries on top.
Status keys: ✅ done & verified · 🟡 partial / unverified · ⏸ paused · ⬜ not started

## Current focus (2026-10-30)
**Player-only build — basic movement.** The game boots into a movement playground
(`scripts/main/movement_playground.gd`, `PLAYER_ONLY = true` in `scripts/main/main.gd`).
World, Combat and UI agents are paused by user request; their partial files stay on disk, unwired.

## Status by area
| Area | Status | Notes |
|---|---|---|
| Lead foundation (autoloads, input map, damage/faction/interaction/save interfaces, world layout) | ✅ | Runs headless clean |
| Player & camera (`scripts/player/`) | ✅ | 42/42 headless tests (agent); now being hand-checked in the playground |
| Movement playground (`scripts/main/movement_playground.gd`) | ✅ | Slopes 15–55°, stairs, jump course, camera corridor/tunnel, pillars, pool. Verified windowed: spawn, run 5.2 m/s, jump, heavy attack; screenshots in `tests/screens/` |
| Progression, abilities, quests (`scripts/progression|abilities|quests/`) | 🟡 | 136/136 headless tests (agent); not used in player-only build |
| World & environment (`scripts/world/`, `shaders/world/`) | ⏸ | Terrain, sky, water, atmosphere, zones written; vegetation/areas not done; `world_terrain.gd` had a parse error when paused |
| Combat & enemy AI (`scripts/enemies/`) | ⏸ | Base AI, wolf, humanoids, adventurers, ogre, spawner written; behaviour tests not run |
| UI & audio (`scripts/ui/`, `scripts/audio/`) | ⏸ | Audio synth done; HUD/menus partly written; `ui_root` not finished |
| Integration & QA | ⬜ | After the paused agents resume |

## Backlog (next up, in order)
1. ⬜ Hand-check player movement feel in the playground (speeds, jump, slopes, stairs, dodge, camera collision) and tune.
2. ⬜ Minimal HUD for player-only build (health/stamina/energy) if needed for testing.
3. ⬜ Resume World agent: fix `world_terrain.gd` parse error, finish vegetation + areas.
4. ⬜ Resume Combat agent: one melee enemy end-to-end first (wolf), then others; fair-combat tests.
5. ⬜ Resume UI agent: finish `ui_root`, pause/settings/character panels, title screen.
6. ⬜ Integration & QA pass: full quest chain, save/load, boss, evolution in the real world.
7. ⬜ Push to GitHub (`origin` = AnomitroMunshi/GoblinAscendant) once a verified build exists.

## Known issues / follow-ups
- Goblin is small on screen in the default camera view (~20% of screen height); consider a closer default distance.
- Lock-on reticle spin is overridden by billboard mode (it still pulses).
- Swing arc appears in full at the start of the active window instead of sweeping.
- Quests: kill counters aren't saved; the first objective completes immediately on spawn.
- Physics interpolation is ON project-wide: teleports must call `reset_physics_interpolation()`.

## Decisions log
- PC (mouse + keyboard) only for now; mobile architecture hooks kept inert (see ARCHITECTURE.md › Platforms).
- Story later: minimal data-driven placeholder quests.
- Art: stylized fantasy, anime-inspired characters, soft gradients, restrained outlines; cel shading later.
- All assets procedural (see docs/ASSETS.md).

## Progress log
### 2026-10-30
- Player-only build verified: headless run clean; windowed smoke test (`tests/playground_screens.tscn`) spawns, runs, jumps and heavy-attacks with no errors. Committed.
- User asked for a player-only build with basic movement. Paused World, Combat and UI agents. Added the movement playground and a `PLAYER_ONLY` switch in main; Esc releases the mouse and a click recaptures it (no UI yet).
- Player & Camera agent finished: full controller, camera with collision, lock-on, goblin model with expressions, evolution visuals; 42/42 tests. Enabled physics interpolation.
- Progression & Quest agent finished: XP/levels/upgrades, 3 abilities, evolution, data-driven 5-quest chain, Nib, quest props; 136/136 tests.
- User direction: enemy fighting styles, fair-combat rules (2 attackers max, LOS), local faction fights; Hitbox got a line-of-sight check; adventurers hostile to monsters.
- Lead foundation built and committed; GitHub repo set as `origin` (not pushed yet).
