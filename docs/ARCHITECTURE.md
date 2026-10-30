# Goblin Ascendant — Architecture & Team Contract (Chapter 1)

Engine: **Godot 4.7.2 stable**, Forward+ renderer, GDScript only, Jolt/default physics.
Godot binary: `D:/GODOT/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe`

Everything is **procedural GDScript** (nodes, meshes and materials built in code).
No imported 3D/audio assets — keeps the build self-contained and licence-clean.
`scenes/main.tscn` is the only scene; `scripts/main/main.gd` builds parts in order:

1. `World` — `res://scripts/world/world.gd` (World agent)
2. `Player` — `res://scripts/player/player.gd` (Player & Camera agent)
3. `Actors` — `res://scripts/enemies/enemy_spawner.gd` (Combat & AI agent)
4. `QuestWorld` — `res://scripts/quests/quest_world.gd` (Progression & Quest agent)
5. `UI` — `res://scripts/ui/ui_root.gd` (UI & Audio agent)

Each part's script must be instantiable with `Script.new()` (no constructor args) and must build
its own child nodes in `_ready()`. Parts added earlier are fully ready before later ones
(World builds synchronously, so `GameState.ground_height()` works for later parts).

## Story scope (user direction)
Prioritise world, controls, combat, AI, abilities and evolution. Quests are **minimal,
data-driven placeholders** that exercise progression; no extensive dialogue, cutscenes, lore or
branching. Keep quest/dialogue definitions as data so the full story can be added later without
touching core systems. Protagonist identity: kind goblin who protects friends and never attacks
peaceful races without provocation (neutral NPCs are never auto-targeted by anything the player does).

## Ownership (one active owner per file)
| Area | Owner | Files |
|---|---|---|
| Shared core | **Lead** | `project.godot`, `scenes/main.tscn`, `scripts/main/*`, `scripts/core/*`, `scripts/combat/{damage_info,hitbox,health_component}.gd`, `scripts/interaction/*`, `docs/ARCHITECTURE.md` |
| World & Environment | World agent | `scripts/world/**`, `shaders/world/**` |
| Player & Camera | Player agent | `scripts/player/**`, `shaders/player/**` |
| Combat & Enemy AI | Combat agent | `scripts/enemies/**`, `shaders/enemies/**` |
| Progression & Quests | Progression agent | `scripts/progression/**`, `scripts/abilities/**`, `scripts/quests/**` |
| UI & Audio | UI agent | `scripts/ui/**`, `scripts/audio/**`, `shaders/ui/**` |
| Integration & QA | QA agent | `tests/**`, `docs/QA_REPORT.md` |

**Never edit another owner's file.** If you need a change in a shared/other file, put the request in
your final report (exact proposed change). The lead integrates. Global `class_name`s must be
prefixed by area to avoid collisions — pick names inside your area (e.g. `WorldTerrain`, `PlayerModel`,
`EnemyBase`, `QuestData`, `HudBar`). Already taken: `Layers, WorldLayout, Palette, InputSetup,
DamageInfo, Hitbox, HealthComponent, Interactable, TriggerZone, AbilityController`.

## Autoloads (singletons)
| Name | Owner | Purpose |
|---|---|---|
| `Events` | Lead | Global signal bus (`scripts/core/events.gd`) — read it, it is the integration surface |
| `Settings` | Lead | `get_value(&"key")`, `quality()`, signal `changed(key)` |
| `SaveManager` | Lead | providers `register(key, obj)`; `save_game()`, `load_game()`, `request_autosave()`, `has_save()` |
| `GameState` | Lead | `player/world/camera/ability_controller` refs, `flags`, checkpoints, menu/mouse policy, `ground_height(x,z)` |
| `Factions` | Lead | `relation(a,b)`, `is_hostile(a_node,b_node)`, `can_damage(attacker,target)` |
| `GameFeel` | Lead | `hit_stop(duration, scale)`, `shake(strength)` |
| `Audio` | UI agent | `play_sfx(id, pos_or_null)`, `create_loop(id, parent)`, `play_music(track)` — never errors on missing sounds |
| `Progression` | Progression agent | XP/levels/stats/abilities/essences/inventory/discoveries/evolution |
| `Quests` | Progression agent | quest chain, objective text + position |

Keep the public API in the stub files (`audio.gd`, `progression.gd`, `quest_manager.gd`,
`ability_controller.gd`) — owners may ADD methods but must not change existing signatures.

## Physics layers (`Layers`)
`WORLD=1` terrain/rocks/trunks/ruins/cave (camera SpringArm collides with WORLD only) ·
`PLAYER=2` · `ACTORS=4` enemies/NPCs/friend · `HITBOX=8` · `INTERACT=16` · `TRIGGER=32` · `WATER=64`.
Decorative foliage (grass, flowers, bushes, leaves) has **no collision** and is not on any layer.
Characters: player body layer `PLAYER`, mask `WORLD|ACTORS`. Actors layer `ACTORS`, mask `WORLD|PLAYER|ACTORS`.

