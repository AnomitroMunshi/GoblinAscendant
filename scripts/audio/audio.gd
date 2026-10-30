extends Node
## Audio service. OWNER: UI & Audio agent. (Lead stub: public API only.)
## Every call must be safe when a sound is missing: never error, just skip.
##
## SFX ids: footstep, jump, land, swing_light, swing_heavy, hit, hit_heavy,
##   block, dodge, player_hurt, death, wolf_growl, wolf_howl, enemy_warn,
##   ogre_roar, ogre_slam, pickup, essence, level_up, quest_complete,
##   ui_click, ui_open, dash, stone_guard, flame, evolve, splash
## Loop ids (spatial): river_loop, waterfall_loop, fire_loop
## Music: &"explore", &"boss", &"title", &"none"


## Play a one-shot. `position` = Vector3 for 3D spatial playback, null for 2D.
func play_sfx(_id: StringName, _position: Variant = null, _volume_db: float = 0.0, _pitch_variation: float = 0.08) -> void:
	pass


## Create a looping spatial emitter parented to `parent` (river, waterfall, campfire).
## Returns the AudioStreamPlayer3D or null if unavailable.
func create_loop(_id: StringName, _parent: Node3D, _unit_size: float = 10.0, _volume_db: float = 0.0) -> Node3D:
	return null


func play_music(_track: StringName) -> void:
	pass
