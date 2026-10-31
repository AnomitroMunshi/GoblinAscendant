extends Node
## Windowed smoke test for the player-only build: boots main.tscn, drives the
## player a little and saves screenshots to tests/screens/.

var _main: Node


func _ready() -> void:
	GameState.show_title = false
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/screens"))
	await _frames(60)
	await _shot("playground_spawn")
	var p: Node3D = GameState.player
	print("spawn pos: ", p.global_position, " state: ", p.call("get_state_name") if p.has_method("get_state_name") else "?")
	Input.action_press(&"move_forward")
	await _frames(90)
	print("after run pos: ", p.global_position, " vel: ", (p as CharacterBody3D).velocity)
	await _shot("playground_running")
	Input.action_press(&"sprint")
	Input.action_press(&"jump")
	await _frames(12)
	Input.action_release(&"jump")
	await _shot("playground_jump")
	await _frames(60)
	Input.action_release(&"sprint")
	Input.action_release(&"move_forward")
	Input.action_press(&"attack_heavy")
	await _frames(2)
	Input.action_release(&"attack_heavy")
	await _frames(22)
	await _shot("playground_heavy")
	await _frames(40)
	await get_tree().create_timer(1.2).timeout
	Input.action_press(&"holster")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(&"holster")
	await get_tree().create_timer(0.15).timeout
	await _shot("playground_holstered")
	Input.action_press(&"attack_light")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(&"attack_light")
	await get_tree().create_timer(0.13).timeout
	await _shot("playground_punch")
	await get_tree().create_timer(0.6).timeout
	Input.action_press(&"attack_heavy")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(&"attack_heavy")
	await get_tree().create_timer(0.3).timeout
	await _shot("playground_kick")
	await get_tree().create_timer(0.6).timeout
	print("final pos: ", p.global_position, " on_floor: ", (p as CharacterBody3D).is_on_floor())
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://tests/screens/%s.png" % shot_name)