## Groups
`player` (the Player) · `actors` (every enemy/NPC CharacterBody3D) · `enemies` (anything that can fight) ·
`lock_targets` (currently lockable — remove on death) · `boss` (ogre) · `rescue_guard` (rescue-site guards).

## Damage contract
Any damageable node (player, enemy, NPC) implements:
```gdscript
func take_damage(info: DamageInfo) -> int      # returns DamageInfo.Result.{IGNORED,HIT,BLOCKED,KILLED}
func get_faction() -> StringName
func is_dead() -> bool
```
Lockable/targetable actors also implement `get_lock_point() -> Vector3` (chest height) and expose
`var display_name: String`, and a `HealthComponent` as `health`.
Attacks use `Hitbox` (`scripts/combat/hitbox.gd`) with **explicit active windows**: one hit per target
per activation (multi-hit only via `rehit_interval`). Heavy hits (`info.is_heavy`) call
`GameFeel.hit_stop(0.06)` + `GameFeel.shake(...)` on the attacker side when they connect.
Emit `Events.actor_damaged(actor, info)` when an actor is hurt.

## Factions & social rules
Factions: `player, goblin_friend, wolf, goblin_raider, human_raider, adventurer, ogre` (consts on `Factions`).
Race never decides hostility. Enemies attack only targets where `Factions.is_hostile(self, target)`.
Neutral adventurers never attack the player unprovoked. If the player damages one, **that individual**
gets a grudge (`has_grudge(node) -> bool`) and defends itself; it calms down after the player leaves
(~20 s out of range). Emit `Events.actor_provoked(actor, by)` when provoked.

## Enemy AI (Combat agent)
Reusable state machine: `IDLE → PATROL → INVESTIGATE → CHASE → ATTACK → RECOVER`, plus `HURT`,
`RETURN`, `DEAD`. Limited detection radius + FOV, leash radius from home; return home (and regenerate)
when the player escapes. Telegraphs (wind-up pose + `Audio.play_sfx(&"enemy_warn", pos)`) before
damage windows; recovery windows after. Call `GameState.set_engaged(self, true/false)` while
fighting the player. On death emit `Events.enemy_killed(self, enemy_type, tags)` and, for essence
carriers, `Events.essence_dropped(ability_id, global_position)`.
Enemy types (`enemy_type`): `wolf`, `alpha_wolf` (drops `wolf_dash`), `goblin_raider`,
`human_raider`, `raider_captain` (drops `flame_burst`), `adventurer` (neutral), `ogre` (boss).
Rescue-site guards: exactly `WorldLayout.RESCUE_GUARD_COUNT` goblin raiders tagged `rescue_guard`,
not spawned if `GameState.has_flag(&"friend_rescued")`. Boss not spawned if `has_flag(&"boss_defeated")`;
alpha/captain not spawned if `has_flag(&"alpha_wolf_defeated")` / `has_flag(&"raider_captain_defeated")`
(the Combat agent sets those flags on death; it also sets `boss_defeated`).
Boss: emits `Events.boss_engaged(boss)` when the player enters the arena (use a `TriggerZone`),
`boss_health_changed`, `boss_disengaged` (player left/died → boss resets to full),
`boss_defeated`. Set `GameState.boss_active` true while engaged.
Movement: direct steering over the heightfield with simple obstacle avoidance (raycasts on WORLD)
is acceptable; `NavigationAgent3D` optional.

## Player API (Player agent) — `class_name Player extends CharacterBody3D`, group `player`
```gdscript
var health: HealthComponent
var stamina: float; var energy: float
func get_faction() -> StringName          # Factions.PLAYER
func is_dead() -> bool
func take_damage(info: DamageInfo) -> int # handles dodge i-frames, block (stamina), damage_taken_mult
func spend_energy(amount: float) -> bool
func spend_stamina(amount: float) -> bool
func begin_dash(direction: Vector3, speed: float, duration: float, invulnerable: bool) -> void  # Wolf Dash
var damage_taken_multiplier: float = 1.0  # Stone Guard sets/restores this
func get_lock_target() -> Node3D           # null if not locked
func get_facing() -> Vector3               # flat forward of the model
func get_cast_origin() -> Vector3          # chest-height point in front of the goblin (Flame Burst)
func play_cast_animation() -> void
func is_busy() -> bool                     # attacking/dodging/hurt/dead → abilities refuse
func respawn() -> void                     # at GameState.get_respawn_position()
```
- Spawns at `GameState.get_spawn_position()`; sets `GameState.player = self`; emits `Events.player_spawned`.
- Stats come from `Progression.max_health()/max_stamina()/max_energy()/attack_power()`; refresh on
  `Events.stats_upgraded`, `level_up`, `evolution_changed`.
