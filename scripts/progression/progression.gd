extends Node
## Experience, levels, stat upgrades, abilities, essences, discoveries,
## inventory and evolution. OWNER: Progression & Quest agent.
##
## ---------------------------------------------------------------- XP BUDGET
## Curve: XP to go from level L to L+1 = 150 + 100 * (L - 1)
##   L1->2: 150, L2->3: 250, L3->4: 350, L4->5: 450  => 1200 total XP for level 5.
##
## Mandatory chapter content (what the quest chain forces):
##   ~4 wolves on the woods path        4 x  20 =   80
##   3 rescue guards (goblin raiders)   3 x  25 =   75
##   ogre (boss)                        1 x 250 =  250
##   rescue Nib                                     75
##   quests 1-4 rewards       50+100+75+150   =  375
##   claim-home step reward                         50
##   landmarks on the way (glade, woods,
##     ogre clearing, cave)             4 x  25 =  100
##                                       total  = 1005  (level 4, ~84 % of the way)
## "A little exploration" closes the gap of 195, e.g.:
##   alpha wolf 80 + 2 more wolves 40 + 3 landmarks 75     = 195  -> level 5
## Everything in the chapter (8 wolves 160, alpha 80, 5 goblin raiders 125,
##   4 human raiders 140, captain 100, ogre 250, 9 landmarks 225, rescue 75,
##   quests 1-4 375, home 50)                              = 1580 (~1.3x the requirement)
## Quest 5 (+200) is only granted after evolving.

const MAX_LEVEL := 20
const SLOT_COUNT := 3

const XP_BY_ENEMY := {
	&"wolf": 20, &"alpha_wolf": 80, &"goblin_raider": 25, &"human_raider": 35,
	&"raider_captain": 100, &"ogre": 250, &"adventurer": 0,
}
const LANDMARK_XP := 25
const SECRET_XP := 10
const RESCUE_XP := 75

# Stats: base + per level (automatic) + per upgrade point, then x stage multiplier.
const BASE := {"health": 100.0, "stamina": 100.0, "energy": 100.0, "attack": 12.0}
const PER_LEVEL := {"health": 8.0, "stamina": 4.0, "energy": 5.0, "attack": 1.0}
const PER_POINT := {"health": 15.0, "stamina": 12.0, "attack": 2.5}
const UPGRADABLE: Array[StringName] = [&"health", &"stamina", &"attack"]

var level := 1
var xp := 0
var upgrade_points := 0
var stage: StringName = &"goblin"            # &"goblin" -> &"hobgoblin" (future: more stages)
var unlocked_abilities: Array[StringName] = []
var equipped: Array[StringName] = [&"", &"", &""]  # ability ids in slots 1..3
var discovered: Array[StringName] = []
var inventory: Dictionary = {}               # StringName item_id -> int
var upgrades: Dictionary = {&"health": 0, &"stamina": 0, &"attack": 0}
var unlocks: Array[StringName] = []          # passive unlocks (shockwave_slam)
var rewards_claimed: Array[StringName] = []  # one-time rewards (rescue, quest xp)


func _ready() -> void:
	SaveManager.register("progression", self)
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.zone_entered.connect(_on_zone_entered)
	Events.friend_rescued.connect(_on_friend_rescued)
	Events.quest_completed.connect(_on_quest_completed)
	Events.interacted.connect(_on_interacted)


# ---------------------------------------------------------------- stats
func _stat(key: String) -> float:
	var v: float = BASE[key] + PER_LEVEL[key] * (level - 1)
	if PER_POINT.has(key):
		v += PER_POINT[key] * int(upgrades.get(StringName(key), 0))
	var mult: Dictionary = ProgressionEvolution.get_stage(stage)["mult"]
	return v * float(mult.get(key, 1.0))


func max_health() -> float: return _stat("health")
func max_stamina() -> float: return _stat("stamina")
func max_energy() -> float: return _stat("energy")
## Base damage for a light attack; heavy attacks multiply this.
func attack_power() -> float: return _stat("attack")


