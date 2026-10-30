# Assets & Licences

Goblin Ascendant Chapter 1 ships **no third-party assets**.

| Asset type | Source | Licence |
|---|---|---|
| Terrain, water, vegetation, ruins, cave, sky | Procedurally generated GDScript + shaders written for this project (`scripts/world`, `shaders/world`) | Project licence |
| Characters (goblin, Nib, wolves, raiders, adventurers, ogre) | Primitive meshes assembled and animated in code (`scripts/player`, `scripts/enemies`, `scripts/quests`) | Project licence |
| Sound effects, ambience, music | Synthesised at runtime from oscillators/noise (`scripts/audio`) | Project licence |
| UI theme | Built in code with Godot `StyleBoxFlat` + the engine default font | Project licence / Godot (MIT) |
| Engine | Godot Engine 4.7.2 | MIT |

Reason: an offline-reproducible, licence-clean build. Art can later be swapped for CC0
packs (e.g. Kenney, Quaternius, Poly Haven) by replacing the model builder functions;
record each new source and licence in this table.
