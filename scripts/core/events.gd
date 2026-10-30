extends Node
## Global signal bus. Owned by the lead developer.
## Systems communicate through these signals instead of hard references.
## Request new signals from the lead rather than editing this file.

@warning_ignore_start("unused_signal")

# --- Game flow ---
signal game_started                         # every part of main.tscn has been built
signal game_saved
signal game_loaded
signal notify(text: String, kind: StringName)   # toast: kind = &"info", &"quest", &"xp", &"warning", &"essence"

# --- Player ---
signal player_spawned(player: Node3D)
signal player_stats_changed(hp: float, max_hp: float, stamina: float, max_stamina: float, energy: float, max_energy: float)
signal player_damaged(info: DamageInfo)
signal player_died
signal player_respawned
signal lock_target_changed(target: Node3D)  # null when lock released
signal interaction_prompt_changed(text: String)  # "" hides the prompt

# --- Combat / actors ---
signal actor_damaged(actor: Node3D, info: DamageInfo)
signal actor_provoked(actor: Node3D, by: Node3D)
signal enemy_killed(enemy: Node3D, enemy_type: StringName, tags: Array)
signal essence_dropped(ability_id: StringName, position: Vector3)
signal boss_engaged(boss: Node3D)
signal boss_health_changed(current: float, maximum: float)
signal boss_disengaged(boss: Node3D)
signal boss_defeated(boss: Node3D)

# --- World / interaction ---
signal zone_entered(zone_id: StringName)
signal zone_exited(zone_id: StringName)
signal interacted(interact_id: StringName, actor: Node)
signal item_collected(item_id: StringName, amount: int)
signal landmark_discovered(landmark_id: StringName)
signal checkpoint_reached(checkpoint_id: StringName)

# --- Progression / abilities ---
signal xp_gained(amount: int, reason: String)
signal level_up(new_level: int)
signal stats_upgraded
signal ability_unlocked(ability_id: StringName)
signal ability_used(slot: int, ability_id: StringName)
signal ability_failed(slot: int, reason: String)
signal evolution_changed(stage: StringName)

# --- Quests ---
signal quest_started(quest_id: StringName)
signal quest_updated(quest_id: StringName)
signal quest_completed(quest_id: StringName)
signal objective_changed(text: String)
signal friend_rescued
signal home_claimed
signal chapter_completed

# --- Feel ---
signal camera_shake(strength: float)

# --- Device-agnostic input ---
## Camera look delta from non-mouse sources (touch drag on mobile), already in
## degrees (yaw, pitch); positive x turns right, positive y looks down.
## The camera adds it directly, honouring invert_y.
signal look_input(delta_degrees: Vector2)
## The app lost focus / was backgrounded (mobile) — UI opens the pause menu.
signal app_suspended

@warning_ignore_restore("unused_signal")
