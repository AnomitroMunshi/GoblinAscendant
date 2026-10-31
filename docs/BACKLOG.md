# Goblin Ascendant — Backlog & Progress

Living file, updated by the lead as work lands. Newest log entries on top.
Status keys: ✅ done & verified · 🟡 partial / unverified · ⏸ paused · ⬜ not started

## Current focus (2026-10-31)
Chapter 1 narrative draft and implementation handoff: [A Fire of Our Own](STORY_CHAPTER_1.md). Includes scenes, dialogue, environmental clues and Claude's implementation checklist. Story additions are not implemented. The draft proposes hearth completion with evolution foreshadowed; current quest code still requires level 5 and Hobgoblin evolution until that change is integrated.
User's added journey requirements: rabbit alert/flee encounter, deer crossing, and an adventurer search party with a working cover/avoidance route before Nib's rescue. Detailed in the story draft; implementation pending. These specific wildlife scenes extend the earlier scope cut; the larger wildlife library remains deferred. Preserve neutral adventurer faction rules and handle discovery without automatic lethal combat.
Further user direction: two wolves killed by the adventurers can be searched for loot; a discarded rough sword can also be taken. Story specifies two one-time fang searches and an optional Battered Short Sword with real equip/stow, sword moveset and save support. Implementation pending; no player kill credit for scavenged carcasses, and the starting knife remains owned.

**WORLD FIRST (user, 2026-10-31):** only the World agent is running. Choreography and Character Art are paused until the world is done and reviewed.
Earlier plan, still the overall goal: **finish Chapter 1** (user request): World, Combat & Enemy AI, UI & Audio, plus
the new Combat Choreography agent (data-driven weapon movesets, previews, enemy motion spec).
Integration & QA runs after them; then the lead flips the default build to the full game.
- Default launch is still the movement playground. Run the full game with `godot --path . -- --full`.
- Known integration blocker at resume: `scripts/world/world_terrain.gd` parse error (World agent fixing).

## Status by area
| Area | Status | Notes |
|---|---|---|
| Lead foundation (autoloads, input map, damage/faction/interaction/save interfaces, world layout) | ✅ | Runs headless clean |
| Player & camera (`scripts/player/`) | ✅ | 42/42 headless tests (agent); now being hand-checked in the playground |
| Movement playground (`scripts/main/movement_playground.gd`) | ✅ | Slopes 15–55°, stairs, jump course, camera corridor/tunnel, pillars, pool. Verified windowed: spawn, run 5.2 m/s, jump, heavy attack; screenshots in `tests/screens/` |
| Progression, abilities, quests (`scripts/progression|abilities|quests/`) | 🟡 | 136/136 headless tests (agent); not used in player-only build |
| World & environment (`scripts/world/`, `shaders/world/`) | ✅ | Realistic valley with CC0 textures, 7 tree species, all areas, still waters, spring, marsh, castle backdrop; world_check pass; lead-verified walk of 11 areas at 57–170 fps |
| Combat & enemy AI (`scripts/enemies/`) | ✅ | All 7 types, 24 spawns, fair-combat rules; 93/93 headless tests; screenshots reviewed by agent. Awaiting choreography spec + live-play feel check |
| UI & audio (`scripts/ui/`, `scripts/audio/`) | ✅ | HUD, compass, ability slots, boss/lock bars, toasts, pause/settings/controls/character/title; synthesized SFX/loops/music; 45/45 HUD checks + audio test; screenshots reviewed by agent and lead |
| Integration & QA | ⬜ | After the paused agents resume |

## Backlog (next up, in order)
1. ⬜ Hand-check player movement feel in the playground (speeds, jump, slopes, stairs, dodge, camera collision) and tune.
2. ⬜ Minimal HUD for player-only build (health/stamina/energy) if needed for testing.
3. ⬜ Resume World agent: fix `world_terrain.gd` parse error, finish vegetation + areas.
4. ⬜ Resume Combat agent: one melee enemy end-to-end first (wolf), then others; fair-combat tests.
5. ⬜ Resume UI agent: finish `ui_root`, pause/settings/character panels, title screen.
6. ⬜ Integration & QA pass: full quest chain, save/load, boss, evolution in the real world.
7. ⬜ Push to GitHub (`origin` = AnomitroMunshi/GoblinAscendant) once a verified build exists.

