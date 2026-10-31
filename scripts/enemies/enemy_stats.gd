class_name EnemyStats
extends Resource
## Tunable stat block for one enemy / NPC type. Combat agent.
## Built in code by EnemyStats.create(type) so designers can tweak numbers in
## one table without touching behaviour code.

@export var enemy_type: StringName = &"wolf"
@export var display_name := "Wolf"
@export var faction: StringName = &"wolf"
@export var max_health := 40.0
@export var damage := 8.0               # base damage of the standard attack
@export var move_speed := 2.2           # walk / patrol speed (m/s)
@export var chase_speed := 6.0          # run speed while chasing (m/s)
@export var turn_speed := 8.0           # rad/s
@export var detection_radius := 16.0    # sight radius inside the FOV cone
@export var proximity_radius := 2.0     # always detected (no LOS needed) inside this
@export var fov_degrees := 140.0
@export var attack_range := 2.0         # preferred distance to start attacks
@export var hold_distance := 4.5        # ring distance while waiting for an attack token
@export var leash_radius := 32.0        # max distance from home while chasing
@export var patrol_radius := 8.0        # wander radius around home (0 = stand still)
@export var aggression := 1.0           # 0 = never initiates (neutral), 1 = attacks hostiles on sight
@export var xp_tag: StringName = &"xp_small"
@export var essence_id: StringName = &""
@export var defeat_flag: StringName = &""
@export var telegraph_time := 0.5       # wind-up of the standard attack (s)
@export var recovery_time := 0.7        # vulnerable recovery after attacks (s)
@export var poise := 5.0                # stagger points before HURT (DamageInfo.stagger*10 per hit)
@export var model_scale := 1.0
@export var body_radius := 0.45
@export var body_height := 1.0
@export var knockback_resist := 0.0     # 0 = full knockback, 1 = immovable
@export var regen_per_sec := 0.25       # fraction of max HP per second while RETURNing
@export var ally_assist_radius := 12.0  # same-faction actors this close join a fight
@export var lose_target_time := 4.0
@export var flee_health_ratio := 0.0    # > 0: retreat briefly once when HP drops below
@export var block_chance := 0.0         # chance per decision to raise a guard
@export var is_elite := false
@export var is_boss := false
@export var tags: Array[StringName] = []