- Emits `Events.player_stats_changed(...)` whenever hp/stamina/energy change (throttle is fine).
- Creates `AbilityController` child: `abilities.setup(self)`; on `ability_1/2/3` calls `try_activate(0/1/2)`.
- Evolution: on `Events.evolution_changed(&"hobgoblin")` the model visibly grows (≈1.3× scale,
  darker skin, armour pieces, bigger blade) and if `Progression.has_unlock(&"shockwave_slam")` the
  heavy attack adds a shockwave AoE.
- Death: `Events.player_died` → ~3 s → `respawn()` at last checkpoint, full stats, `Events.player_respawned`.
- Calls `GameState.update_safe_position(pos)` every ~2 s while grounded, not in water, not in combat.
- Interaction: Area3D (mask `INTERACT`) picks nearest `Interactable`; emits `Events.interaction_prompt_changed`.
- All gameplay input ignored while `GameState.is_input_blocked()`.
- Camera: SpringArm3D rig (mask `WORLD`), sets `GameState.camera`; listens `Events.camera_shake`
  and `Settings.changed`. Lock-on: R toggles, wheel switches among `lock_targets` group in range/view;
  `Events.lock_target_changed`.

## Interaction / zones / quests
- `Interactable` (Area3D on `INTERACT`): `interact_id`, `prompt`, `enabled`, `radius`; emits
  `interacted(actor)` and `Events.interacted(interact_id, actor)`.
- `TriggerZone` (cylinder, player-only): emits `Events.zone_entered/zone_exited(zone_id)`.
- World agent places `TriggerZone`s with `zone_id` = each key of `WorldLayout.LANDMARKS`
  (radius from the dict). Progression marks discoveries from those (`Events.landmark_discovered`).
- Progression agent places quest content (signpost, injured friend Nib, supplies, ruins shrine,
  cave hearth, essence orbs) in `QuestWorld`, using `Interactable`s.
- Quests listen to Events (`zone_entered`, `interacted`, `enemy_killed`, `item_collected`,
  `boss_defeated`...) and are defined as data so story content can grow without code changes.

## Abilities (Progression agent)
Ids: `wolf_dash` (alpha wolf essence), `stone_guard` (ruins shrine), `flame_burst` (raider captain essence).
Passive unlock `shockwave_slam` from Hobgoblin evolution. Unlocking auto-equips into the next free slot.
`AbilityController` spends energy, enforces cooldowns, emits `Events.ability_used/ability_failed`,
calls player API above. Fire damage via a `Hitbox` owned by the player.

## Evolution
Goblin → Hobgoblin requires **level ≥ 5** and quest "The Ogre's Claim" done + home claimed.
`Progression.evolve()` sets `stage`, emits `Events.evolution_changed(&"hobgoblin")`, unlocks
`shockwave_slam`, boosts stats. Data-driven stage list so later stages can be appended.

## Save / load
Providers: `game_state` (flags, checkpoint, safe position), `progression`, `quests`. Loading happens
at the start of `main.gd` **before** parts are built, so spawners read restored state. Autosave via
`SaveManager.request_autosave()` after quest steps / essences / checkpoints / evolution.
`F5` quick save, `F9` quick load. `GameState.new_game()` / `continue_game()` reload the scene.

## Menus & mouse
UI calls `GameState.set_menu_open(true/false)` (handles mouse capture). Pause uses
`get_tree().paused`; UI nodes use `PROCESS_MODE_ALWAYS`. Title screen shown when
`GameState.show_title` (first boot) with **Continue** (if `SaveManager.has_save()`) and **New Game**.

## Settings
`Settings` keys: `mouse_sensitivity` (deg/pixel), `invert_y`, `camera_distance`, `fov`,
`camera_shake`, `graphics_quality` (0/1/2), `view_distance`, `render_scale`, `vsync`,
`fullscreen`, `show_fps`, `master_volume`, `music_volume`, `sfx_volume`, `ambience_volume`.
World applies quality/view-distance (shadows, SSAO, glow, fog, foliage density, visibility ranges);
Audio applies volumes; camera applies its keys; `Settings` applies display keys.

## Art direction (all agents)
Stylized, cohesive, warm: emerald meadows, layered canopies, wildflowers, warm sun, soft shadows,
atmospheric depth/fog. Use `Palette` colours/materials (`Palette.mat`, `Palette.glow`,
`Palette.vertex_color_mat`). Characters are articulated primitive models (capsules, spheres,
boxes, prisms) with readable silhouettes. Prefer fewer, well-composed objects over clutter.
Use `MultiMeshInstance3D` for repeated foliage; `visibility_range_end` for culling; few
shadow-casting lights.

## Testing
After `class_name` changes run an import so the global class cache updates:
`"$G" --headless --path . --import`  then  `"$G" --headless --path . --quit-after 600`
(G = Godot console binary above). Other agents edit in parallel — if an error is clearly in
someone else's file, note it and continue. Self-tests go in your own area or `tests/<area>_*.gd`
(e.g. a scene script under `tests/` that you run with `"$G" --headless --path . res://tests/x.tscn`).
