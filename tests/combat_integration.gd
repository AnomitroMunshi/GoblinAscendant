extends Node
## Integration probe (Combat agent): loads the real main scene and checks every
## spawned enemy stands on the terrain. Run:
##   Godot --headless --fixed-fps 60 --path . res://tests/combat_integration.tscn -- --full


func _ready() -> void:
	GameState.show_title = false
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	for i in 240:
		await get_tree().physics_frame
	var bad := 0
	var n := 0
	var by_type := {}
	for e in get_tree().get_nodes_in_group(&"actors"):
		if not (e is EnemyBase):
			continue
		n += 1
		var en := e as EnemyBase
		by_type[en.enemy_type] = int(by_type.get(en.enemy_type, 0)) + 1
		var gh := GameState.ground_height(en.global_position.x, en.global_position.z)
		if absf(en.global_position.y - gh) > 1.0 or not en.global_position.is_finite():
			bad += 1
			print("  OFF-GROUND ", en.name, " y=", en.global_position.y, " ground=", gh)
	print("enemies=", n, " types=", by_type, " off_ground=", bad, " in_combat=", GameState.in_combat())
	get_tree().quit(1 if bad > 0 or n == 0 else 0)
