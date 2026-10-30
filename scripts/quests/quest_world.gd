extends Node3D
## Quest props placed in the world (built by main.gd after World/Player/Actors).
## OWNER: Progression & Quest agent. Positions/text come from QuestData.
## Respects saved state: collected supplies stay gone, Nib waits at home once
## rescued, the hearth burns once home is claimed, the shrine stays spent.

const REFRESH_INTERVAL := 0.4

var nib: QuestFriend
var _signpost: Node3D
var _supplies: Dictionary = {}        # index -> Node3D
var _shrine_rune: MeshInstance3D
var _shrine_light: OmniLight3D
var _shrine_it: Interactable
var _hearth_it: Interactable
var _hearth_fire: Node3D
var _orbs: Dictionary = {}            # ability id -> QuestEssenceOrb
var _refresh_t := 0.0


func _ready() -> void:
	name = "QuestWorld"
	_build_signpost()
	_build_rescue_zone()
	_build_nib()
	_build_supplies()
	_build_shrine()
	_build_hearth()
	Events.essence_dropped.connect(_on_essence_dropped)
	Events.friend_rescued.connect(_on_friend_rescued)
	Events.home_claimed.connect(_on_home_claimed)
	# Essence carriers that died before their essence was absorbed (saved mid-pickup).
	for id: StringName in QuestData.ESSENCE_SOURCES:
		var src: Dictionary = QuestData.ESSENCE_SOURCES[id]
		if GameState.has_flag(src["flag"]) and not Progression.has_ability(id):
			spawn_essence(id, src["pos"])
	_refresh_prompts()


func _process(delta: float) -> void:
	_refresh_t -= delta
	if _refresh_t <= 0.0:
		_refresh_t = REFRESH_INTERVAL
		_refresh_prompts()


func _ground(p: Vector3) -> Vector3:
	return GameState.ground_point(p)


