class_name ProgressionEvolution
## Data-driven evolution stages, in order. Stage 0 is the starting form.
## Append dictionaries to STAGES to add later forms; no code changes needed.
##   id       StringName stage id (Events.evolution_changed payload)
##   name     display name
##   level    required level
##   quests   quest ids that must be completed (Quests.is_quest_completed)
##   flags    GameState flags that must be set (hint text in QuestData.FLAG_HINTS)
##   mult     stat multipliers {health, stamina, energy, attack}
##   unlocks  passive unlock ids granted on reaching the stage (Progression.has_unlock)

const ALTAR_ID := &"evolution_altar"   # Interactable id that performs the evolution

const STAGES: Array[Dictionary] = [
	{
		"id": &"goblin", "name": "Goblin", "level": 1, "quests": [], "flags": [],
		"mult": {"health": 1.0, "stamina": 1.0, "energy": 1.0, "attack": 1.0},
		"unlocks": [],
	},
	{
		"id": &"hobgoblin", "name": "Hobgoblin", "level": 5,
		"quests": [&"the_ogres_claim"], "flags": [&"home_claimed"],
		"mult": {"health": 1.35, "stamina": 1.2, "energy": 1.2, "attack": 1.3},
		"unlocks": [&"shockwave_slam"],
	},
	# Future stages (not part of Chapter 1) - append when content exists:
	# {"id": &"hob_warlord", "name": "Hob Warlord", "level": 12, "quests": [&"chapter2_finale"], "flags": [], "mult": {...}, "unlocks": []},
	# {"id": &"oni", "name": "Oni", "level": 20, ...},
	# {"id": &"demon_lord", "name": "Demon Lord", "level": 30, ...},
	# {"id": &"demon_emperor", "name": "Demon Emperor", "level": 40, ...},
]


static func index_of(id: StringName) -> int:
	for i in STAGES.size():
		if STAGES[i]["id"] == id:
			return i
	return -1


static func get_stage(id: StringName) -> Dictionary:
	var i := index_of(id)
	return STAGES[i] if i >= 0 else STAGES[0]