## Character, equipment and mature tone (2026-10-30)
User direction; implementation pending unless explicitly marked otherwise. These additions do not resume the paused areas.

- ⬜ Rebuild the starting Goblin in Godot: friendly, capable, distinctive face; smaller seated amber eyes, defined cheeks/jaw, balanced adult proportions. Avoid both baby-faced mascot and excessively rough brute.
- ✅ Starting appearance implemented: opaque torn waist cloth, bare chest and feet, and a rough chipped knife with a wrapped handle. No starting tunic, leather belt, boots, armour or proper sword. Face/proportions revised; visual acceptance still pending.
- ⬜ Make equipment separate from the body and evolution: find/earn a rope sash or belt, pouch, wraps, worn tunic, boots, proper dagger, then short sword. Acquisition order beyond the starting loadout is proposed tuning, not a fixed quest requirement.
- ⬜ Add inventory/equip definitions and visible equipment slots; save owned/equipped items. Weapons change reach, damage and animation; synchronize hitboxes with actual weapon reach. No automatic wardrobe upgrade on evolution.
- ⬜ Give Hobgoblin a distinct taller, muscular build: longer legs, broader shoulders/chest, stronger arms and a more defined face, retaining identity. Target reference heights: Goblin ~1.1 m, Hobgoblin ~1.5 m; tune collider, camera, interaction and attack reach accordingly.
- References: `docs/concepts/goblin-player-v2.png` (face/proportions; its clothing is later equipment), `docs/concepts/hobgoblin-player-v1.png` (body; armour is optional equipment). First Goblin concept v1 was deleted at user request. A torn-cloth/knife reference is still needed.
- ⬜ Mature fantasy action/survival tone, not aimed at children: dangerous fights, visible wounds/blood feedback, grounded consequences and restrained presentation. Keep the protagonist compassionate; mature tone does not change the faction/non-aggression rules. Exact gore level and death penalties remain undecided.

## Skills and abilities — proposed Chapter 1 progression
The following distinguishes current ability code from new design work. None of these systems is newly implemented by this backlog update.

| Type | Skill / ability | Acquisition and purpose | State |
|---|---|---|---|
| Basic combat | Rough Knife | Start with short-range cuts/stabs and a committed heavy thrust; low reach, stamina-based, no magical starter attack | ⬜ Adapt existing attacks to starting weapon |
| Basic movement | Dodge / sprint / jump | Available from start; survival relies on spacing and stamina | Existing controller; tune with new body |
| Weapon defence | Guard | Knife guard is weak; proper weapons improve defence. Do not assume the existing 80% block reduction suits a rough knife | ⬜ Weapon-based tuning |
| Learned skill | Quickstep | Survive early encounters / complete dodge training; improve recovery modestly | ⬜ Proposed |
| Learned skill | Counter Thrust | Successfully guard timed enemy strikes; unlock a brief punish window, not an automatic hit | ⬜ Proposed; requires timing events |
| Learned skill | Field Dressing | Find supplies and learn treatment; consumable bandage with a vulnerable use animation | ⬜ Proposed |
| Essence ability | Wolf Dash | Absorb alpha-wolf essence; short invulnerable burst for approach or escape | Code exists; integrate/test in real encounters |
| Essence ability | Stone Guard | Ruins shrine; temporary damage reduction | Code exists; integrate/test |
| Essence ability | Flame Burst | Raider-captain essence; short-range fire attack costing energy | Code exists; integrate/test |
| Evolution passive | Shockwave Slam | Hobgoblin evolution; heavy attacks add an area shockwave | Unlock/controller hooks exist; validate end-to-end |

- ⬜ Separate learned skills, essence abilities, equipment and evolution in progression data/UI. Retain three equipped essence slots and current energy/cooldown rules.
- ⬜ Use mastery milestones rather than rewarding repetitive button presses. Add definitions for prerequisites, thresholds, unlock effects and descriptions; persist progress and prevent duplicate rewards.
- Later scope: stealth/backstab, hunting/tracking, crafting and additional evolution abilities; do not make these prerequisites for the first playable encounter.

