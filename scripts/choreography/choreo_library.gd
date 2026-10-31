class_name ChoreoLibrary
## Weapon moveset registry. All attack timing, reach, hitboxes, footwork, grips,
## trails, guard values and key poses live in data under
## scripts/choreography/movesets/<type>.gd (static func data() -> Dictionary).
## The Player resolves a move ONCE at attack start (so an equip change cannot
## alter an attack halfway through) and the model animates from the same dict.
##
## Adding a weapon: create movesets/<type>.gd following knife.gd, register it in
## SOURCES, add its mesh to ChoreoWeapons.build() (unless the model owns it) and run
## tests/player_test.tscn (it validates every moveset) + tests/choreo_preview.tscn.
##
## Moveset keys:
##   id, label, slot (&"none"/&"knife"/&"main"/&"ranged"), category (&"edge"/&"point"/
##   &"blunt"/&"ranged"/&"none"), hands (1|2), stages (allowed evolution stages),
##   grip {main_hand, off_role (&"guard"/&"balance"/&"aim")} (two-hand grips: future),
##   carry (pose overlay at rest), move (locomotion arm tuning), guard {reduction,
##   pose}, stow {parent, pos, dir, up}, cast {free_hand},
##   light (Array of moves = combo chain), heavy (move).
## Move keys:
##   id, anim (model action name), attack_id (DamageInfo.attack_id), heavy (bool),
##   windup / active / recovery (s), chain_open (fraction of recovery after which a
##   buffered input chains), mult, stagger, knock, stamina,
##   footwork {lunge (m travelled from active start), time (s)}; the controller
##   applies it once as body velocity; poses never translate the root,
##   hitbox {size, offset} at Goblin scale in facing space (-Z forward); reach =
##   -offset.z + size.z/2 must match the visible weapon tip at contact,
##   trail {style &"arc"/&"thrust"/&"none", ...}, projectile {speed, range, radius}
##   (ranged moves spawn ChoreoSlingStone instead of using the melee hitbox),
##   poses {name: {joint: Vector3|float}}, curve [[phase, pose, ease?], ...]
##   (see ChoreoPose), sfx.

const SOURCES := {
	&"unarmed": preload("res://scripts/choreography/movesets/unarmed.gd"),
	&"knife": preload("res://scripts/choreography/movesets/knife.gd"),
	&"sword": preload("res://scripts/choreography/movesets/sword.gd"),
	&"sling": preload("res://scripts/choreography/movesets/sling.gd"),
}

## Debug order (numpad 1..4 in the playground).
const DEBUG_ORDER: Array[StringName] = [&"knife", &"sword", &"sling", &"unarmed"]

static var _cache: Dictionary = {}


static func types() -> Array[StringName]:
	var out: Array[StringName] = []
	for k: StringName in SOURCES:
		out.append(k)
	return out


static func has(type: StringName) -> bool:
	return SOURCES.has(type)


static func moveset(type: StringName) -> Dictionary:
	if not SOURCES.has(type):
		type = &"unarmed"
	if not _cache.has(type):
		_cache[type] = _prepare(SOURCES[type].data())
	return _cache[type]


static func light_chain(type: StringName) -> Array:
	return moveset(type)["light"]


static func heavy(type: StringName) -> Dictionary:
	return moveset(type)["heavy"]


## Finds a move by its model action name (e.g. &"punch1", &"light2").
static func find_move(type: StringName, anim: StringName) -> Dictionary:
	var ms := moveset(type)
	for m: Dictionary in ms["light"]:
		if m["anim"] == anim:
			return m
	if ms["heavy"]["anim"] == anim:
		return ms["heavy"]
	for t: StringName in SOURCES:
		if t == type:
			continue
		var other := moveset(t)
		for m: Dictionary in other["light"]:
			if m["anim"] == anim:
				return m
		if other["heavy"]["anim"] == anim:
			return other["heavy"]
	return {}


## Stage/loadout rule (docs/BACKLOG.md "Stage-specific carried loadouts").
static func can_equip(type: StringName, stage: StringName) -> bool:
	if not SOURCES.has(type):
		return false
	var stages: Array = moveset(type).get("stages", [])
	return stages.is_empty() or stages.has(stage)


## Horizontal reach of the melee hitbox in front of the body centre (Goblin scale).
static func reach(move: Dictionary) -> float:
	if move.has("projectile"):
		return float(move["projectile"]["range"])
	var hb: Dictionary = move["hitbox"]
	return -(hb["offset"] as Vector3).z + (hb["size"] as Vector3).z * 0.5


static func lunge_distance(move: Dictionary) -> float:
	return float(move.get("footwork", {}).get("lunge", 0.0))


static func _prepare(ms: Dictionary) -> Dictionary:
	for key in ["carry", "move"]:
		if ms.has(key):
			ms[key] = ChoreoPose.normalize(ms[key])
	if ms.has("guard"):
		ms["guard"]["pose"] = ChoreoPose.normalize(ms["guard"].get("pose", {}))
	if ms.has("cast_poses"):
		for k: String in ms["cast_poses"]:
			ms["cast_poses"][k] = ChoreoPose.normalize(ms["cast_poses"][k])
	var moves: Array = ms["light"].duplicate()
	moves.append(ms["heavy"])
	for m: Dictionary in moves:
		var poses: Dictionary = m.get("poses", {})
		for k: String in poses:
			poses[k] = ChoreoPose.normalize(poses[k])
		m["moveset"] = ms["id"]
	return ms


## Returns a list of problems (empty = valid). Used by tests.
static func validate(type: StringName) -> PackedStringArray:
	var errs := PackedStringArray()
	var ms := moveset(type)
	for k in ["id", "slot", "hands", "light", "heavy", "guard", "carry"]:
		if not ms.has(k):
			errs.append("%s: missing %s" % [type, k])
	if not errs.is_empty():
		return errs
	if (ms["light"] as Array).is_empty():
		errs.append("%s: empty light chain" % type)
	var moves: Array = ms["light"].duplicate()
	moves.append(ms["heavy"])
	for m: Dictionary in moves:
		var id := "%s/%s" % [type, m.get("id", "?")]
		for k in ["anim", "attack_id", "windup", "active", "recovery", "mult", "stagger", "knock", "stamina", "poses", "curve", "trail"]:
			if not m.has(k):
				errs.append("%s: missing %s" % [id, k])
		if not m.has("hitbox") and not m.has("projectile"):
			errs.append("%s: needs hitbox or projectile" % id)
		if float(m.get("active", 0.0)) <= 0.0:
			errs.append("%s: zero active window" % id)
		var last := 0.0
		var has_contact := false
		for key: Array in m.get("curve", []):
			if float(key[0]) < last:
				errs.append("%s: curve not sorted" % id)
			last = float(key[0])
			if key[1] != "rest" and not (m["poses"] as Dictionary).has(key[1]):
				errs.append("%s: unknown pose %s" % [id, key[1]])
			if key[1] == "contact":
				has_contact = true
				# Visible contact must land inside the active window.
				if float(key[0]) < 1.0 or float(key[0]) > 2.0:
					errs.append("%s: contact key outside active window (%.2f)" % [id, key[0]])
		if not has_contact:
			errs.append("%s: no contact key" % id)
		if last < 3.0:
			errs.append("%s: curve must end at 3.0 (rest)" % id)
		if m.has("hitbox"):
			var r := reach(m)
			if r <= 0.2 or r > 2.2:
				errs.append("%s: implausible reach %.2f" % [id, r])
	return errs
