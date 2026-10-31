# QA Report — Chapter 1 integrated build (2026-10-31)

Integration & QA agent. Engine: Godot 4.7.2, Forward+. Hardware: RX 6600 XT, 1600×900 windowed.
Scope: the quest chain as implemented in `scripts/quests/quest_data.gd`:
A Small Beginning → A Friend in Trouble → A Place to Belong → The Ogre's Claim → Something Greater,
ending in the Goblin → Hobgoblin evolution. The additions drafted in `docs/STORY_CHAPTER_1.md` are not
implemented, so they were not tested (see "Pending story content").

Note: the World agent was working in parallel (denser forest, `Layers.TREES`). All results
below come from the working tree that included its in-progress changes.

## Test matrix (verified by running)
| Suite | Mode | Result |
|---|---|---|
| `tests/player_test.tscn` | headless (`tools/run_tests.sh`) | 79/79 PASS |
| `tests/combat_test.tscn` | headless, `--fixed-fps 60` | 93/93 PASS |
| `tests/world_check.tscn` | headless `-- --full` | 42 checks ok, 0 failed |
| `tests/ui_audio_test.tscn` | headless | PASS |
| `tests/progression_tests.tscn` | headless | 136/136 PASS |
| `tests/ui_hud_test.tscn` | headless | PASS (45 checks) |
| **`tests/qa_chapter1.tscn`** (new) | headless `-- --full` (real time in the runner; also `--fixed-fps 60`, ~30 s) | **196/196 PASS** |
| **`tests/qa_chapter1.tscn`** (new) | **windowed** `-- --full` | **196/196 PASS**, avg 112 fps |
| **`tests/qa_title_flow.tscn`** (new) | **windowed** `-- --full` | **11/11 PASS**, avg 77 fps |
| `tests/full_walk.tscn` | windowed `-- --full` | 11/11 areas walkable and grounded |
| Full game boot | headless `--quit-after 600 -- --full` | clean, **0 ObjectDB leaks** (was 18) |
| Player-only boot | headless | clean apart from 2–4 leaked audio instances (see issues) |

Run everything: `bash tools/run_tests.sh` (about 2.5 min wall time; qa_chapter1 runs in the save lane).

## Playthrough driven by `tests/qa_chapter1` (real World, Player, Actors, QuestWorld, UI)
Boots `scenes/main.tscn` with `GameState.show_title = false`. It fails loudly if `--full` is
missing or any part (World/Player/Actors/QuestWorld/UI) is absent. Teleports use
`GameState.ground_point` + `reset_physics_interpolation()`. Props are used through the player's
real interaction detector + `Interactable.interact(player)`. Kills go through `take_damage(DamageInfo)`
with the player as source. Zones are the real TriggerZones.