## Achievements and earned titles — proposed, not implemented
Achievements record milestones; titles are earned identity rewards. Unlocking a title does not equip it automatically. Initially titles are cosmetic, with no stacking combat bonuses.

| Achievement | Goal | Earned title / reward |
|---|---|---|
| First Blood | Player kills the first hostile wolf | Wolf Slayer |
| Hunter of the Woods | Player kills 10 distinct wolves | Wolf Hunter |
| Against the Alpha | Player defeats the unique alpha wolf | Alpha Breaker; essence pickup separately grants Wolf Dash |
| A Friend Worth Fighting For | Rescue Nib | Friendshield |
| Steady Hands | Successfully guard 10 distinct enemy attack activations | Steady Hand |
| Untouched | Defeat an engaged hostile enemy without taking damage during that encounter | Untouched |
| Breaking the Claim | Defeat the ogre | Ogrebreaker |
| A Place of Our Own | Claim the cave home | Hearthkeeper |
| Something Greater | Evolve into a Hobgoblin | Ascendant |

- ⬜ Create data-driven achievement/title definitions with stable IDs, descriptions, conditions, counters, unlocked IDs and one equipped title.
- ⬜ Record persistent kill/mastery counters separately from the existing quest session counters. Credit combat achievements to the player, including player-owned abilities; NPC-versus-NPC kills must not count.
- ⬜ Deduplicate kill credit per enemy life and guard credit per attack activation; loading must never regrant unlocks/rewards. Unique boss/quest achievements reconcile with existing saved completion flags.
- ⬜ Track encounter participation and damage for Untouched; environmental damage invalidates the attempt. Avoid unlocking it for an uninvolved NPC kill.
- ⬜ Save/load counters, unlocks and selected title, with defaults for older saves; new game resets run progression. First version is per save, not platform-wide.
- ⬜ Add unobtrusive achievement/title notifications and a character-panel list with progress and title selection. No pause or forced modal during combat.
- ⬜ Verify thresholds, player attribution, duplicate events, save/load, new game and title persistence. No achievements encouraging attacks on peaceful NPCs.

Suggested delivery order: starting Goblin/body and knife → one wolf encounter → First Blood/Wolf Slayer plus save support → equipment pickup/equip → remaining achievements and learned skills → distinct Hobgoblin evolution.

## Stage-specific carried loadouts (2026-10-31)
Confirmed by user; implementation pending. These limits supersede the earlier starting-Goblin two-handed-axe proposal. Slots describe carried combat equipment, not simultaneous attacks or starting ownership.

| Stage | Main loadout (one choice at a time) | Additional carried weapons |
|---|---|---|
| Goblin | One one-handed main weapon: blunt, pointed or edged | One knife and one ranged weapon: sling |
| Hobgoblin | Shield + one-handed axe; shield + one-handed sword; OR one two-handed weapon: spear, two-handed sword, two-handed hammer, **two-handed axe** | One knife and one sling |

- ⬜ Define blunt/point/edge as main-weapon categories and explicit handedness per item. Goblin has no shield or two-handed loadout in the currently specified design.
- ⬜ Hobgoblin's shield occupies the off-hand; a two-handed weapon occupies both hands and excludes the shield. Carry only one selected main loadout, not all listed alternatives together.
- ⬜ Knife and sling are separate carried slots. Switching readies one weapon and stows the previous one; carrying the knife does not imply dual wielding. Sling use stows main weapon/shield as needed by its animation.
- ⬜ Start with only the rough knife and torn cloth; empty main/ranged slots are valid. Unlocking a slot or evolving does not grant its equipment. Sling/ammunition acquisition and tuning remain to be designed.
- ⬜ Validate stage restrictions, slot limits and hand occupancy in equip UI, combat state and save restoration. Add matching weapon switch/stow visuals and per-loadout movesets, including shield guard and two-handed grips.
- ⬜ Reconcile Oathcleaver with these rules before implementation: proposed solution is a Goblin-compatible one-handed axe that gains a distinct Hobgoblin two-handed form. Exact item/form design remains open; the Goblin must not use a two-handed axe under the confirmed loadout rules.

