class_name QuestEssenceOrb
extends Area3D
## Floating essence dropped by an essence carrier. Absorbed on touch:
## Progression.unlock_ability(ability_id) + sfx `essence`.

const ARM_DELAY := 0.6

var ability_id: StringName = &""
var _armed_in := ARM_DELAY
var _collected := false
var _visual: Node3D
var _time := 0.0
var _base_y := 0.0


func _init() -> void:
	collision_layer = 0
	collision_mask = Layers.PLAYER
	monitoring = true
	monitorable = false


func _ready() -> void:
	name = "Essence_%s" % ability_id
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 1.2
	cs.shape = s
	add_child(cs)
	var data := AbilityLibrary.get_ability(ability_id)
	var col: Color = data.icon_color if data else Palette.ESSENCE
	_visual = Node3D.new()
	add_child(_visual)
	_base_y = 0.0
	var core := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.22
	sm.height = 0.44
	core.mesh = sm
	core.material_override = Palette.glow(col.lightened(0.35), 4.0)
	_visual.add_child(core)
	var halo := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.42
	hm.height = 0.84
	halo.mesh = hm
	halo.material_override = Palette.glow(col, 1.5, true)
	halo.transparency = 0.7
	_visual.add_child(halo)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.5
	tm.outer_radius = 0.56
	ring.mesh = tm
	ring.material_override = Palette.glow(Palette.ESSENCE, 2.0, true)
	ring.rotation.x = 0.5
	_visual.add_child(ring)
	for m: GeometryInstance3D in [core, halo, ring]:
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light := OmniLight3D.new()
	light.light_color = col
	light.light_energy = 1.5
	light.omni_range = 4.0
	add_child(light)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta
	if _visual:
		_visual.position.y = _base_y + sin(_time * 2.2) * 0.15
		_visual.rotation.y += delta * 1.5
	if _armed_in > 0.0:
		_armed_in -= delta
		if _armed_in <= 0.0:
			for b in get_overlapping_bodies():
				_on_body_entered(b)


func _on_body_entered(body: Node3D) -> void:
	if _armed_in > 0.0 or _collected or not body.is_in_group("player"):
		return
	collect()


func collect() -> void:
	if _collected:
		return
	_collected = true
	Progression.unlock_ability(ability_id)
	Audio.play_sfx(&"essence", global_position)
	set_deferred("monitoring", false)
	if is_inside_tree():
		var tw := create_tween()
		tw.tween_property(_visual, "scale", Vector3.ONE * 2.5, 0.25)
		tw.tween_property(_visual, "scale", Vector3.ZERO, 0.15)
		tw.tween_callback(queue_free)
	else:
		queue_free()