func xp_to_next_level() -> int:
	return xp_required_for(level)


## XP needed to advance from `lvl` to lvl+1.
static func xp_required_for(lvl: int) -> int:
	return 150 + 100 * (maxi(lvl, 1) - 1)


## Total XP needed from level 1 to reach `lvl`.
static func total_xp_for_level(lvl: int) -> int:
	var t := 0
	for l in range(1, lvl):
		t += xp_required_for(l)
	return t


func is_evolved() -> bool: return stage != &"goblin"
func has_ability(id: StringName) -> bool: return unlocked_abilities.has(id)
func get_equipped(slot: int) -> StringName: return equipped[slot] if slot >= 0 and slot < equipped.size() else &""
## Passive unlocks (e.g. &"shockwave_slam" from Hobgoblin evolution).
func has_unlock(id: StringName) -> bool: return unlocks.has(id)
func is_discovered(id: StringName) -> bool: return discovered.has(id)
func get_stage_name() -> String: return String(ProgressionEvolution.get_stage(stage)["name"])
func get_upgrade_level(stat: StringName) -> int: return int(upgrades.get(stat, 0))


# ---------------------------------------------------------------- xp / levels
func add_xp(amount: int, reason: String = "") -> void:
	if amount <= 0 or level >= MAX_LEVEL:
		return
	xp += amount
	Events.xp_gained.emit(amount, reason)
	while level < MAX_LEVEL and xp >= xp_to_next_level():
		xp -= xp_to_next_level()
		level += 1
		upgrade_points += 1
		Events.level_up.emit(level)
		Events.notify.emit("Level up! You are now level %d (+1 upgrade point)" % level, &"xp")
		Audio.play_sfx(&"level_up")
	if level >= MAX_LEVEL:
		xp = 0


## Spend one upgrade point on &"health", &"stamina" or &"attack".
func spend_point(stat: StringName) -> bool:
	if upgrade_points <= 0 or not UPGRADABLE.has(stat):
		return false
	upgrade_points -= 1
	upgrades[stat] = int(upgrades.get(stat, 0)) + 1
	Events.stats_upgraded.emit()
	return true


func _on_enemy_killed(_enemy: Node3D, enemy_type: StringName, _tags: Array) -> void:
	var amount := int(XP_BY_ENEMY.get(enemy_type, 0))
	if amount > 0:
		add_xp(amount, "Defeated %s" % String(enemy_type).replace("_", " "))


func _on_zone_entered(zone_id: StringName) -> void:
	if discovered.has(zone_id):
		return
	if WorldLayout.LANDMARKS.has(zone_id):
		discovered.append(zone_id)
		var nm := String(WorldLayout.LANDMARKS[zone_id].get("name", zone_id))
		Events.landmark_discovered.emit(zone_id)
		Events.notify.emit("Discovered: %s" % nm, &"info")
		add_xp(LANDMARK_XP, "Discovered %s" % nm)
	elif String(zone_id).begins_with("secret_"):
		discovered.append(zone_id)
		Events.landmark_discovered.emit(zone_id)
		Events.notify.emit("You found a secret spot!", &"info")
		add_xp(SECRET_XP, "Secret")


func _on_friend_rescued() -> void:
	if rewards_claimed.has(&"rescue_nib"):
		return
	rewards_claimed.append(&"rescue_nib")
	add_xp(RESCUE_XP, "Protected a friend")


func _on_quest_completed(quest_id: StringName) -> void:
	var q := QuestData.get_quest(quest_id)
	var key := StringName("quest_" + String(quest_id))
	if q.is_empty() or rewards_claimed.has(key):
		return
	rewards_claimed.append(key)
	add_xp(int(q.get("xp", 0)), "Quest: %s" % q.get("title", ""))


# ---------------------------------------------------------------- inventory
func add_item(item_id: StringName, amount: int = 1) -> void:
	if amount <= 0 or item_id == &"":
		return
	inventory[item_id] = int(inventory.get(item_id, 0)) + amount
	Events.item_collected.emit(item_id, amount)


