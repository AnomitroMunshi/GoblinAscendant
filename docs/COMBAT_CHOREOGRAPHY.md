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

- `scripts/player/goblin_model.gd`: articulated nodes, `ATTACK_KEYS`, `_attack`, `_rest_combat`, `_target_pose`, `_update_face`, weapon visibility. Preserve joint names and the public animation API.
- `scripts/player/player.gd`: armed/unarmed attack timing/data, buffered combo state, stamina, lunges, active hitbox windows, holster state and model feed.
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