static func create(type: StringName) -> EnemyStats:
	var s := EnemyStats.new()
	s.enemy_type = type
	match type:
		&"wolf":
			s.display_name = "Wolf"
			s.faction = Factions.WOLF
			s.max_health = 38.0
			s.damage = 8.0
			s.move_speed = 2.4
			s.chase_speed = 7.0
			s.turn_speed = 9.0
			s.detection_radius = 17.0
			s.fov_degrees = 150.0
			s.attack_range = 3.4
			s.hold_distance = 5.5
			s.leash_radius = 34.0
			s.patrol_radius = 9.0
			s.telegraph_time = 0.5
			s.recovery_time = 0.8
			s.poise = 5.0
			s.body_radius = 0.45
			s.body_height = 0.95
			s.tags = [&"beast"]
		&"alpha_wolf":
			s.display_name = "Alpha Wolf"
			s.faction = Factions.WOLF
			s.max_health = 150.0
			s.damage = 13.0
			s.move_speed = 2.6
			s.chase_speed = 7.4
			s.turn_speed = 8.0
			s.detection_radius = 22.0
			s.fov_degrees = 160.0
			s.proximity_radius = 2.5
			s.attack_range = 4.4
			s.hold_distance = 6.0
			s.leash_radius = 30.0
			s.patrol_radius = 6.0
			s.telegraph_time = 0.65
			s.recovery_time = 0.9
			s.poise = 14.0
			s.model_scale = 1.4
			s.body_radius = 0.6
			s.body_height = 1.3
			s.knockback_resist = 0.4
			s.ally_assist_radius = 25.0  # howl radius
			s.xp_tag = &"xp_elite"
			s.essence_id = &"wolf_dash"
			s.defeat_flag = &"alpha_wolf_defeated"
			s.is_elite = true
			s.tags = [&"beast", &"elite", &"essence_carrier"]
		&"goblin_raider":
			s.display_name = "Goblin Raider"
			s.faction = Factions.GOBLIN_RAIDER
			s.max_health = 48.0
			s.damage = 8.0
			s.move_speed = 2.0
			s.chase_speed = 5.4
			s.detection_radius = 14.0
			s.fov_degrees = 120.0
			s.attack_range = 1.7
			s.hold_distance = 4.0
			s.leash_radius = 28.0
			s.patrol_radius = 5.0
			s.telegraph_time = 0.42   # quick attacks
			s.recovery_time = 0.6
			s.poise = 6.0
			s.body_radius = 0.35
			s.body_height = 1.15
			s.flee_health_ratio = 0.3
			s.tags = [&"goblinoid"]
		&"human_raider":
			s.display_name = "Raider"
			s.faction = Factions.HUMAN_RAIDER
			s.max_health = 70.0
			s.damage = 12.0
			s.move_speed = 2.0
			s.chase_speed = 5.0
			s.detection_radius = 16.0
			s.fov_degrees = 120.0
			s.attack_range = 2.0
			s.hold_distance = 4.5
			s.leash_radius = 30.0
			s.patrol_radius = 6.0
			s.telegraph_time = 0.62   # deliberate
			s.recovery_time = 0.8
			s.poise = 8.0
			s.body_radius = 0.4
			s.body_height = 1.8
			s.block_chance = 0.35
			s.tags = [&"human"]
		&"raider_captain":
			s.display_name = "Raider Captain"
			s.faction = Factions.HUMAN_RAIDER
			s.max_health = 190.0
			s.damage = 15.0
			s.move_speed = 2.0
			s.chase_speed = 5.3
			s.detection_radius = 18.0
			s.fov_degrees = 130.0
			s.attack_range = 2.2
			s.hold_distance = 5.0
			s.leash_radius = 26.0
			s.patrol_radius = 3.0
			s.telegraph_time = 0.65
			s.recovery_time = 0.9
			s.poise = 16.0
			s.model_scale = 1.12
			s.body_radius = 0.45
			s.body_height = 2.0
			s.knockback_resist = 0.4
			s.block_chance = 0.2
			s.xp_tag = &"xp_elite"
			s.essence_id = &"flame_burst"
			s.defeat_flag = &"raider_captain_defeated"
			s.is_elite = true
			s.tags = [&"human", &"elite", &"essence_carrier"]
		&"adventurer":
			s.display_name = "Adventurer"
			s.faction = Factions.ADVENTURER
			s.max_health = 80.0
			s.damage = 10.0
			s.move_speed = 1.3
			s.chase_speed = 5.0
			s.detection_radius = 14.0
			s.fov_degrees = 120.0
			s.attack_range = 2.0
			s.hold_distance = 4.0
			s.leash_radius = 24.0
			s.patrol_radius = 6.0
			s.aggression = 0.0
			s.telegraph_time = 0.6
			s.recovery_time = 0.8
			s.poise = 8.0
			s.body_radius = 0.4
			s.body_height = 1.8
			s.regen_per_sec = 0.15
			s.xp_tag = &"no_xp"
			s.tags = [&"human", &"neutral"]
		&"ogre":
			s.display_name = "Grukk the Ogre"
			s.faction = Factions.OGRE
			s.max_health = 560.0
			s.damage = 26.0
			s.move_speed = 1.8
			s.chase_speed = 3.4
			s.turn_speed = 2.6
			s.detection_radius = 30.0
			s.fov_degrees = 360.0
			s.proximity_radius = 6.0
			s.attack_range = 4.2
			s.hold_distance = 5.0
			s.leash_radius = WorldLayout.OGRE_ARENA_RADIUS + 2.0
			s.patrol_radius = 6.0
			s.telegraph_time = 1.1
			s.recovery_time = 1.4
			s.poise = 60.0
			s.body_radius = 1.0
			s.body_height = 3.4
			s.knockback_resist = 0.95
			s.regen_per_sec = 1.0
			s.ally_assist_radius = 0.0
			s.xp_tag = &"xp_boss"
			s.defeat_flag = &"boss_defeated"
			s.is_boss = true
			s.tags = [&"boss", &"giant"]
		_:
			push_warning("EnemyStats: unknown type '%s', using defaults." % type)
	return s
