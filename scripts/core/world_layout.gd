class_name WorldLayout
## Shared map contract for the Chapter 1 forest valley. Lead-owned.
## The playable area is a 512 x 512 m square centred on the origin
## (x, z in [-256, 256]); +X is east, -Z is north. Y values here are 0:
## always resolve the real height with GameState.ground_height(x, z).
##
## The World agent shapes terrain so every area below is reachable,
## reasonably level within its radius and connected by paths.
## Other agents place their content relative to these anchors.

const HALF_SIZE := 256.0
const PLAYABLE_HALF := 236.0  # invisible boundary / cliffs start beyond this

# --- Areas: centre and approximate radius ---
const START_GLADE := Vector3(-10, 0, 175)
const START_GLADE_RADIUS := 32.0
const PLAYER_START := Vector3(-12, 0, 186)
const PLAYER_START_YAW := 0.0  # facing -Z (north, toward the castle)

const WOLF_WOODS := Vector3(-130, 0, 85)
const WOLF_WOODS_RADIUS := 60.0
const ALPHA_WOLF_DEN := Vector3(-175, 0, 120)  # alpha wolf (Wolf Dash essence)

const RESCUE_SITE := Vector3(-150, 0, 10)      # injured goblin + guards
const RESCUE_SITE_RADIUS := 18.0
const RESCUE_GUARD_COUNT := 3                  # goblin raiders tagged &"rescue_guard"

const RUINS := Vector3(-80, 0, -85)
const RUINS_RADIUS := 40.0
const RUINS_SHRINE := Vector3(-92, 0, -100)    # Stone Guard essence shrine

const OVERLOOK := Vector3(-25, 0, -5)          # elevated hill, view of castle & waterfall

const ADVENTURER_CAMP := Vector3(120, 0, 120)  # neutral humans
const ADVENTURER_CAMP_RADIUS := 22.0

const RAIDER_OUTPOST := Vector3(155, 0, -5)    # hostile human raiders + captain
const RAIDER_OUTPOST_RADIUS := 22.0            # captain drops Flame Burst essence

const OGRE_CLEARING := Vector3(95, 0, -150)    # boss arena
const OGRE_ARENA_RADIUS := 28.0

const CAVE_ENTRANCE := Vector3(178, 0, -178)   # mouth faces south-west toward the clearing
const CAVE_INTERIOR := Vector3(195, 0, -198)   # hearth / home centre (inside the cave shell)
const CAVE_RADIUS := 14.0

const WATERFALL := Vector3(30, 0, -212)        # falls off the northern cliff into a pool
const WATERFALL_POOL := Vector3(32, 0, -195)

# River polyline (centre line), from the waterfall pool south to the map edge.
const RIVER_POINTS := [
	Vector3(32, 0, -195), Vector3(42, 0, -150), Vector3(30, 0, -95),
	Vector3(12, 0, -40), Vector3(18, 0, 15), Vector3(48, 0, 70),
	Vector3(64, 0, 125), Vector3(58, 0, 180), Vector3(66, 0, 256),
]
const RIVER_WIDTH := 10.0
# Shallow fords (walkable) and the stone bridge.
const FORDS := [Vector3(12, 0, -40), Vector3(60, 0, 100)]
const BRIDGE := Vector3(61, 0, 165)

# Distant landmark outside the playable area (visible from overlooks).
const CASTLE_LANDMARK := Vector3(-90, 150, -620)

# Main path network: polylines the World agent carves as dirt paths.
const PATHS := [
	[Vector3(-12, 0, 186), Vector3(-30, 0, 140), Vector3(-80, 0, 110), Vector3(-130, 0, 85), Vector3(-150, 0, 10)],
	[Vector3(-150, 0, 10), Vector3(-120, 0, -40), Vector3(-80, 0, -85)],
	[Vector3(-12, 0, 186), Vector3(25, 0, 150), Vector3(61, 0, 165), Vector3(100, 0, 140), Vector3(120, 0, 120)],
	[Vector3(-30, 0, 140), Vector3(-25, 0, -5), Vector3(12, 0, -40), Vector3(40, 0, -60), Vector3(80, 0, -110), Vector3(95, 0, -150)],
	[Vector3(-80, 0, -85), Vector3(-25, 0, -5)],
	[Vector3(120, 0, 120), Vector3(60, 0, 100), Vector3(18, 0, 60), Vector3(-25, 0, -5)],
	[Vector3(120, 0, 120), Vector3(155, 0, -5), Vector3(130, 0, -90), Vector3(95, 0, -150)],
	[Vector3(95, 0, -150), Vector3(140, 0, -170), Vector3(178, 0, -178)],
]

# Respawn checkpoints (death respawns at the latest one reached).
const CHECKPOINTS := {
	&"glade": Vector3(-12, 0, 186),
	&"woods_edge": Vector3(-80, 0, 110),
	&"ruins": Vector3(-60, 0, -70),
	&"camp": Vector3(110, 0, 128),
	&"clearing_edge": Vector3(75, 0, -118),
	&"home": Vector3(185, 0, -188),
}

# Discoverable landmarks: compass icons + exploration XP.
const LANDMARKS := {
	&"glade": {"name": "Sunlit Glade", "pos": START_GLADE, "radius": 25.0},
	&"wolf_woods": {"name": "Howling Woods", "pos": WOLF_WOODS, "radius": 40.0},
	&"ruins": {"name": "Mossy Ruins", "pos": RUINS, "radius": 30.0},
	&"overlook": {"name": "Windy Overlook", "pos": OVERLOOK, "radius": 14.0},
	&"waterfall": {"name": "Silver Falls", "pos": WATERFALL_POOL, "radius": 20.0},
	&"camp": {"name": "Adventurers' Camp", "pos": ADVENTURER_CAMP, "radius": 22.0},
	&"outpost": {"name": "Raider Outpost", "pos": RAIDER_OUTPOST, "radius": 22.0},
	&"ogre_clearing": {"name": "Ogre's Clearing", "pos": OGRE_CLEARING, "radius": 30.0},
	&"cave": {"name": "Hollow Cave", "pos": CAVE_ENTRANCE, "radius": 14.0},
}


static func distance_to_river(p: Vector3) -> float:
	var best := INF
	for i in RIVER_POINTS.size() - 1:
		var a: Vector3 = RIVER_POINTS[i]
		var b: Vector3 = RIVER_POINTS[i + 1]
		var q := Geometry3D.get_closest_point_to_segment(Vector3(p.x, 0, p.z), a, b)
		best = minf(best, q.distance_to(Vector3(p.x, 0, p.z)))
	return best


static func distance_to_path(p: Vector3) -> float:
	var best := INF
	var flat := Vector3(p.x, 0, p.z)
	for path: Array in PATHS:
		for i in path.size() - 1:
			var q := Geometry3D.get_closest_point_to_segment(flat, path[i], path[i + 1])
			best = minf(best, q.distance_to(flat))
	return best
