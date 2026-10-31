# World texture assets (World agent)

All environment textures live in `assets/textures/world/<name>/` as `albedo.jpg` (sRGB colour)
and `normal.jpg` (OpenGL-convention normal map). Each is the 1K-JPG variant from ambientCG,
downloaded 2026-10-31. Only the Color and NormalGL images were kept (the other maps in the
download archives were discarded). Total ~38 MB.

**Licence:** every file is **CC0 1.0 Universal (public domain)** — https://docs.ambientcg.com/license/
(ambientCG: "All assets are provided under the Creative Commons CC0 1.0 Universal License").
No attribution required; credited here anyway.

| Folder | ambientCG asset | Source URL (download) | Used for |
|---|---|---|---|
| `grass/` | Grass004 | https://ambientcg.com/view?id=Grass004 (https://ambientcg.com/get?file=Grass004_1K-JPG.zip) | meadow ground |
| `forest_floor/` | Ground076 | https://ambientcg.com/view?id=Ground076 (https://ambientcg.com/get?file=Ground076_1K-JPG.zip) | leaf litter under trees |
| `dirt_path/` | Ground069 | https://ambientcg.com/view?id=Ground069 (https://ambientcg.com/get?file=Ground069_1K-JPG.zip) | paths, trampled camps, arena |
| `mud/` | Ground071 | https://ambientcg.com/view?id=Ground071 (https://ambientcg.com/get?file=Ground071_1K-JPG.zip) | marsh mud, wet ground |
| `rock_cliff/` | Rock030 | https://ambientcg.com/view?id=Rock030 (https://ambientcg.com/get?file=Rock030_1K-JPG.zip) | cliffs, mountains, ruins stone, castle |
| `rock_mossy/` | Rock064 | https://ambientcg.com/view?id=Rock064 (https://ambientcg.com/get?file=Rock064_1K-JPG.zip) | boulders |
| `bark_fir/` | Bark014 | https://ambientcg.com/view?id=Bark014 (https://ambientcg.com/get?file=Bark014_1K-JPG.zip) | conifer trunks |
| `bark_oak/` | Bark012 | https://ambientcg.com/view?id=Bark012 (https://ambientcg.com/get?file=Bark012_1K-JPG.zip) | broadleaf trunks, logs, wooden props |
| `moss/` | Moss002 | https://ambientcg.com/view?id=Moss002 (https://ambientcg.com/get?file=Moss002_1K-JPG.zip) | moss on rock tops, logs, ruins |
| `shore_pebbles/` | Gravel042 | https://ambientcg.com/view?id=Gravel042 (https://ambientcg.com/get?file=Gravel042_1K-JPG.zip) | river banks, lake/pond shores |

Leaf and needle cards are **not** downloaded: their alpha atlases are generated procedurally at
runtime by `scripts/world/world_textures.gd` (no external asset).
