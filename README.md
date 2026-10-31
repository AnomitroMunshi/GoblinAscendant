# Goblin Ascendant — Chapter 1 (first draft)

A third-person open-world action RPG built in **Godot 4.7.2**. You play a small, capable goblin who
protects his friends and grows toward becoming the Demon Emperor. Chapter 1 takes place in a dense
forest valley. It ends when you defeat the ogre, claim a cave as home and evolve from Goblin to
Hobgoblin.

Everything is built in GDScript. Characters, effects, audio and music are generated in code. The
only imported assets are CC0 terrain/bark textures from ambientCG (see `docs/ASSETS_WORLD.md`).

## Run

1. Install **Godot 4.7.2 (standard, not .NET)**.
2. Open the editor, choose **Import**, select `project.godot`, then press **F5**.

Or from a terminal:

```
Godot_v4.7.2-stable_win64.exe --path "D:\Goblin Ascendant"
```

| Launch option | What it does |
|---|---|
| *(default)* | Full game, starting at the title screen (New Game / Continue) |
| `-- --playground` | Player-only movement and combat test level (no world, enemies or UI) |

## Controls (keyboard and mouse)

| Input | Action |
|---|---|
| WASD | Move (camera-relative) |
| Mouse | Camera |
| Shift | Sprint |
| Space | Jump |
| Left mouse | Light attack combo |
| Right mouse | Heavy attack |
| Ctrl | Dodge (brief invulnerability) |
| Q (hold) | Block / guard |
| H | Draw or holster the weapon (holstered: punches and kick) |
| E | Interact |
| R | Lock on to a target |
| Mouse wheel (while locked) | Switch target |
| 1 / 2 / 3 | Essence abilities (Wolf Dash, Stone Guard, Flame Burst) |
| Tab | Character panel (stats, upgrades, abilities, quest log) |
| C / middle mouse | Reset camera |
| Esc | Pause menu (settings, save, load) |
| F5 / F9 | Quick save / quick load |

A controller is also mapped (left stick, right stick camera, face buttons).

## Chapter 1

1. **A Small Beginning**: walk to the glade's edge and read the signpost.
2. **A Friend in Trouble**: defeat the goblin raiders guarding the injured Nib, then help him up.
3. **A Place to Belong**: find the cave in the north-east and gather supplies.
4. **The Ogre's Claim**: defeat the ogre in its clearing.
5. **Something Greater**: claim the cave as home, reach level 5 and evolve into a Hobgoblin.

Optional content:
- the alpha wolf (Wolf Dash essence), the ruins shrine (Stone Guard) and the raider captain (Flame Burst);
- 12 landmarks and 4 secret spots;
- Clearwater Spring, which restores health.

Neutral adventurers never attack unless provoked.

## Tests

```
bash tools/run_tests.sh            # all headless suites in parallel (~1–3 min)
bash tools/run_tests.sh player qa  # a subset
```

The suites are player, combat, world, audio, progression, UI/HUD, and a full Chapter 1 playthrough
(`qa_chapter1`) that covers save/load, the boss and evolution. Windowed checks:
`tests/full_walk.tscn` (area walk and fps) and `tests/qa_title_flow.tscn`.

## Docs

- `docs/BACKLOG.md`: status, backlog and progress log.
- `docs/ARCHITECTURE.md`: systems, ownership and contracts.
- `docs/QA_REPORT.md`: latest QA results.
- `docs/STORY_CHAPTER_1.md`: story draft. Its additions are not implemented yet.
- `docs/COMBAT_CHOREOGRAPHY.md`: combat motion brief.

## Known limitations (first draft)

- **Story draft not implemented:** the Battered Short Sword pickup, wolf carcasses, wildlife scenes and the search party.
- **Characters:** enemy/NPC models are functional but not yet the planned realistic remodel. The Hobgoblin redesign is deferred.
- **Not in yet:** equipment and inventory equipping, swimming and climbing.
- **Feel:** combat feel and a hand-played boss fight still need human playtesting. Automated tests cover mechanics, not feel.
- **Platform:** PC only for now; the architecture is ready for a later mobile port.
