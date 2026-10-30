extends Node3D
## "Actors" part of main.tscn (Combat agent). Spawns every enemy / NPC of
## Chapter 1 around WorldLayout anchors, snapped to GameState.ground_height.
## Flags (set on death / by Quests) prevent re-spawning unique encounters.

const ADVENTURER_SCRIPT := "res://scripts/enemies/enemy_adventurer.gd"
const OGRE_SCRIPT := "res://scripts/enemies/enemy_ogre.gd"

var spawned: Array[EnemyBase] = []


func _ready() -> void:
	_spawn_wolves()
	_spawn_goblins()
	_spawn_raiders()
	_spawn_adventurers()
	_spawn_ogre()


func spawn(script: Script, type: StringName, pos: Vector3, tags: Array = [], p_variant: int = 0, p_name: String = "") -> EnemyBase:
	if script == null:
		return null
	var e: EnemyBase = script.new()
	var p := Vector3(pos.x, GameState.ground_height(pos.x, pos.z) + 0.05, pos.z)
	e.configure(EnemyStats.create(type), p, tags)
	e.variant = p_variant
	if p_name != "":
		e.display_name = p_name
	e.name = "%s_%d" % [type, spawned.size()]
	e.position = to_local(p) if is_inside_tree() else p
	add_child(e)
	spawned.append(e)
	return e


func _ring(center: Vector3, count: int, radius: float, phase: float = 0.0) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i in count:
		var a := phase + TAU * float(i) / float(count)
		out.append(center + Vector3(cos(a) * radius, 0.0, sin(a) * radius))
	return out


func _spawn_wolves() -> void:
	var c := WorldLayout.WOLF_WOODS
	# two territorial packs of three, slightly off the main path
	for p in _ring(c + Vector3(18, 0, -14), 3, 2.5, 0.3):
		spawn(EnemyWolf, &"wolf", p, [&"pack_a"])
	for p in _ring(c + Vector3(-14, 0, 24), 3, 2.5, 1.1):
		spawn(EnemyWolf, &"wolf", p, [&"pack_b"])
	if not GameState.has_flag(&"alpha_wolf_defeated"):
		var den := WorldLayout.ALPHA_WOLF_DEN
		spawn(EnemyWolf, &"alpha_wolf", den, [&"alpha_den"])
		for p in _ring(den, 2, 4.0, 0.6):
			spawn(EnemyWolf, &"wolf", p, [&"alpha_den"])


func _spawn_goblins() -> void:
	if not GameState.has_flag(&"friend_rescued") and not GameState.has_flag(&"rescue_guards_defeated"):
		var i := 0
		for p in _ring(WorldLayout.RESCUE_SITE, WorldLayout.RESCUE_GUARD_COUNT, 6.0, 0.4):
			spawn(EnemyHumanoid, &"goblin_raider", p, [&"rescue_guard"], i)
			i += 1
	# a few roaming raiders around the ruins and the path to them
	spawn(EnemyHumanoid, &"goblin_raider", WorldLayout.RUINS + Vector3(14, 0, 8), [&"ruins"], 0)
	spawn(EnemyHumanoid, &"goblin_raider", WorldLayout.RUINS + Vector3(18, 0, 3), [&"ruins"], 1)
	spawn(EnemyHumanoid, &"goblin_raider", Vector3(-118, 0, -42), [&"roamer"], 0)


func _spawn_raiders() -> void:
	var c := WorldLayout.RAIDER_OUTPOST
	var i := 0
	for p in _ring(c, 4, 8.0, 0.2):
		spawn(EnemyHumanoid, &"human_raider", p, [&"outpost"], i)
		i += 1
	if not GameState.has_flag(&"raider_captain_defeated"):
		spawn(EnemyHumanoid, &"raider_captain", c + Vector3(2, 0, -2), [&"outpost"])


func _spawn_adventurers() -> void:
	if not ResourceLoader.exists(ADVENTURER_SCRIPT):
		return
	var script: Script = load(ADVENTURER_SCRIPT)
	var names := ["Bram", "Mira", "Thalen"]
	var i := 0
	for p in _ring(WorldLayout.ADVENTURER_CAMP, 3, 3.6, 0.5):
		spawn(script, &"adventurer", p, [&"camp"], i, names[i])
		i += 1


func _spawn_ogre() -> void:
	if GameState.has_flag(&"boss_defeated") or not ResourceLoader.exists(OGRE_SCRIPT):
		return
	spawn(load(OGRE_SCRIPT), &"ogre", WorldLayout.OGRE_CLEARING, [])