## Casting with equipped weapons (2026-10-31)
User confirmed: skills, especially magic, can be used with weapons in hand. Implementation pending.

- ⬜ Do not require unequipping or stowing a weapon merely to cast magic. Support Goblin main weapon/knife/sling and every allowed Hobgoblin loadout, including shield pairings and two-handed weapons.
- ⬜ Add cast-pose variants per grip: free-hand gesture when available; subtle weapon/shield gesture or body-based cast when both hands are occupied. A two-handed wielder may briefly release/regrip one hand if the animation needs it; keep the weapon held and avoid clipping or floating equipment.
- ⬜ Choose effect origins per skill, not universally from the hand: Flame Burst from mouth/chest, Stone Guard around the body, Wolf Dash from movement; other spells may use palm or weapon tip. Prevent self-collision and retain wall/line-of-sight checks and faction rules.
- ⬜ Separate compatible equipment from action timing. Holding equipment permits casting; attacks, guard, dodge and casts still follow explicit busy/cancel rules. Do not silently enable simultaneous attack damage and spell damage or casting while dead/staggered. Define any spell-combo cancel windows as authored exceptions.
- ⬜ Retain energy costs, cooldowns and three essence slots across loadouts. Weapon-specific skills such as Rift Cleave still require their matching weapon; generic magic does not. Equip changes must not reset cooldowns or grant spell ownership.
- ⬜ Validate casting origins/poses and grip restoration with knife, main weapon, sling, shield+sword/axe and every two-handed weapon; test interruption, death, switching and insufficient-energy/cooldown failure paths.

## Weapon-specific movesets (2026-10-31)
User confirmed: each weapon must have a separate moveset, not the same animation with a different mesh. Planned work; only the recent off-hand correction is implemented.

| Weapon | Light combo | Heavy attack | Handling |
|---|---|---|---|
| Rough knife / dagger | Diagonal cut → backhand cut → quick forward stab | Committed lunging thrust | One-handed; free hand guards/balances; short reach and quick recovery |
| Short sword | Diagonal cut → returning horizontal cut → finishing thrust | Committed descending cut | One-handed; wider arcs and more reach than knife |
| One-handed axe | Diagonal cleave → returning cleave → downward chop | Committed one-handed cleave | Goblin main edged weapon; Hobgoblin may pair an axe with a shield |
| Two-handed axe | Diagonal cleave → returning cleave → downward chop | Two-handed overhead strike | Hobgoblin only; no shield; slower recovery, higher stamina cost, stronger stagger and authored two-hand grip |

- ⬜ Add distinct blunt-weapon, pointed-weapon, sling, shield+sword, shield+axe, spear, two-handed sword and two-handed hammer movesets. Specific combo tuning remains to be authored; do not reuse knife poses for every weapon.

- ⬜ Add weapon/moveset definitions: mesh/grip, light-combo entries, heavy attack, timing, stamina costs, damage/stagger/knockback, lunge, guard effectiveness, animation poses, hitbox offsets/sizes and trails.
- ⬜ Replace the single hard-coded Player ATTACKS/model ATTACK_KEYS lookup with equipped-weapon data. Keep input actions consistent; resolve the weapon/moveset at attack start so an equip change cannot alter an attack halfway through.
- ⬜ Implement knife third-hit stab and heavy thrust first; current corrected knife animations still use descending strikes. Stabs need a short directional trail rather than a broad slash arc.
- ⬜ Animate both hands only when required by grip/attack. Off-hand may balance or guard during one-handed attacks, but must not mimic gripping an invisible second handle. Add authored two-hand placement for the axe; no new manual rigging workflow required.
- ⬜ Give each weapon distinct guard pose/effectiveness, attack reach, recovery and audio/VFX. Dodge remains a shared movement action; weapon pose must blend into and out of it cleanly.
- ⬜ Refuse or defer equipment changes while attacking; reset combo on an accepted switch. Save equipped weapon and restore its moveset without granting unowned equipment.
- ⬜ Verify per-weapon combo order, active windows, single-hit credit, wall checks, stamina, reach, off-hand placement and transitions. Test switching, death/respawn and save/load with each supported weapon.

