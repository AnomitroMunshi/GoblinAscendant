class_name QuestData
## ALL quest + dialogue content for the game, as plain data.
## Add story content here; QuestManager (the `Quests` autoload) and QuestWorld
## interpret it without code changes.
##
## QUEST  { id, title, summary, xp (reward on completion), requires: [quest ids],
##          steps: [STEP...], on_complete: [ACTION...] }
## STEP   { text: objective line ("{n}/{count}" progress is appended automatically
##                when count > 1 or type == level),
##          type:  zone      target = zone id (landmark keys, rescue_site, secret_*...)
##                 interact  target = Interactable.interact_id (only counts while active)
##                 kill_tag  target = tag in Events.enemy_killed tags
##                 kill_type target = enemy_type
##                 collect   target = item id (inventory count or pickups while active)
##                 flag      target = GameState flag
##                 level     count  = required level
##                 stage     target = evolution stage id (Progression.stage)
##          target, count (default 1),
##          pos: Vector3 compass target (optional), or
##          positions + position_flag_prefix: nearest spot whose flag <prefix><i> is unset,
##          on_complete: [ACTION...] }
## ACTION { set_flag: id } | { give_xp: n } | { notify: text, kind? } |
##        { checkpoint: id } | { emit: friend_rescued | home_claimed | chapter_completed }
##        | { sfx: id }

const SUPPLY_ITEM := &"supplies"

## Supply pickups placed by QuestWorld (flag "supply_<index>" when taken).
## SUPPLIES[i] is placed at SUPPLY_POSITIONS[i] (cave mouth, clearing edge, ruins).
const SUPPLIES: Array[Dictionary] = [
	{"name": "Mushroom basket", "kind": "basket"},
	{"name": "Firewood bundle", "kind": "firewood"},
	{"name": "Old blanket", "kind": "blanket"},
]
const SUPPLY_POSITIONS: Array[Vector3] = [Vector3(168, 0, -166), Vector3(80, 0, -112), Vector3(-70, 0, -80)]

## Positions of quest props (QuestWorld). Y is resolved with GameState.ground_height.
const SIGNPOST_POS := Vector3(-18, 0, 178)
## First movement objective: the glade's north edge, ~28 m from the spawn point
## (the spawn sits inside the glade landmark zone, so that zone can't be the goal).
const GLADE_EDGE_POS := Vector3(-8, 0, 158)
const NIB_RESCUE_POS := Vector3(-148, 0, 12)
const NIB_HOME_POS := Vector3(191, 0, -194)
const HEARTH_POS := WorldLayout.CAVE_INTERIOR
const SHRINE_POS := WorldLayout.RUINS_SHRINE

## Essence fallbacks: if the carrier is dead (flag) but the essence was never absorbed
## (e.g. saved before pickup), QuestWorld respawns the orb here.
const ESSENCE_SOURCES := {
	&"wolf_dash": {"flag": &"alpha_wolf_defeated", "pos": WorldLayout.ALPHA_WOLF_DEN},
	&"flame_burst": {"flag": &"raider_captain_defeated", "pos": WorldLayout.RAIDER_OUTPOST},
}

## Hints for evolution/flag requirements shown at the altar.
const FLAG_HINTS := {
	&"home_claimed": "claim the cave as your home",
	&"boss_defeated": "defeat the ogre",
}

## One-liners (shown with Events.notify(text, &"quest")).
const LINES := {
	"signpost": "The sign reads: \"West - Howling Woods. Mind the raiders!\"",
	"nib_injured": "Nib: \"Ow... they jumped me. Please, be careful!\"",
	"nib_guarded": "Nib: \"Behind you - the raiders are still here!\"",
	"nib_rescued": "Nib: \"You came for me! I'll find us shelter... somewhere safe.\"",
	"nib_home": "Nib: \"Home sweet home! Thank you, friend.\"",
	"nib_home_waiting": "Nib: \"This cave would be perfect... if the ogre weren't next door.\"",
	"shrine_use": "The rune flares. Stone strength flows into you.",
	"shrine_spent": "The shrine is quiet now.",
	"hearth_cold": "A cold firepit. This cave isn't safe while the ogre roams.",
	"hearth_rest": "The fire crackles warmly. This is home.",
}

