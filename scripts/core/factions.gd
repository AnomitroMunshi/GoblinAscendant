extends Node
## Faction relationships. Race never decides hostility: factions and
## individual grudges do. Lead-owned.
##
## Rules:
##  * relation(a, b) is symmetric; same faction => FRIENDLY; unlisted => NEUTRAL.
##  * An actor may hold an individual grudge against a specific node
##    (e.g. a neutral adventurer the player attacked). Actors expose
##    `has_grudge(node) -> bool`; is_hostile() honours it.
##  * can_damage(): anything that is not FRIENDLY can be damaged, so the
##    player CAN strike a neutral (which provokes that individual only).

enum Relation { HOSTILE, NEUTRAL, FRIENDLY }

const PLAYER := &"player"
const FRIEND := &"goblin_friend"
const WOLF := &"wolf"
const GOBLIN_RAIDER := &"goblin_raider"
const HUMAN_RAIDER := &"human_raider"
const ADVENTURER := &"adventurer"
const OGRE := &"ogre"

var _table: Dictionary = {}


func _ready() -> void:
	set_relation(PLAYER, FRIEND, Relation.FRIENDLY)
	set_relation(PLAYER, ADVENTURER, Relation.NEUTRAL)
	for f in [WOLF, GOBLIN_RAIDER, HUMAN_RAIDER, OGRE]:
		set_relation(PLAYER, f, Relation.HOSTILE)
		set_relation(FRIEND, f, Relation.HOSTILE)
	set_relation(HUMAN_RAIDER, ADVENTURER, Relation.HOSTILE)
	set_relation(WOLF, ADVENTURER, Relation.HOSTILE)
	# Monsters ignore one another so fights stay readable around the player.
	set_relation(WOLF, GOBLIN_RAIDER, Relation.NEUTRAL)
	set_relation(OGRE, WOLF, Relation.NEUTRAL)


func _key(a: StringName, b: StringName) -> String:
	return "%s|%s" % [a, b] if String(a) < String(b) else "%s|%s" % [b, a]


func set_relation(a: StringName, b: StringName, r: Relation) -> void:
	_table[_key(a, b)] = r


func relation(a: StringName, b: StringName) -> Relation:
	if a == b:
		return Relation.FRIENDLY
	return _table.get(_key(a, b), Relation.NEUTRAL)


func faction_of(node: Object) -> StringName:
	if node and is_instance_valid(node) and node.has_method("get_faction"):
		return node.get_faction()
	return &""


## True when `a` should treat `b` as an enemy (faction or personal grudge).
func is_hostile(a: Object, b: Object) -> bool:
	if not (a and b and is_instance_valid(a) and is_instance_valid(b)) or a == b:
		return false
	if a.has_method("has_grudge") and a.has_grudge(b):
		return true
	return relation(faction_of(a), faction_of(b)) == Relation.HOSTILE


func can_damage(attacker: Object, target: Object) -> bool:
	if not (target and is_instance_valid(target)) or attacker == target:
		return false
	if target.has_method("is_dead") and target.is_dead():
		return false
	if not (attacker and is_instance_valid(attacker)):
		return true  # environmental damage
	if attacker.has_method("has_grudge") and attacker.has_grudge(target):
		return true
	return relation(faction_of(attacker), faction_of(target)) != Relation.FRIENDLY