## Legendary signature weapon — Oathcleaver (2026-10-30)
User requested a legendary axe found in a cave, becoming the protagonist's main weapon with a unique skill. The name and tuning below are proposed; implementation pending.

- ⬜ **Oathcleaver**, an ancient single-bladed bearded axe: dark steel crescent edge, worn wrapped haft, one restrained amber rune. Distinct silhouette, procedural mesh construction. Handedness/form must follow the stage-specific loadouts above; original two-handed Goblin design is superseded. No oversized decorative spikes.
- ⬜ Place it in a small relic chamber branching from the cave near the ogre clearing. Discover the chamber during shelter scouting, before defeating the ogre; keep it reachable without entering the boss encounter or first claiming home. Exact anchor/geometry still to be authored in WorldLayout/world content.
- ⬜ Short data-driven quest **An Edge in the Dark**: discover an old axe embedded in a stone plinth → activate three nearby worn rune markers in the chamber → return and claim the axe. Keep this a brief exploration beat without a new boss, extensive dialogue or a level gate.
- ⬜ Axe is intended to be usable on acquisition, dormant in power, with better stagger/reach than the rough knife, higher stamina cost and clear recovery. Resolve its Goblin-compatible one-handed form before implementing this acquisition path. Knife remains a faster alternate weapon. Tune damage against the first ogre rather than trivializing it.
- ⬜ Weapon skill **Rift Cleave**: a planted overhead strike sends a short, narrow ground fissure forward. Initial tuning: 20 energy, 12 s cooldown, ~4 m reach. Clear wind-up; interruptible before release; once per target per cast; respect walls and faction rules. Targeted skill does not auto-acquire peaceful actors.
- ⬜ Weapon skill is available only while Oathcleaver is equipped, through a dedicated weapon-skill action separate from the three essence slots. Define keyboard/controller bindings and HUD feedback; avoid conflicting with existing block/heavy/ability inputs. Reuse the ability resource/cooldown infrastructure where practical.
- ⬜ On Hobgoblin evolution, awaken the rune and grant a modest Rift Cleave stagger/reach upgrade with a stronger wielding animation. Keep the same recognizable axe; no automatic armour/clothing grants. Rebalance interaction with Shockwave Slam so one cast does not double-trigger overlapping area damage.
- ⬜ Add achievement **An Edge in the Dark** and earned cosmetic title **Oathbearer** on first acquisition. Guaranteed unique pickup, not a random drop; persist ownership, quest state, awakened state and cooldown handling across death/load. No duplicate pickup or unlock reward; item is not consumed, sold or permanently lost on death in Chapter 1.
- ⬜ Implement the axe mesh, equip visibility, hand placement, dedicated attack animations, weapon-sized hitboxes, skill effect and UI description; test acquisition before boss, unequip restrictions, LOS, hit deduplication, save/load and evolution.

Revised Chapter 1 weapon path: rough knife → optional ordinary weapon finds → Oathcleaver in the cave → use it against the ogre → claim home and evolve → awaken its potential. The acquisition beat must fit the short chapter and not require building the full crafting system.

## Known issues / follow-ups
- Goblin is small on screen in the default camera view (~20% of screen height); consider a closer default distance.
- Lock-on reticle spin is overridden by billboard mode (it still pulses).
- Swing arc appears in full at the start of the active window instead of sweeping.
- Quests: kill counters aren't saved; the first objective completes immediately on spawn.
- Physics interpolation is ON project-wide: teleports must call `reset_physics_interpolation()`.

## Decisions log
- World must be realistic, not cartoonish (2026-10-31). Believable trees, rocks, terrain and water, PBR materials, natural lighting and colour grading. Small CC0 texture set allowed (ambientCG / Poly Haven), recorded in `docs/ASSETS_WORLD.md`.
- Characters must not be cartoonish (mature game). Concept roster sheets give the design (costume, colours, silhouette); proportions and faces follow the grounded player concepts. Humans ~7–7.5 heads, almond eyes with lids, muted weathered palettes.
- Starting Goblin has torn waist cloth and a rough knife; equipment is earned separately from evolution. Hobgoblin must have distinct taller muscular proportions. Mature tone; avoid childish character styling.
- PC (mouse + keyboard) only for now; mobile architecture hooks kept inert (see ARCHITECTURE.md › Platforms).
- Story later: minimal data-driven placeholder quests.
- Art: stylized fantasy, anime-inspired characters, soft gradients, restrained outlines; cel shading later.
- All assets procedural (see docs/ASSETS.md).