## Prompts for quest props.
const PROMPTS := {
	"signpost": "Read signpost",
	"nib_injured": "Help Nib up",
	"nib_talk": "Talk to Nib",
	"supply": "Pick up %s",
	"shrine": "Touch the rune",
	"shrine_spent": "Quiet shrine",
	"hearth_cold": "Cold firepit",
	"hearth_claim": "Claim the cave as home",
	"hearth_evolve": "Evolve into %s",
	"hearth_locked": "Evolve: %s",
	"hearth_rest": "Warm hearth",
}

const QUESTS: Array[Dictionary] = [
	{
		"id": &"a_small_beginning", "title": "A Small Beginning", "xp": 50, "requires": [],
		"summary": "Get your bearings in the glade.",
		"steps": [
			{"text": "Walk to the north edge of the glade", "type": "zone", "target": &"glade_edge", "pos": GLADE_EDGE_POS},
			{"text": "Read the signpost", "type": "interact", "target": &"glade_signpost", "pos": SIGNPOST_POS,
				"on_complete": [{"notify": "Someone is crying for help in the woods to the west..."}]},
		],
	},
	{
		"id": &"a_friend_in_trouble", "title": "A Friend in Trouble", "xp": 100, "requires": [&"a_small_beginning"],
		"summary": "A fellow goblin needs help.",
		"steps": [
			{"text": "Find the injured goblin", "type": "zone", "target": &"rescue_site", "pos": WorldLayout.RESCUE_SITE,
				"on_complete": [{"notify": "Nib: \"Help! Raiders!\""}, {"checkpoint": &"woods_edge"}]},
			{"text": "Defeat the raiders", "type": "kill_tag", "target": &"rescue_guard",
				"count": WorldLayout.RESCUE_GUARD_COUNT, "pos": WorldLayout.RESCUE_SITE,
				"on_complete": [{"set_flag": &"rescue_guards_defeated"}]},
			{"text": "Help Nib up", "type": "interact", "target": &"nib_rescue", "pos": NIB_RESCUE_POS,
				"on_complete": [{"set_flag": &"friend_rescued"}, {"emit": "friend_rescued"}]},
		],
	},
	{
		"id": &"a_place_to_belong", "title": "A Place to Belong", "xp": 75, "requires": [&"a_friend_in_trouble"],
		"summary": "Nib heard of a cave to the north-east.",
		"steps": [
			{"text": "Find the cave in the north-east", "type": "zone", "target": &"cave", "pos": WorldLayout.CAVE_ENTRANCE},
			{"text": "Gather supplies", "type": "collect", "target": SUPPLY_ITEM, "count": 3,
				"positions": SUPPLY_POSITIONS, "position_flag_prefix": "supply_"},
		],
	},
	{
		"id": &"the_ogres_claim", "title": "The Ogre's Claim", "xp": 150, "requires": [&"a_place_to_belong"],
		"summary": "An ogre claims the clearing before the cave.",
		"steps": [
			{"text": "Defeat the ogre", "type": "flag", "target": &"boss_defeated", "pos": WorldLayout.OGRE_CLEARING,
				"on_complete": [{"checkpoint": &"clearing_edge"}]},
		],
	},
	{
		"id": &"something_greater", "title": "Something Greater", "xp": 200, "requires": [&"the_ogres_claim"],
		"summary": "Make the cave a home, and grow strong enough to protect it.",
		"steps": [
			{"text": "Claim the cave as home", "type": "interact", "target": &"cave_hearth", "pos": HEARTH_POS,
				"on_complete": [{"set_flag": &"home_claimed"}, {"emit": "home_claimed"}, {"checkpoint": &"home"},
					{"give_xp": 50}, {"notify": "The hearth blazes to life. Welcome home."}]},
			{"text": "Reach level 5", "type": "level", "count": 5},
			{"text": "Evolve at the hearth", "type": "stage", "target": &"hobgoblin", "pos": HEARTH_POS},
		],
		"on_complete": [{"emit": "chapter_completed"}, {"notify": "Chapter 1 complete", "kind": &"quest"}],
	},
]


static func get_quest(id: StringName) -> Dictionary:
	for q: Dictionary in QUESTS:
		if q["id"] == id:
			return q
	return {}


static func line(key: String) -> String:
	return String(LINES.get(key, ""))


static func prompt(key: String) -> String:
	return String(PROMPTS.get(key, ""))