| # | Step | Outcome |
|---|---|---|
| 1 | Boot: parts built, spawn on ground at the glade | PASS. "Look around the glade" completes on spawn (design item, below) |
| 2 | Signpost → quest 1 done; objective text, HUD text and compass marker checked at every step | PASS |
| 3 | Light attack (real `attack_light` input) against a real pack wolf | PASS: exactly one damage event per swing, HP drops |
| 4 | Kill the alpha wolf → essence orb spawns → not absorbed from range → touch it | PASS: `wolf_dash` unlocked and auto-equipped in slot 1 |
| 5 | Rescue site zone → checkpoint `woods_edge`, 3 real guards, Nib refuses while guarded | PASS |
| 6 | Kill 1 guard → (1/3) → **save → Continue** | PASS: all 3 guards respawn, counter restarts at (0/3), consistent |
| 7 | Kill 3 guards → help Nib → `friend_rescued`, quest 2 done | PASS. Nib walks off and relocates home (talkable) |
| 8 | Lethal damage → death screen, save refused while dead → respawn | PASS: full HP at checkpoint `woods_edge`, on floor |
| 9 | Stand beside idle adventurers for 15 s | PASS: no damage, no grudge, not lock targets |
| 10 | Hit one adventurer (third one moved 24 m away) | PASS: only it emits `actor_provoked`; ally in 12 m assists; far ally and every other actor stay calm; attacked one retaliates |
| 11 | Leave (45 m) for 24 s; re-provoke and leave beyond the 70 m sleep range for 30 s | PASS: grudges calm in both cases |
| 12 | Discover all remaining landmarks via real zones; Stone Guard shrine | PASS: `stone_guard` unlocked, shrine spent |
| 13 | Cave + 3 supplies (marker always points at nearest remaining supply) | PASS: quest 3 done |
| 14 | Ogre: enter arena → engage + boss bar; 40 % damage; leave arena | PASS: disengage, **full HP reset** |
| 15 | Re-engage, kill ogre | PASS: `boss_defeated` event + flag, quest 4 done, checkpoint `clearing_edge` |
| 16 | **Mid-chain save → Continue** (providers reset, `pending_load`, re-instantiated main.tscn, mirroring main.gd) | PASS: quests, flags, level/xp, abilities + slots, inventory, discoveries and checkpoint restored. Boss, rescue guards and alpha not respawned. Orb and supplies gone. Nib at home. Spawn at the saved spot on valid dry ground |
| 17 | Camera in the real cave: arm pointed into the nearest wall | PASS: arm 1.13 of 3.91 m; full 3.91 m in the open glade |
| 18 | Claim hearth → `home_claimed`, fire lit, checkpoint `home` | PASS |
| 19 | Level 5 | **Reached by real content, no XP top-up** (the test kills more than the minimum and visits every landmark) |
| 20 | Evolve at the hearth | PASS: stage hobgoblin, model `stage == hobgoblin`, scale 1.3, `shockwave_slam`, `chapter_completed` fired once, every quest complete, no objective left; survives another Continue |
| 21 | Corrupted JSON save / malformed field types / missing save | PASS: Continue hidden, `load_game()` refuses, fresh game; bad fields fall back to defaults; a quest saved without its prerequisites is dropped; an off-map position is ignored |
| 22 | Title screen up for 3 s over an existing save | PASS (after fix #1): save file byte-identical |

`tests/qa_title_flow` (windowed, real scene reloads): title on boot → **New Game** (confirm prompt when a
save exists) → gameplay → save → quit to title → **Continue** restores flag + XP.
Screenshots: `tests/screens/qa/title_1_title.png`, `title_2_new_game.png`, `title_3_continue.png`,
plus the windowed playthrough shots `tests/screens/qa/01_glade.png` … `08_title.png`.

## Bugs found and fixed
1. **Booting to the title screen overwrote the player's save** (severe, data loss).
   - Repro: have a mid-game save, launch the game, wait about 1 s on the title. The save is replaced by a fresh level-1 game. Seen live: the real `savegame.json` timestamp changed after a plain `--full` boot.
   - Root cause: a fresh world runs behind the title. The player spawns inside the glade zone, the first quest step completes, and `SaveManager.request_autosave()` fires. Quitting to the title within 0.5 s of an autosave request did the same.
   - Fix: `request_autosave()` does nothing while `GameState.show_title` is set. Manual saves were already guarded. File: `scripts/core/save_manager.gd`.
   - Regression check: QA step 22. It fails with the fix reverted (verified).
2. **ObjectDB leak warnings at exit** (18 instances in the full game).
   - Root cause: audio streams/playbacks were still held by the AudioServer because Audio's players were playing at teardown.
   - Fix: `Audio._exit_tree()` stops every player and clears streams. File: `scripts/audio/audio.gd`.
   - Full game now exits with 0 leaks. The player-only build still shows 2–4 (below).
3. **Missing `marsh_loop` sound.** The World agent's marsh asked for it and silently got nothing.
   - Fix: added a synthesized loop (murky low air, slow mud bubbles, a few distant croaks), registered in `AudioSynth.LOOPS`, `Audio.AMBIENT_IDS` (Ambience bus) and the background generation list.
   - Files: `scripts/audio/audio_synth.gd`, `scripts/audio/audio.gd`. ui_audio_test passes.
4. **`Palette.vertex_color_mat()` treated sRGB vertex colours as linear.**
   - Fix: set `vertex_color_is_srgb = true`. File: `scripts/core/palette.gd`.
   - No visual change today: the function currently has no callers. Checked with grep.
5. **`tests/full_walk` overwrote the real save** (its autosaves). It now backs up and restores `user://savegame.json`.

## Checked, not bugs
- **Quest kill counters not saved:** working as intended. The guards respawn on load unless `rescue_guards_defeated` / `friend_rescued` is set, so a session-only counter restarting at (0/3) matches the 3 live guards (QA step 6). Saving the counter would let the step complete with guards still standing.
- **Neutral grudges past the 70 m sleep range:** they calm down correctly (QA step 11).

## Remaining known issues (by severity)
1. **Medium — marsh frame rate.** About 20 fps at the Sunken Marsh in both windowed walks, against 79–150 fps everywhere else (high quality, 1600×900). Probably the marsh FogVolume / volumetrics, but this was inspected only. World-owned: reported to the lead, not touched.
2. **Low (design) — "Look around the glade" completes on spawn.** The spawn point is inside the glade zone, so the player's first visible objective is "Read the signpost". The fix is a data/design choice (move the step target, or start outside the zone), not a bug fix. Since fix #1 it no longer causes saves behind the title.
3. **Low — player-only build leaks 2–4 audio instances at exit.** Source not found. The full game is clean.
4. **Cosmetic** — "Interpolated Camera3D triggered from outside physics process" warning when tests teleport the player (also in player_test). `JSON parse failed` engine errors are expected in the corrupted-save test.
5. Existing known items in BACKLOG remain: goblin small on screen, reticle spin, swing-arc sweep.

## Frame rate (windowed, 1600×900, high quality, RX 6600 XT)
- `full_walk` run 2 (clean): glade 102, woods 81, rescue 86, ruins 108, overlook 108, spring 79, camp 89, outpost 102, ogre 151, cave 79, **marsh 22**.
- `full_walk` run 1: overlook through marsh measured 13–20 fps. That overlapped another Godot process (World agent / my windowed QA) starting up, so treat it as contention; run 2 had no overlap until the end.
- `qa_chapter1` windowed: 112 fps average (minimum 1 fps on teleport frames).
- `qa_title_flow`: 77 fps average, including scene reloads.

## Verified by running vs inspected only
- **Running:** everything in the test matrix and playthrough table. Windowed: qa_chapter1, qa_title_flow, full_walk, and screenshots of the title, New Game and Continue.
- **Inspected only:**
  - the marsh fps cause;
  - the root cause of the player-only audio leak;
  - the visual effect of the `vertex_color_is_srgb` change (no callers, so nothing to see);
  - that the new `marsh_loop` sounds right. It generates and loops, but nobody listened to it.
  - Combat feel, the boss fight played by hand, and ability use in real fights (Wolf Dash, Stone Guard, Flame Burst, Shockwave Slam) are not covered by the QA playthrough. The playthrough unlocks them; the existing unit suites cover their mechanics.

## Pending story content (not implemented, not tested)
From `docs/STORY_CHAPTER_1.md`:
- Battered Short Sword pickup with equip/stow/save;
- two one-time wolf-carcass fang searches;
- the rabbit and deer wildlife scenes;
- the adventurer search party with its cover/avoidance route;
- hearth-completion ending with evolution only foreshadowed.

## Recommendation
The integrated full game is **ready to become the default launch** (`main.gd` `PLAYER_ONLY := false`):
- the whole chain plays to the Hobgoblin evolution;
- save, Continue, title and New Game work;
- no script errors;
- frame rate is fine except at the marsh.

Do it after the World agent's current density pass lands and `tools/run_tests.sh` plus a windowed `full_walk` are re-run. Give the marsh frame rate to the World agent as the one performance follow-up.
