class_name Palette
## Shared stylized colour palette and cached material factory.
## Use these so every agent's geometry belongs to the same world.

# Nature
const GRASS := Color(0.36, 0.62, 0.24)
const GRASS_LIGHT := Color(0.55, 0.76, 0.30)
const MOSS := Color(0.30, 0.47, 0.18)
const LEAF_DARK := Color(0.16, 0.38, 0.17)
const LEAF := Color(0.24, 0.52, 0.20)
const LEAF_WARM := Color(0.56, 0.66, 0.22)
const BARK := Color(0.33, 0.23, 0.16)
const DIRT := Color(0.55, 0.42, 0.28)
const ROCK := Color(0.52, 0.52, 0.50)
const ROCK_DARK := Color(0.33, 0.34, 0.35)
const STONE_RUIN := Color(0.64, 0.62, 0.56)
const WATER := Color(0.22, 0.55, 0.62)
const SAND := Color(0.80, 0.72, 0.52)
const FLOWER_COLORS := [Color(0.95, 0.85, 0.30), Color(0.92, 0.45, 0.62), Color(0.62, 0.52, 0.95), Color(0.98, 0.98, 0.92), Color(0.95, 0.55, 0.25)]

# Characters
const GOBLIN_SKIN := Color(0.47, 0.55, 0.22)      # olive green (concept: docs/concepts/goblin-player-v1.png)
const HOBGOBLIN_SKIN := Color(0.38, 0.46, 0.20)   # deeper olive, still clearly goblin
const CLOTH_BROWN := Color(0.46, 0.32, 0.20)
const CLOTH_RED := Color(0.62, 0.20, 0.16)
const CLOTH_BLUE := Color(0.24, 0.36, 0.62)
const LEATHER := Color(0.38, 0.25, 0.15)
const RUST := Color(0.58, 0.36, 0.22)
const STEEL := Color(0.70, 0.72, 0.76)
const WOLF_FUR := Color(0.42, 0.40, 0.40)
const OGRE_SKIN := Color(0.62, 0.55, 0.40)
const HUMAN_SKIN := Color(0.86, 0.68, 0.54)

# Effects / UI accents
const FIRE := Color(1.0, 0.55, 0.15)
const ESSENCE := Color(0.55, 0.85, 1.0)
const GOLD := Color(0.93, 0.76, 0.32)
const DANGER := Color(0.92, 0.25, 0.20)

static var _cache: Dictionary = {}


## Opaque stylized material (soft wrap lighting, no harsh speculars). Cached per colour.
static func mat(color: Color, roughness: float = 0.85) -> StandardMaterial3D:
	var key := "m%s_%.2f" % [color.to_html(), roughness]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	_cache[key] = m
	return m


## Material using per-vertex colours (for merged procedural meshes).
static func vertex_color_mat(roughness: float = 0.9) -> StandardMaterial3D:
	var key := "vc_%.2f" % roughness
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = roughness
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	_cache[key] = m
	return m


## Unshaded glowing material for effects, essences, fire, telegraphs.
static func glow(color: Color, energy: float = 2.0, transparent: bool = false) -> StandardMaterial3D:
	var key := "g%s_%.2f_%s" % [color.to_html(), energy, transparent]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache[key] = m
	return m
