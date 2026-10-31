---
name: combat-choreography
description: Improve or review Goblin Ascendant combat motion, weapon grips, punch and kick animation, footwork, guard and casting poses. Use for this project's choreography work, not general AI or quest implementation.
---

Read `docs/COMBAT_CHOREOGRAPHY.md` relative to the Goblin Ascendant repository root. It contains the shared specialist brief, confirmed loadout/stance rules, implementation map and visual verification workflow. Read the relevant live code and latest `docs/BACKLOG.md` before treating an ability or moveset as implemented.

Apply that brief directly when working as the main agent. If the user requests delegation and the client supports it, the project also has `.codex/agents/combat-choreographer.toml`; creating this skill does not require or automatically authorize delegation.

Keep work within the assigned scope and ownership contract in `docs/ARCHITECTURE.md`. For choreography fixes, inspect actual graphical runtime motion in addition to appropriate behavior tests. State any missing visual verification and remaining defects plainly.
