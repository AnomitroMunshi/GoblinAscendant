# Combat choreography brief

Shared project brief for the Claude Code agent, Codex agent, and Codex skill. User direction in the current conversation takes precedence. Read `docs/BACKLOG.md` for the latest confirmed design and distinguish implemented mechanics from plans.

## Invocation

- Claude Code: open this repository and ask, "Use the combat-choreographer agent to review the unarmed combo." Definition: `.claude/agents/combat-choreographer.md`.
- Codex with custom-agent support: ask, "Use combat_choreographer to review the unarmed combo." Definition: `.codex/agents/combat-choreographer.toml`.
- Codex direct skill: "$combat-choreography improve the punch and kick animations." Definition: `.agents/skills/combat-choreography/SKILL.md`. This runs the workflow directly without requiring a separate agent.

New agent/skill directories may require reopening the project or starting a fresh session for discovery. Files have been locally validated; Claude runtime discovery was not tested because Claude Code is not installed in this environment. Host/client support and delegation availability determine whether a separate worker can run.

Formats checked against [Claude Code subagent documentation](https://code.claude.com/docs/en/sub-agents), [Codex custom agents](https://learn.chatgpt.com/docs/agent-configuration/subagents), and [Codex skills](https://learn.chatgpt.com/docs/build-skills).

## Role and boundaries

Make combat motion convincing and readable in Goblin Ascendant. Work on anticipation, strikes, grips, footwork, contact, recoil, recovery, guard, stowing/drawing and casting poses. Review character geometry only where it prevents a correct grip or produces visible gaps during motion.

The combat/AI role owns enemy decisions, attack selection, damage resolution, faction logic and encounter fairness. The player/camera role owns controller state transitions and locomotion. Choreography coordinates pose timing and contact windows with those systems; do not silently change damage, invulnerability, target selection or progression to hide a motion problem.

Read the ownership section of `docs/ARCHITECTURE.md`. A delegated task should assign exact editable files. If running as a specialist subagent, edit only that assignment; report concrete changes needed in another owner's files to the lead. Do not independently edit `player.gd`, `goblin_model.gd` or an enemy model while another agent owns the same file. The lead can integrate related animation/controller changes within the user's task. Paused World/UI/Combat work stays paused unless the user resumes it. This agent definition does not authorize spawning more agents, publishing, committing or pushing.

## Game and equipment contract

- Fully 3D Godot project, currently procedural GDScript models and joint-node animations. User does not want a manual rigging workflow. Do not migrate engines or impose imported rigs to complete an ordinary motion fix.
- Mature dark, swampy fantasy. The protagonist is a capable goblin who protects friends; do not reward unprovoked attacks on peaceful NPCs. Strong motion should feel controlled and grounded rather than childish, floaty or excessively theatrical.
- Starting gear: opaque torn waist cloth, bare feet and rough knife. Preserve current appearance unless the assignment includes a model change. Hobgoblin redesign is deferred; do not implement future forms as collateral work.
- Goblin carries one one-handed main weapon (blunt, pointed or edged), one knife and one sling. Hobgoblin carries shield+axe, shield+sword, or one two-handed spear/sword/hammer/axe, plus knife and sling. These are carried slots, not permission to wield everything at once. Shield and two-handed main weapons are mutually exclusive.
- Distinct weapon movesets are required. Knife: cuts, finishing stab, committed thrust. Sword: broader cuts/thrust. Axe: weighted cleaves/chop. Spear: reach and thrusts. Hammer: weighted impact. Sling: wind-up/release and a projectile. Detailed future movesets remain backlog proposals until implemented.
- One-handed attacks keep the off-hand in a believable balancing/protective role. Two-handed weapons require visible contact from both hands on the actual haft/hilt; no invisible grips. Oathcleaver's early Goblin-compatible form remains unresolved in the backlog; do not assume the Goblin may use a two-handed axe.
- Magic can be used while holding weapons, including shields/two-handed loadouts. Choose origins per skill (mouth/chest, body, hand or weapon); regrip naturally if a hand briefly releases. Preserve energy, cooldowns, busy/cancel rules and faction/LOS checks. Holding equipment does not imply simultaneous unrestricted attacks and spells.

## Current controls and observed problems

Check the live InputMap/controller before relying on these bindings:

- H draws/holsters the current knife; holstered LMB punches in a combo, RMB kicks.
- Armed LMB is light combo; RMB is heavy; Q is held guard; Ctrl dodges; 1/2/3 are skills.
- Unarmed idle is relaxed, arms at the sides. Walking has natural arm swing. Q alone raises a boxing guard: fists by the cheeks, elbows tucked, chin slightly down. Releasing Q lowers the arms. Do not turn holstering into a permanent guard stance or auto-draw the knife on LMB.
- Hands must read as connected palms, curled fingers and tucked thumbs, not detached beads or loose claws. Inspect low angles for jaw/neck holes and gripping angles for fingers floating from the wrist.
- Prior failures: two-arm knife chops, weak kick extension, minimally interpolated punch poses, rigid mannequin limbs, permanent forward-held hands and exaggerated attack-mouth teeth. Verify actual runtime behavior rather than assuming a renamed pose fixes it.

## Implementation map

- `scripts/choreography/`: data-driven movesets (`movesets/{unarmed,knife,sword,sling}.gd`, format documented in `choreo_library.gd`), keyframe evaluation (`choreo_pose.gd`), arm IK (`choreo_ik.gd`), procedural weapon meshes (`choreo_weapons.gd`) and the sling projectile (`choreo_sling_stone.gd`). To add a weapon: create a moveset file, register it in `ChoreoLibrary.SOURCES` and add its mesh to `ChoreoWeapons`.
- `scripts/player/goblin_model.gd`: articulated nodes (incl. ankle pivots `foot_l/foot_r`), weapon sockets/stowing (`set_weapon`), `_attack` (evaluates move data), `_rest_combat` (moveset carry), hand IK + wrist aim, foot planting, sling spin, hurt/cast poses, `_update_face`. Preserve joint names and the public animation API.
- `scripts/player/player.gd`: resolves the move at attack start, buffered combo state, per-move stamina, footwork (lunge applied once, stops on body contact), data-sized hitboxes, projectile launch, holster/equip (`equip_weapon`, `debug_set_weapon`), guard reduction per moveset, direction-aware hit reactions and the model feed.
- `tests/choreo_preview.tscn` (windowed): contact sheets per move in `tests/screens/choreo/` (rows: front / side / gameplay camera; columns: anticipation -> contact -> follow-through -> recovery; red box = live hitbox).
- `scripts/player/player_fx.gd`: trails/impact feedback. Punches/kicks must not receive blade trails; thrusts need directional rather than broad cutting trails.
- `scripts/combat/hitbox.gd`: shared LOS and once-per-target-per-activation contract; do not bypass it.
- `scripts/enemies/`: enemy attack/model/FX files; inspect the actual enemy selected in the task before proposing animations.
- `tests/player_test.tscn`: behavior regression suite. `tests/unarmed_visual.tscn`: actual model rest/guard/punch/kick pose renders. `tests/playground_screens.tscn`: live-controller windowed smoke test. `tests/goblin_turnaround.tscn`: character angle inspection.

Pose math matters: models face -Z. Positive local X rotates a downward limb forward; upward torso/head joints invert authored X in `_process`. Check world-space hand/foot positions, parent rotation, scaling, smoothing and physics interpolation before increasing angles. Do not add mesh root translation on top of controller lunges without accounting for movement twice.

## Working method and acceptance

1. Reproduce the exact action with current equipment/state. Inspect the controller-to-animation path, timing and mesh hierarchy; use the user's screenshot as evidence, not as proof of the cause.
2. For the requested move, author a clear preparation, extension/contact, follow-through, retraction and return. Punches alternate appropriate hands with shoulder/torso rotation and a stable opposite guard; kicks chamber, extend, retract at the knee and plant again with a believable support leg. Maintain readable weight shifts and avoid limb/weapon clipping.
3. Align the damaging window to visible contact and actual reach. Preserve one hit per target per activation, walls/LOS, stamina, guard facing and cancellation rules. Never enlarge a hitbox to compensate for a missing animation. If timing or reach changes, validate the affected controller path too.
4. Preview front, side and gameplay camera angles across the full motion, including idle/guard transitions. Static key-pose renders are useful but are not proof of a good animation. Use a short capture or sequential runtime frames when needed. Inspect the actual saved images before describing improvement.
5. Run checks appropriate to the change. Headless tests establish mechanics; visible motion requires a graphical Godot run. If graphical execution is unavailable, say motion is unverified. Do not claim visual acceptance because a script parsed or a damage test passed.
6. Return the changed behavior, files, preview paths, checks/results and remaining visible defects. Record meaningful completed work or newly discovered follow-ups in the backlog when assigned to update it. Do not claim planned movesets or concept images are implemented gameplay.

Godot console path currently documented by the project:

```powershell
$godotExe = 'D:/GODOT/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe'
& $godotExe --headless --path . --import
& $godotExe --headless --path . res://tests/player_test.tscn
& $godotExe --path . res://tests/unarmed_visual.tscn
& $godotExe --path . res://tests/playground_screens.tscn
```

Use import when class/cache changes need it; run only relevant scenes rather than repeating everything after every small edit. Use the configured Forward+ renderer for final visual judgment. Preserve unrelated user changes and report existing engine warnings accurately.

## Enemy choreography spec (review, 2026-10-31)

This is a report-only review of `scripts/enemies/`. No enemy files were edited; the Combat agent or the lead applies these changes, and the Character Art agent owns enemy model-building. Phases use each enemy's own windup / active / recovery from `EnemyAttack`.

Rules for every enemy:
- Reach the visible contact pose within the first 40-60 % of the active window.
- Hold the anticipation pose (not still moving) for the last 30-45 % of the windup.
- Never let the hitbox exceed the visible weapon or jaw reach.

Shared observations (all humanoids, `enemy_humanoid.gd` `POSES`):
- Each pose has only 4 numbers (right arm pitch, left arm pitch, torso pitch, torso yaw). With no elbow, wrist or weapon-edge control, chops can land flat-side and thrusts read as arm raises. Proposed: add `fore_r` (elbow) and `grip_x/grip_z` (weapon pitch/roll) channels per pose, using the player convention (+X = forward for limbs).
- The strike pose snaps in at active start (rate 28-34/s), so contact reads 70-90 ms into a 140-180 ms window. That timing is fine, but arcs (sweep, slash) read as a straight blend. Proposed: a `mid` key at 35 % of the active window.
- Every attack uses the same step (`leg_l -0.25 / leg_r 0.3` in the windup, `0.45 / -0.3` at the strike). Per-attack steps are proposed in the table.
- HURT is one backward lean regardless of the hit side. Proposed: use the hit direction (`info.knockback` in body space) like the player does:
  - front: torso -0.35 and a step back with the rear leg;
  - behind: torso +0.3 forward;
  - side: torso roll 0.25 away and a twist of 0.3.
- Blocking has no impact reaction. Proposed: on BLOCKED, push both guard arms back 0.25 rad and torso -0.15 for 0.15 s, plus a 0.15 m slide back.

| Enemy / attack (anim) | Windup -> active -> recovery (s) | Anticipation (held) | Contact | Follow-through / recovery | Telegraph cue |
|---|---|---|---|---|---|
| Wolf lunge (`lunge`) | 0.50 -> 0.30 -> 0.80 | Crouch: body_y 0.42, rear legs loaded 0.6, head low -0.25, tail rigid; step_back 1.2 m/s. Hold the last 0.2 s still. | Body extended (0.75), forelegs reaching 1.1, jaws open. Reach the pose within 0.12 s. | Forelegs plant, head drops 0.1, then the wolf turns away (circles). | Growl at windup start, head locked on the target. |
| Wolf bite (`bite`) | 0.375 -> 0.14 -> 0.64 | DEFECT: plays the same crouch/lunge poses as the lunge. Proposed: no crouch; head pulls back 0.25, front legs braced. | Head snaps forward 0.45 with the jaw open 0.5 rad within 60 ms. Body stays put (no lunge). | Jaw closes, head shakes twice (yaw ±0.15), step back. | Short snarl, clearly distinct from the lunge's deep crouch. |
| Alpha pounce (`lunge`, heavy) | 0.95 -> 0.40 -> 1.20 | Deeper crouch (body_y 0.36) and a 0.25 s shoulder tremble at the end of the windup; step_back 1.5. | Airborne arc: body pitch -0.3 rising to +0.2 landing; add a 0.4 m vertical hop. | Heavy landing (squash 0.15 s), then a 0.4 s punishable recovery. | Howl, eyes brighten. |
| Goblin raider chop (`chop`) | 0.42 -> 0.14 -> 0.60 | Arm 2.8 overhead, torso back 0.18, yaw 0.35, rear-leg step 0.3; held 0.19 s. | Arm 1.0, torso -0.35, yaw -0.15, front leg 0.45; grip pitch -1.2 so the edge leads. | Hold 45 % of the recovery, then hop back. | Arm raise over 55 % of the windup. |
| Goblin raider jab (`thrust`) | 0.29 -> 0.12 -> 0.42 | Arm -0.6 drawn back, torso yaw 0.55; hold at least 0.12 s. | Arm 1.55 straight, yaw -0.35, front-foot step 0.5. | Snap back to guard. | Shoulder-back hold. |
| Human raider slash (`sweep`) | 0.62 -> 0.18 -> 0.80 | Arm 1.5 out to the side, torso yaw 1.1, weight on the rear leg; hold the last 0.25 s. | Mid key yaw 0 at 35 % of the active window, then -1.1; grip roll 1.57 so the edge faces the sweep. | Hold 45 %, then return to `GUARD_POSE` (not idle) when block_chance > 0. | Raised-arm hold. |
| Human raider axe chop (`chop`, heavy) | 0.93 -> 0.16 -> 1.04 | Raise over 0.5 s to arm 2.9 with torso back 0.25, then hold 0.4 s with the existing tremble. | Arm 0.9, torso -0.45, deep front-knee bend (crouch 0.12). | Axe stays down 0.35 s ("embedded"), then is pulled free (arm 1.3). This is the punish window. | `enemy_warn` plus an exhale. |
| Human raider block | n/a | `GUARD_POSE` is fine; add crouch 0.06 and a 0.1 s raise blend. | Guard recoil on block (see above). | Lower over 0.2 s, never instantly. | None. |
| Raider captain overhead (`chop`, heavy) | 0.85 -> 0.16 -> 0.99 | As the axe chop; the torch arm stays forward for balance (arm_l 0.9). | As the axe chop. | As the axe chop. | Warn sound. |
| Raider captain flame sweep (`flame`) | 1.40 -> 0.30 -> 1.50 | Torch arm 2.9 up, torso back 0.25, yaw 0.5, flare ramp and 1.7 m marker (present). Add a 0.3 step back in the first 0.4 s. | Sweep the torch right to left across the whole 0.30 s (yaw +0.5 -> -0.6 linear, not a snap), torso -0.3. | Torch held low 0.5 s (vulnerable). | Flare + marker (good). |
| Ogre club smash (`smash`) | 1.60 -> 0.18 -> 1.90 | Both arms 3.0 overhead, torso back 0.35, a 0.4 s held peak, wide feet; marker at the impact point (present). | Arms 0.75, torso -0.6, hips drop 0.15. The club head must reach the marker centre: the hitbox is at z -3.0, so verify the club length. | Club stays grounded 0.8 s (punish); shockwave FX at contact. | Marker + warn + shake. |
| Ogre club sweep (`sweep`) | 1.25 -> 0.30 -> 1.40 | Arm 1.4, torso yaw 1.25 coiled right, weight on the right leg. | Travel across the full 0.30 s (mid key at yaw 0), ending at yaw -1.3. | Torso continues to -1.4 and holds 0.5 s. | 4 m ring (present). |
| Ogre stomp (`stomp`, unblockable) | 1.00 -> 0.15 -> 1.10 | Right knee up (`STOMP_LEG`), arms out (arm_z ±0.6), torso back 0.1. | Foot slams within 50 ms; whole-body drop 0.1. | Dust ring; foot stays planted 0.4 s. | 3 m purple ring (present). |
| Ogre charge (enraged) | 1.30 -> 1.10 -> 2.20 | Torso forward 0.6, pawing step, roar. | Run cycle keeps playing during the active window (not a frozen pose); head down. | Stumble stop: torso -0.3, 0.6 s dizzy sway (punish). | Roar + dust trail. |

Hit-reaction notes for all enemies:
- Light hit (stagger < 0.5): additive 0.15 s flinch away from the hit, no state change.
- Stagger: HURT with a step away from the hit.
- Heavy hit (`is_heavy`, stagger >= 0.9): larger recoil plus a knock-back slide.
- Wolves: head jerk away plus a hind-leg skid.
- Ogre: super armour; only heavy hits cause a flinch (head turn 0.2).