func _mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func _box(s: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = s
	return m


static func _cyl(top: float, bottom: float, h: float, seg: int = 12) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = seg
	return m


static func _sphere(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 12
	m.rings = 6
	return m


func _interactable(parent: Node3D, id: StringName, prompt: String, radius: float, pos: Vector3) -> Interactable:
	var it := Interactable.new()
	it.interact_id = id
	it.prompt = prompt
	it.radius = radius
	it.position = pos
	parent.add_child(it)
	return it


func _solid(parent: Node3D, size: Vector3, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position = pos
	body.add_child(cs)
	parent.add_child(body)


# ---------------------------------------------------------------- signpost
func _build_signpost() -> void:
	_signpost = Node3D.new()
	_signpost.name = "GladeSignpost"
	add_child(_signpost)
	_signpost.global_position = _ground(QuestData.SIGNPOST_POS)
	var wood := Palette.mat(Palette.BARK)
	var plank := Palette.mat(Color(0.58, 0.43, 0.28))
	_mesh(_signpost, _cyl(0.08, 0.1, 2.0, 8), wood, Vector3(0, 1.0, 0), Vector3(0, 0, 0.04))
	# Arrow board pointing west (-X) toward the woods, a second one north.
	var west := Node3D.new()
	west.position = Vector3(0, 1.6, 0)
	_signpost.add_child(west)
	_mesh(west, _box(Vector3(0.9, 0.24, 0.06)), plank, Vector3(-0.4, 0, 0), Vector3(0, 0, 0.05))
	_mesh(west, _cyl(0.0, 0.17, 0.2, 3), plank, Vector3(-0.92, 0.03, 0), Vector3(0, 0, PI * 0.5))
	var north := Node3D.new()
	north.position = Vector3(0, 1.25, 0)
	north.rotation.y = -PI * 0.5
	_signpost.add_child(north)
	_mesh(north, _box(Vector3(0.75, 0.2, 0.06)), plank, Vector3(-0.32, 0, 0), Vector3(0, 0, -0.06))
	# Moss tuft at the base.
	_mesh(_signpost, _sphere(0.22), Palette.mat(Palette.MOSS), Vector3(0.05, 0.05, 0.05))
	_solid(_signpost, Vector3(0.25, 2.0, 0.25), Vector3(0, 1.0, 0))
	var it := _interactable(_signpost, &"glade_signpost", QuestData.prompt("signpost"), 2.2, Vector3(0, 1.0, 0))
	it.interacted.connect(func(_a: Node) -> void: Events.notify.emit(QuestData.line("signpost"), &"quest"))


# ---------------------------------------------------------------- rescue site
func _build_rescue_zone() -> void:
	var z := TriggerZone.new()
	z.name = "RescueSiteZone"
	z.zone_id = &"rescue_site"
	z.radius = WorldLayout.RESCUE_SITE_RADIUS
	add_child(z)
	z.global_position = _ground(WorldLayout.RESCUE_SITE)


func _build_nib() -> void:
	nib = QuestFriend.new()
	nib.injured = not GameState.has_flag(&"friend_rescued")
	add_child(nib)
	nib.interactable.interacted.connect(_on_nib_interacted)
	if nib.injured:
		nib.global_position = _ground(QuestData.NIB_RESCUE_POS)
		nib.rotation.y = 0.8
	else:
		nib.place_at_home(QuestData.NIB_HOME_POS, QuestData.HEARTH_POS)


func _on_nib_interacted(_actor: Node) -> void:
	if nib.injured:
		if Quests.is_waiting_for(&"nib_rescue"):
			return  # the quest handles it (friend_rescued)
		var guards_left := Quests.is_waiting_for(&"rescue_guard")
		Events.notify.emit(QuestData.line("nib_guarded" if guards_left else "nib_injured"), &"quest")
	else:
		var key := "nib_home" if GameState.has_flag(&"boss_defeated") else "nib_home_waiting"
		Events.notify.emit(QuestData.line(key), &"quest")


func _on_friend_rescued() -> void:
	if not is_instance_valid(nib) or not nib.injured:
		return
	Events.notify.emit(QuestData.line("nib_rescued"), &"quest")
	var dir := WorldLayout.CAVE_ENTRANCE - nib.global_position
	nib.walk_away_and_go_home(dir, 6.0, QuestData.NIB_HOME_POS, QuestData.HEARTH_POS)


# ---------------------------------------------------------------- supplies
func _build_supplies() -> void:
	for i in QuestData.SUPPLIES.size():
		if GameState.has_flag(StringName("supply_%d" % i)):
			continue
		var def: Dictionary = QuestData.SUPPLIES[i]
		var root := Node3D.new()
		root.name = "Supply_%d" % i
		add_child(root)
		root.global_position = _ground(QuestData.SUPPLY_POSITIONS[i])
		root.rotation.y = i * 1.3
		match String(def.get("kind", "")):
			"basket":
				_mesh(root, _cyl(0.32, 0.24, 0.3), Palette.mat(Color(0.66, 0.5, 0.3)), Vector3(0, 0.15, 0))
				for k in 4:
					var a := TAU * k / 4.0
					_mesh(root, _cyl(0.0, 0.1, 0.06), Palette.mat(Color(0.86, 0.32, 0.25)), Vector3(cos(a) * 0.14, 0.34, sin(a) * 0.14))
					_mesh(root, _cyl(0.03, 0.03, 0.08, 6), Palette.mat(Color(0.95, 0.92, 0.82)), Vector3(cos(a) * 0.14, 0.28, sin(a) * 0.14))
			"firewood":
				for k in 3:
					_mesh(root, _cyl(0.07, 0.07, 0.8, 8), Palette.mat(Palette.BARK), Vector3(0, 0.1 + 0.11 * (k % 2), -0.12 + 0.12 * k), Vector3(0, 0, PI * 0.5))
				_mesh(root, _cyl(0.17, 0.17, 0.05, 10), Palette.mat(Palette.LEATHER), Vector3(0, 0.16, 0), Vector3(0, 0, PI * 0.5))
			_:
				_mesh(root, _box(Vector3(0.6, 0.18, 0.45)), Palette.mat(Palette.CLOTH_RED), Vector3(0, 0.09, 0))
				_mesh(root, _box(Vector3(0.62, 0.04, 0.12)), Palette.mat(Palette.GOLD), Vector3(0, 0.19, 0))
		# Subtle glow so the pickup reads from a distance.
		var sparkle := _mesh(root, _sphere(0.06), Palette.glow(Palette.GOLD, 3.0), Vector3(0, 0.7, 0))
		var tw := sparkle.create_tween().set_loops()
		tw.tween_property(sparkle, "position:y", 0.85, 1.0).set_trans(Tween.TRANS_SINE)
		tw.tween_property(sparkle, "position:y", 0.7, 1.0).set_trans(Tween.TRANS_SINE)
		var light := OmniLight3D.new()
		light.light_color = Palette.GOLD
		light.light_energy = 0.6
		light.omni_range = 2.5
		light.position = Vector3(0, 0.6, 0)
		root.add_child(light)
		var it := _interactable(root, StringName("supply_%d" % i), QuestData.prompt("supply") % def["name"], 1.8, Vector3(0, 0.4, 0))
		it.interacted.connect(_on_supply_taken.bind(i))
		_supplies[i] = root


func _on_supply_taken(_actor: Node, index: int) -> void:
	var flag := StringName("supply_%d" % index)
	if GameState.has_flag(flag):
		return
	GameState.set_flag(flag)
	Progression.add_item(QuestData.SUPPLY_ITEM, 1)
	var root: Node3D = _supplies.get(index)
	if is_instance_valid(root):
		Audio.play_sfx(&"pickup", root.global_position)
		root.queue_free()
	_supplies.erase(index)
	var have := Progression.item_count(QuestData.SUPPLY_ITEM)
	Events.notify.emit("Found %s (%d/%d)" % [QuestData.SUPPLIES[index]["name"], mini(have, 3), 3], &"quest")
	SaveManager.request_autosave()


# ---------------------------------------------------------------- ruins shrine
func _build_shrine() -> void:
	var root := Node3D.new()
	root.name = "RuinsShrine"
	add_child(root)
	root.global_position = _ground(QuestData.SHRINE_POS)
	var stone := Palette.mat(Palette.STONE_RUIN)
	_mesh(root, _cyl(0.75, 0.9, 0.3, 8), Palette.mat(Palette.ROCK_DARK), Vector3(0, 0.15, 0))
	_mesh(root, _cyl(0.38, 0.45, 1.0, 8), stone, Vector3(0, 0.8, 0))
	_mesh(root, _box(Vector3(0.95, 0.14, 0.95)), stone, Vector3(0, 1.36, 0), Vector3(0, PI * 0.25, 0))
	_mesh(root, _sphere(0.3), Palette.mat(Palette.MOSS), Vector3(0.35, 0.3, 0.3))
	_solid(root, Vector3(0.9, 1.4, 0.9), Vector3(0, 0.7, 0))
	var rune_mesh := TorusMesh.new()
	rune_mesh.inner_radius = 0.16
	rune_mesh.outer_radius = 0.24
	_shrine_rune = _mesh(root, rune_mesh, Palette.glow(AbilityEffects.STONE_COLOR, 3.0), Vector3(0, 1.85, 0), Vector3(PI * 0.5, 0, 0))
	_shrine_light = OmniLight3D.new()
	_shrine_light.light_color = AbilityEffects.STONE_COLOR
	_shrine_light.light_energy = 1.8
	_shrine_light.omni_range = 5.0
	_shrine_light.position = Vector3(0, 1.9, 0)
	root.add_child(_shrine_light)
	var tw := _shrine_rune.create_tween().set_loops()
	tw.tween_property(_shrine_rune, "rotation:y", TAU, 4.0).from(0.0)
	_shrine_it = _interactable(root, &"ruins_shrine", QuestData.prompt("shrine"), 2.4, Vector3(0, 1.0, 0))
	_shrine_it.interacted.connect(_on_shrine_used)
	if GameState.has_flag(&"shrine_used") or Progression.has_ability(&"stone_guard"):
		GameState.set_flag(&"shrine_used")
		_set_shrine_spent()


func _on_shrine_used(_actor: Node) -> void:
	if GameState.has_flag(&"shrine_used"):
		Events.notify.emit(QuestData.line("shrine_spent"), &"quest")
		return
	GameState.set_flag(&"shrine_used")
	Events.notify.emit(QuestData.line("shrine_use"), &"quest")
	Audio.play_sfx(&"essence", _shrine_rune.global_position)
	Progression.unlock_ability(&"stone_guard")
	_set_shrine_spent()


func _set_shrine_spent() -> void:
	_shrine_rune.material_override = Palette.mat(Palette.ROCK_DARK)
	_shrine_light.visible = false
	_shrine_it.prompt = QuestData.prompt("shrine_spent")


# ---------------------------------------------------------------- cave hearth
func _build_hearth() -> void:
	var root := Node3D.new()
	root.name = "CaveHearth"
	add_child(root)
	root.global_position = _ground(QuestData.HEARTH_POS)
	for k in 9:
		var a := TAU * k / 9.0
		_mesh(root, _sphere(0.16), Palette.mat(Palette.ROCK if k % 2 else Palette.ROCK_DARK),
			Vector3(cos(a) * 0.6, 0.08, sin(a) * 0.6)).scale = Vector3(1.2, 0.7, 1.0)
	for k in 2:
		_mesh(root, _cyl(0.07, 0.07, 0.9, 8), Palette.mat(Palette.BARK), Vector3(0, 0.12, 0), Vector3(0, k * PI * 0.5 + 0.3, PI * 0.5))
	_mesh(root, _cyl(0.4, 0.4, 0.02, 12), Palette.mat(Color(0.18, 0.16, 0.15)), Vector3(0, 0.02, 0))
	_hearth_fire = Node3D.new()
	_hearth_fire.name = "Fire"
	root.add_child(_hearth_fire)
	for k in 3:
		var f := _mesh(_hearth_fire, _cyl(0.0, 0.22 - k * 0.05, 0.7 - k * 0.15, 8),
			Palette.glow([Palette.FIRE, Color(1.0, 0.75, 0.3), Color(1.0, 0.92, 0.6)][k], 2.5 + k), Vector3(0, 0.38 - k * 0.05, 0))
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var tw := f.create_tween().set_loops()
		tw.tween_property(f, "scale", Vector3(1.1, 1.25, 1.1), 0.3 + k * 0.07)
		tw.tween_property(f, "scale", Vector3(0.95, 0.9, 0.95), 0.3 + k * 0.07)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.68, 0.35)
	light.light_energy = 2.5
	light.omni_range = 11.0
	light.shadow_enabled = false
	light.position = Vector3(0, 0.9, 0)
	_hearth_fire.add_child(light)
	_hearth_fire.visible = false
	_hearth_it = _interactable(root, &"hearth_cold", QuestData.prompt("hearth_cold"), 2.4, Vector3(0, 0.6, 0))
	_hearth_it.interacted.connect(_on_hearth_used)
	if GameState.has_flag(&"home_claimed"):
		_light_hearth()


func _light_hearth() -> void:
	if _hearth_fire.visible:
		return
	_hearth_fire.visible = true
	Audio.create_loop(&"fire_loop", _hearth_fire)


func _on_home_claimed() -> void:
	_light_hearth()
	_refresh_prompts()


func _on_hearth_used(_actor: Node) -> void:
	# cave_hearth / evolution_altar are handled by Quests / Progression via Events.
	match _hearth_it.interact_id:
		&"hearth_cold": Events.notify.emit(QuestData.line("hearth_cold"), &"quest")
		&"home_hearth": Events.notify.emit(QuestData.line("hearth_rest"), &"quest")
	call_deferred("_refresh_prompts")


func _refresh_prompts() -> void:
	if _hearth_it:
		if not GameState.has_flag(&"home_claimed"):
			if Quests.is_waiting_for(&"cave_hearth"):
				_set_it(_hearth_it, &"cave_hearth", QuestData.prompt("hearth_claim"))
			else:
				_set_it(_hearth_it, &"hearth_cold", QuestData.prompt("hearth_cold"))
		elif not Progression.get_next_stage().is_empty():
			var nxt := Progression.get_next_stage()
			if Progression.can_evolve():
				_set_it(_hearth_it, ProgressionEvolution.ALTAR_ID, QuestData.prompt("hearth_evolve") % nxt["name"])
			else:
				var missing := Progression.get_missing_requirements()
				_set_it(_hearth_it, ProgressionEvolution.ALTAR_ID, QuestData.prompt("hearth_locked") % ", ".join(missing))
		else:
			_set_it(_hearth_it, &"home_hearth", QuestData.prompt("hearth_rest"))
	if is_instance_valid(nib) and nib.injured and nib.interactable.enabled:
		var can_rescue := Quests.is_waiting_for(&"nib_rescue")
		nib.interactable.prompt = QuestData.prompt("nib_injured" if can_rescue else "nib_talk")


func _set_it(it: Interactable, id: StringName, prompt: String) -> void:
	it.interact_id = id
	it.prompt = prompt


# ---------------------------------------------------------------- essences
func _on_essence_dropped(ability_id: StringName, pos: Vector3) -> void:
	spawn_essence(ability_id, pos)


func spawn_essence(ability_id: StringName, pos: Vector3) -> QuestEssenceOrb:
	if not AbilityLibrary.exists(ability_id) or Progression.has_ability(ability_id):
		return null
	if _orbs.has(ability_id) and is_instance_valid(_orbs[ability_id]):
		return _orbs[ability_id]
	var orb := QuestEssenceOrb.new()
	orb.ability_id = ability_id
	add_child(orb)
	orb.global_position = _ground(pos) + Vector3.UP * 1.1
	_orbs[ability_id] = orb
	return orb
