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
	print("final pos: ", p.global_position, " on_floor: ", (p as CharacterBody3D).is_on_floor())
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://tests/screens/%s.png" % shot_name)