## Progress log
### 2026-10-31
- Lead: WORLD DONE for the first draft. Realism round 2 accepted.
  - Changes: ruined castle on a crag behind layered hazy ridges, clouds, ledged waterfall cliff, natural cave mouth, blended moss, dark reflective water, broken ruins, weathered wood.
  - Lead verified in the integrated full game, windowed, with the player camera (`tests/full_walk.tscn -- --full`): all 11 areas walkable and grounded at 57–170 fps on high (1600×900, RX 6600 XT). Discovery toasts, compass, XP and enemy telegraphs work live.
  - Remaining polish (not blockers): flat cottony clouds, smooth waterfall strip, clumpy near grass, pillowy ledges up close, flat lily pads, missing `marsh_loop` sound.
  - Next: resumed the Choreography and Character Art agents, then QA.
- World agent delivered the realistic valley.
  - Built: textured terrain (10 CC0 ambientCG texture sets, ~38 MB, listed in `docs/ASSETS_WORLD.md`), 7 tree species, physical sky/AgX/fog, still waters, spring heal, marsh, all areas and 4 secrets.
  - Checks: build 2.3 s; `world_check` pass; `--full` clean; ~38–48 fps on high (RX 6600 XT).
  - Lead review: woods, lighting and marsh mood good. Sent back for realism round 2 on 8 points: floating castle and uniform mountain wall, cloudless sky and specks, flat waterfall cliff, cartoon cave arch, painted moss lids, pale icy water, clean lone ruins arch, orange props.
- User: "complete world first". Paused the Combat Choreography and Character Art agents (work saved; resume later). Only the World agent runs now.
  - Player state verified after the pause: player tests 57/57, player-only build clean.
  - Character Art had just verified combat 93/93 and a clean parse; it was mid-investigation of head-mesh holes at small scale.
- All three running agents (World, Choreography, Character Art) were stopped mid-task by the API usage limit (reset 2:50 pm IST). They were resumed at 14:52 from where they stopped; their saved work is kept.
- Lead: first-draft scope cut (user).
  - Weapons: knife, sword, sling and unarmed only, Goblin only. Axe and spear are dropped for now.
  - Characters: only the Chapter 1 cast (enemies, 3 camp adventurers, Nib). Wildlife, the goblin NPC library and the healer are deferred.
  - World & environment is the top priority and gets extra iteration time.
- Lead: added still water to the map contract (user request), now with the World agent.
  - Five waters: glade pond, woods pond, Clearwater Spring (drinkable; heals, 60 s cooldown), Stillmere lake (east), Sunken Marsh (moody swamp, south-west).
  - New landmarks for these and `WorldLayout.distance_to_water()`.
  - All wadeable (≤0.7 m, no swimming yet), with side trails from the main paths.
- Lead: launched the Character Art agent (user request: build the rest of the cast from the concepts, not cartoonish, mature game).
  - The roster sheets (enemies-v1, characters-and-animals, adventurer/goblin/animal turnarounds) define designs only. Proportions and faces follow the grounded `goblin-player-v2` / `hobgoblin-player-v1` style.
  - Scope: shared character kit; remodel all enemies, the 4 adventurers (adds a healer) and Nib; new ambient wildlife (deer, fox, rabbit, boar; new `Wildlife` part in main); goblin NPCs (princess/scout/shaman/guard) as a model library only.
  - The player model and the Hobgoblin redesign stay out of scope.
- UI & Audio agent finished; full game (`-- --full`) now runs headless with no errors.
  - HUD: bars with damage trail, ability slots with cooldowns, objective, compass with landmarks and an objective marker, interaction prompt with keycap, toasts and banners, boss and lock-on bars, damage vignette, death screen.
  - Menus: pause, settings, controls, character panel with upgrades/abilities/inventory/quest log/evolution requirements, and a title screen (`UiRoot.SHOW_TITLE_SCREEN`).
  - Audio: all SFX, loops and music (explore/boss) synthesized on a background thread (~1.9 s total, over the 1.5 s target but non-blocking).
  - Tests: `ui_hud_test` 45/45, `ui_audio_test` pass.
  - Open: compass allocates two small arrays per frame; ObjectDB leak warnings at exit.