func item_count(item_id: StringName) -> int:
	return int(inventory.get(item_id, 0))


func remove_item(item_id: StringName, amount: int = 1) -> bool:
	if amount <= 0 or item_count(item_id) < amount:
		return false
	inventory[item_id] = item_count(item_id) - amount
	if inventory[item_id] <= 0:
		inventory.erase(item_id)
	return true


# ---------------------------------------------------------------- abilities
func unlock_ability(id: StringName) -> void:
	if not AbilityLibrary.exists(id) or unlocked_abilities.has(id):
		return
	if not AbilityLibrary.is_slottable(id):
		_add_unlock(id)
		return
	unlocked_abilities.append(id)
	var free := equipped.find(&"")
	if free >= 0:
		equipped[free] = id
	var data := AbilityLibrary.get_ability(id)
	Events.ability_unlocked.emit(id)
	# No key names in text: the UI adds per-device input hints.
	Events.notify.emit("Essence absorbed: %s" % data.display_name, &"essence")
	SaveManager.request_autosave()


## Puts an unlocked ability into a slot (swapping if it is already equipped elsewhere).
## Pass &"" to clear a slot.
func equip(slot: int, id: StringName) -> bool:
	if slot < 0 or slot >= SLOT_COUNT:
		return false
	if id != &"" and not unlocked_abilities.has(id):
		return false
	var prev := equipped.find(id) if id != &"" else -1
	if prev >= 0:
		equipped[prev] = equipped[slot]
	equipped[slot] = id
	Events.stats_upgraded.emit()
	return true


func _add_unlock(id: StringName) -> void:
	if unlocks.has(id):
		return
	unlocks.append(id)
	Events.ability_unlocked.emit(id)


# ---------------------------------------------------------------- evolution
func get_next_stage() -> Dictionary:
	var i := ProgressionEvolution.index_of(stage)
	if i < 0 or i + 1 >= ProgressionEvolution.STAGES.size():
		return {}
	return ProgressionEvolution.STAGES[i + 1]


## Human-readable unmet requirements for the next stage ([] when eligible / none left).
func get_missing_requirements() -> Array[String]:
	var out: Array[String] = []
	var nxt := get_next_stage()
	if nxt.is_empty():
		return out
	if level < int(nxt["level"]):
		out.append("reach level %d (now %d)" % [nxt["level"], level])
	var quests := get_node_or_null(^"/root/Quests")
	for qid: StringName in nxt["quests"]:
		if quests == null or not quests.is_quest_completed(qid):
			out.append("complete \"%s\"" % QuestData.get_quest(qid).get("title", qid))
	for f: StringName in nxt["flags"]:
		if not GameState.has_flag(f):
			out.append(String(QuestData.FLAG_HINTS.get(f, String(f).replace("_", " "))))
	return out


func can_evolve() -> bool:
	return not get_next_stage().is_empty() and get_missing_requirements().is_empty()


func evolve() -> bool:
	if not can_evolve():
		return false
	var nxt := get_next_stage()
	stage = nxt["id"]
	for u: StringName in nxt["unlocks"]:
		_add_unlock(u)
	Events.evolution_changed.emit(stage)
	Events.stats_upgraded.emit()
	Events.notify.emit("You evolved into a %s!" % nxt["name"], &"essence")
	Audio.play_sfx(&"evolve")
	SaveManager.request_autosave()
	return true


func _on_interacted(interact_id: StringName, _actor: Node) -> void:
	if interact_id != ProgressionEvolution.ALTAR_ID:
		return
	if can_evolve():
		evolve()
	elif not get_next_stage().is_empty():
		Events.notify.emit("Not ready to evolve: " + ", ".join(get_missing_requirements()), &"warning")


# ---------------------------------------------------------------- save / load
func get_save_data() -> Dictionary:
	var inv := {}
	for k: StringName in inventory:
		inv[String(k)] = int(inventory[k])
	var ups := {}
	for k: StringName in upgrades:
		ups[String(k)] = int(upgrades[k])
	return {
		"level": level, "xp": xp, "upgrade_points": upgrade_points,
		"stage": String(stage),
		"abilities": _to_strings(unlocked_abilities),
		"equipped": _to_strings(equipped),
		"discovered": _to_strings(discovered),
		"inventory": inv, "upgrades": ups,
		"unlocks": _to_strings(unlocks),
		"rewards": _to_strings(rewards_claimed),
	}


static func _to_strings(a: Array) -> Array:
	var out := []
	for v: Variant in a:
		out.append(String(v))
	return out


static func _int(v: Variant, fallback: int) -> int:
	if typeof(v) == TYPE_INT:
		return v
	if typeof(v) == TYPE_FLOAT and is_finite(v):
		return int(clampf(v, -1.0e9, 1.0e9))
	return fallback


static func _is_str(v: Variant) -> bool:
	return typeof(v) == TYPE_STRING or typeof(v) == TYPE_STRING_NAME


static func _string_list(v: Variant) -> Array[StringName]:
	var out: Array[StringName] = []
	if typeof(v) != TYPE_ARRAY:
		return out
	for e: Variant in v:
		if _is_str(e) and not out.has(StringName(e)):
			out.append(StringName(e))
	return out


## Validates every field; anything bad falls back to new-game values.
func load_save_data(d: Dictionary) -> void:
	reset()
	level = clampi(_int(d.get("level"), 1), 1, MAX_LEVEL)
	xp = clampi(_int(d.get("xp"), 0), 0, xp_to_next_level() - 1)
	if level >= MAX_LEVEL:
		xp = 0
	var ups: Variant = d.get("upgrades")
	var spent := 0
	if typeof(ups) == TYPE_DICTIONARY:
		for stat: StringName in UPGRADABLE:
			var n := clampi(_int(ups.get(String(stat)), 0), 0, level - 1 - spent)
			upgrades[stat] = n
			spent += n
	upgrade_points = clampi(_int(d.get("upgrade_points"), 0), 0, level - 1 - spent)
	var st: Variant = d.get("stage", "goblin")
	stage = StringName(st) if _is_str(st) and ProgressionEvolution.index_of(StringName(st)) >= 0 else &"goblin"
	for id in _string_list(d.get("abilities")):
		if AbilityLibrary.is_slottable(id):
			unlocked_abilities.append(id)
	var eq: Variant = d.get("equipped")
	if typeof(eq) == TYPE_ARRAY:
		for i in mini(eq.size(), SLOT_COUNT):
			var id: StringName = StringName(eq[i]) if _is_str(eq[i]) else &""
			if id != &"" and unlocked_abilities.has(id) and not equipped.has(id):
				equipped[i] = id
	for id in _string_list(d.get("discovered")):
		if WorldLayout.LANDMARKS.has(id) or String(id).begins_with("secret_"):
			discovered.append(id)
	var inv: Variant = d.get("inventory")
	if typeof(inv) == TYPE_DICTIONARY:
		for k: Variant in inv:
			var n := _int(inv[k], 0)
			if _is_str(k) and n > 0:
				inventory[StringName(k)] = mini(n, 9999)
	for id in _string_list(d.get("unlocks")):
		if AbilityLibrary.exists(id) and not AbilityLibrary.is_slottable(id):
			unlocks.append(id)
	# Passive unlocks implied by the current stage are always restored.
	for i in ProgressionEvolution.index_of(stage) + 1:
		for u: StringName in ProgressionEvolution.STAGES[i]["unlocks"]:
			if not unlocks.has(u):
				unlocks.append(u)
	rewards_claimed = _string_list(d.get("rewards"))


func reset() -> void:
	level = 1
	xp = 0
	upgrade_points = 0
	stage = &"goblin"
	unlocked_abilities.clear()
	equipped = [&"", &"", &""]
	discovered.clear()
	inventory.clear()
	upgrades = {&"health": 0, &"stamina": 0, &"attack": 0}
	unlocks.clear()
	rewards_claimed.clear()