- Combat & Enemy AI agent finished. All 7 enemy types and 24 spawns are on the real terrain.
  - Tests: `tests/combat_test.tscn` 93/93, covering one wolf end to end, leash and return, no detection or hits through walls, one hit per activation, max 2 attackers, unstuck recovery, death signals and flags, goblin retreat, human guard and guard break, adventurers staying neutral and defending locally, adventurer-vs-wolf, ogre engage/reset/enrage/defeat, spawner flags.
  - Tuned for a level-1 knife goblin.
  - Open: real-frame-rate feel with the real player; health-bar look in game; camera-shake scale; the camp campfire (World's job).
- Lead: resumed the World, Combat and UI agents and launched the Combat Choreography agent to finish Chapter 1. Added the `-- --full` launch arg (full game) while the default stays player-only. Baseline at resume: player-only runs clean; full mode fails only on the world terrain parse error.
- Created project-local Combat Choreographer definitions for Claude Code (`.claude/agents/combat-choreographer.md`) and Codex (`.codex/agents/combat-choreographer.toml`), plus direct Codex skill `.agents/skills/combat-choreography/`. Shared brief: `docs/COMBAT_CHOREOGRAPHY.md`, covering movesets, grips, boxing guard, footwork, casting, ownership and graphical verification. Agent/skill metadata and references locally validated; runtime Claude discovery untested. No model/settings changes or paused-agent resumption.
- Corrected unarmed stance following user feedback: relaxed arms at idle and ordinary walking swing; Q alone raises a boxing guard with tucked elbows, fists near the jaw and chin down. Releasing Q lowers hands. Rebuilt hand shapes with overlapping palm/knuckles and tucked thumbs instead of detached finger tips; closed jaw underside to prevent low-angle see-through. Unarmed attacks keep the mouth closed, recoil earlier, and kick has a longer extension window plus knee-first retraction. Added front/side inspection scene `tests/unarmed_visual.tscn` and renders in `tests/screens/unarmed_*.png`. Updated kick test wait for its longer recovery; 57/57 player checks passed, including actual hand height in idle/guard/release. Existing interpolation/exit warnings remain.
- Implemented H draw/holster for the starting knife, with visible waist-stowed mesh and unarmed stance. Holstered LMB uses a three-punch moveset; RMB uses a front kick. Added distinct unarmed attack timing/damage/reach, weaker unarmed guard and suppression of blade trails/weapon slam effects. Toggle resets combo and refuses busy/menu/dead states; magic remains usable with either stance. Current holster state is per Player instance (save/load equipment state remains future work). Updated control hints and automated coverage: 53/53 player checks passed; Forward+ holster/punch/kick screenshots captured in `tests/screens/playground_*.png`. Existing interpolation/exit-leak warnings remain.
- Confirmed magic/skills can be cast with weapons held, including shield and two-handed loadouts; planned grip-aware casting poses, skill-specific origins and explicit action/cancel rules.
- Confirmed carried loadouts: Goblin = one blunt/point/edge main weapon + knife + sling. Hobgoblin = shield+axe, shield+sword, or one two-handed spear/sword/hammer/axe, plus knife and sling. Recorded hand/slot restrictions and flagged the older two-handed Goblin Oathcleaver concept for reconciliation.
- Recorded separate weapon movesets as a confirmed requirement: knife cuts/stabs, short-sword combo, and two-handed Oathcleaver cleaves. Data-driven attack selection, correct grips, weapon-specific timing/reach/guard/trails and validation are planned; they are not yet implemented.
- Corrected third light-combo and heavy knife poses: removed legacy two-handed overhead off-arm motion, keeping the free hand in a bent protective/balancing posture. Attack timing/damage/hitboxes unchanged. Godot windowed playground smoke test completed.
- User selected the original broad-faced Goblin concept as the target, with dark hair and a more serious/rough expression. Updated starting model with broader head/jaw, stronger brow, restrained mouth, shorter swept hair, custom nose, shaped upper/lower limbs, blended neck profile and finger shapes. Torn cloth/bare feet/rough knife retained; no starting armour or tunic. Refreshed Godot Forward+ face/full-body/turnaround and playground previews. This is a procedural iteration; visual acceptance remains pending and Hobgoblin redesign is deferred.

### 2026-10-30
- Rebuilt starting Goblin toward the user's supplied dark-haired illustration: curved tapered dark hair locks and fringe, narrower amber-orange eyes, sharper nose/cheeks/jaw and asymmetric mouth. Torn waist cloth, bare feet and rough knife retained; scarf/jewellery/clothing from illustration not added to starting equipment. Actual Forward+ previews refreshed in `tests/screens/goblin_face.png`, `goblin_hero.png`, and `goblin_turnaround.png`. Reference-inspired procedural adaptation, not an exact reproduction; visual acceptance pending. Hobgoblin redesign remains deferred.
- Replaced layered sphere head with a continuous procedural skull/face mesh (brow, sockets, nose, cheeks, jaw), shaped eyelid surfaces and cupped ears. Following feedback, reduced cartoon exaggeration: smaller head/eyes/tusks, subtler brows, muted olive skin and ear tones. Forward+ close-up and full-body renders inspected. Player tests passed 42/42 after head rebuild; subsequent changes were visual proportions/materials only. Current result remains an early procedural model, not concept-quality sculpted art; further face/body refinement is pending visual acceptance.
- Starting Goblin recreated procedurally: smaller head/eyes, shaped bare torso, ragged opaque cloth with cloth tie, bare feet/toes, chipped wrapped knife. Shortened melee hitboxes and trails to suit knife reach. Existing animation/expression API retained. Godot Forward+ renders and movement/jump/heavy smoke test completed; player suite 42/42 passed (existing interpolation and exit-leak warnings remain). Updated `tests/screens/goblin_hero.png` and turnaround. Hobgoblin redesign deferred by user; future equipment progression remains pending.
- Added legendary signature axe Oathcleaver, cave acquisition quest, Rift Cleave weapon skill, awakening on evolution and Oathbearer title as planned work.
- Added character/equipment redesign, proposed skills, mature tone, achievements and selectable titles to the backlog. Reference images are available; these gameplay additions are not yet implemented. Historical model notes below describe the superseded starting outfit.
- Goblin model rebuilt to match `docs/concepts/goblin-player-v1.png`. It now has:
  - faceted low-poly look, olive skin, huge swept ears with brown-pink inner ears;
  - amber eyes with dark rings and highlights, furrowed brows, a triangular nose, a smirk with two lower fangs;
  - sleeveless brown vest with a split tunic skirt, diagonal strap and square steel buckles;
  - leather bracers, chunky cuffed boots and a faceted steel short sword with a wrapped grip.

  The concept has no satchel, so it was dropped. The Hobgoblin keeps the same design, bigger and with armour. The joint, animation and expression API is unchanged: player tests 42/42. Renders are in `tests/screens/goblin_*.png` via `tests/goblin_turnaround.tscn`.
- Player-only build verified: headless run clean; windowed smoke test (`tests/playground_screens.tscn`) spawns, runs, jumps and heavy-attacks with no errors. Committed.
- User asked for a player-only build with basic movement. Paused World, Combat and UI agents. Added the movement playground and a `PLAYER_ONLY` switch in main; Esc releases the mouse and a click recaptures it (no UI yet).
- Player & Camera agent finished: full controller, camera with collision, lock-on, goblin model with expressions, evolution visuals; 42/42 tests. Enabled physics interpolation.
- Progression & Quest agent finished: XP/levels/upgrades, 3 abilities, evolution, data-driven 5-quest chain, Nib, quest props; 136/136 tests.
- User direction: enemy fighting styles, fair-combat rules (2 attackers max, LOS), local faction fights; Hitbox got a line-of-sight check; adventurers hostile to monsters.
- Lead foundation built and committed; GitHub repo set as `origin` (not pushed yet).
