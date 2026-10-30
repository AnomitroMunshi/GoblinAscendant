class_name HudRoot
extends Control
## In-game HUD (OWNER: UI agent). Built in code; everything anchored so it
## adapts to any aspect ratio. Screen centre is kept clear.
##   bottom-left : health / stamina / energy bars, level badge, XP bar, stage
##   bottom-centre: ability slots 1-3, interaction prompt above them
##   top-centre  : compass, boss bar, lock-on target bar
##   top-right   : objective, toasts below it
##   upper third : banners (level up, essence, quest complete, evolution)

const TOAST_LIFE := 4.2
const MAX_TOASTS := 5
const BANNER_TIME := 2.8
## Toasts already represented by a banner (avoid showing the same news twice).
const BANNER_TOAST_PREFIXES := ["Level up!", "Essence absorbed", "Quest complete", "You evolved"]

var hp_bar: HudBar
var stamina_bar: HudBar
var energy_bar: HudBar
var xp_bar: HudBar
var level_label: Label
var stage_label: Label
var stats_panel: PanelContainer
var slots: Array[HudAbilitySlot] = []
var ability_bar: HBoxContainer
var prompt_panel: PanelContainer
var prompt_key: Label
var prompt_text: Label
var objective_panel: PanelContainer
var objective_title: Label
var objective_text: Label
var compass: HudCompass
var boss_box: VBoxContainer
var boss_name: Label
var boss_bar: HudBar
var lock_box: VBoxContainer
var lock_name: Label
var lock_bar: HudBar
var toasts: VBoxContainer
var banner_box: VBoxContainer
var banner_title: Label
var banner_sub: Label
var _xp_anchor: Control

var hp_ratio := 1.0
var damage_flash := 0.0
var _lock_target: Node3D
var _lock_last := Vector2(-1, -1)
var _boss_visible := false
var _banner_queue: Array = []
var _banner_busy := false
var _banner_tween: Tween
var _suppress_until := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.full_rect(self)
	_build_stats()
	_build_abilities()
	_build_prompt()
	_build_objective()
	_build_top()
	_build_toasts()
	_build_banner()
	_connect_events()
	refresh_all()


# ================================================================ build
func _build_stats() -> void:
	stats_panel = PanelContainer.new()
	stats_panel.theme_type_variation = &"HudPanel"
	stats_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	stats_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	stats_panel.offset_left = 22
	stats_panel.offset_bottom = -22
	add_child(stats_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	stats_panel.add_child(row)
	# level badge
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override(&"panel", UiTheme.panel_box(Color(0.32, 0.22, 0.10, 0.95), Color(0.16, 0.10, 0.05, 0.95), UiTheme.GOLD, 26.0, 4.0, 2.0))
	badge.custom_minimum_size = Vector2(58, 58)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(badge)
	var bv := VBoxContainer.new()
	bv.alignment = BoxContainer.ALIGNMENT_CENTER
	bv.add_theme_constant_override(&"separation", -6)
	badge.add_child(bv)
	var lv := UiTheme.label("LV", &"SmallLabel", 11)
	lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv.add_theme_color_override(&"font_color", UiTheme.GOLD_DIM)
	bv.add_child(lv)
	level_label = UiTheme.label("1", &"HeaderLabel", 26)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(level_label)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 5)
	row.add_child(col)
	var top := HBoxContainer.new()
	col.add_child(top)
	stage_label = UiTheme.label("Goblin", &"SectionLabel", 18)
	stage_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(stage_label)
	_xp_anchor = top
	hp_bar = _bar(Vector2(290, 20), UiTheme.HP, true)
	col.add_child(hp_bar)
	stamina_bar = _bar(Vector2(230, 10), UiTheme.STAMINA, false)
	stamina_bar.chip_color = Color(0.95, 0.9, 0.5)
	col.add_child(stamina_bar)
	energy_bar = _bar(Vector2(230, 10), UiTheme.ENERGY, false)
	energy_bar.chip_color = Color(0.7, 0.85, 1.0)
	col.add_child(energy_bar)
	xp_bar = _bar(Vector2(290, 5), UiTheme.XP, false)
	xp_bar.chip_color = Color(1, 1, 0.85)
	xp_bar.chip_delay = 0.0
	xp_bar.back_color = Color(0.04, 0.03, 0.02, 0.7)
	col.add_child(xp_bar)


func _bar(sz: Vector2, color: Color, text: bool) -> HudBar:
	var b := HudBar.new()
	b.custom_minimum_size = sz
	b.fill_color = color
	b.show_text = text
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return b


func _build_abilities() -> void:
	ability_bar = HBoxContainer.new()
	ability_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ability_bar.add_theme_constant_override(&"separation", 6)
	ability_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	ability_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	ability_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ability_bar.offset_bottom = -18
	add_child(ability_bar)
	for i in 3:
		var s := HudAbilitySlot.new()
		s.slot = i
		s.key_text = UiKeys.hint(StringName("ability_%d" % (i + 1)))
		ability_bar.add_child(s)
		slots.append(s)


func _build_prompt() -> void:
	prompt_panel = PanelContainer.new()
	prompt_panel.theme_type_variation = &"HudPanel"
	prompt_panel.add_theme_stylebox_override(&"panel", UiTheme.hud_panel(8.0))
	prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	prompt_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	prompt_panel.offset_bottom = -124
	prompt_panel.visible = false
	add_child(prompt_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	prompt_panel.add_child(row)
	var cap := PanelContainer.new()
	var cap_sb := UiTheme.flat(Color(0.95, 0.88, 0.7), 5, Color(0.5, 0.36, 0.16), 2)
	cap_sb.content_margin_left = 8
	cap_sb.content_margin_right = 8
	cap_sb.content_margin_top = 0
	cap_sb.content_margin_bottom = 0
	cap.add_theme_stylebox_override(&"panel", cap_sb)
	cap.custom_minimum_size = Vector2(30, 30)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(cap)
	prompt_key = UiTheme.label("E", &"", 17)
	prompt_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_key.add_theme_color_override(&"font_color", Color(0.2, 0.12, 0.05))
	prompt_key.add_theme_constant_override(&"shadow_offset_y", 0)
	prompt_key.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0))
	cap.add_child(prompt_key)
	prompt_text = UiTheme.label("", &"HudLabel", 19)
	row.add_child(prompt_text)


func _build_objective() -> void:
	objective_panel = PanelContainer.new()
	objective_panel.theme_type_variation = &"HudPanel"
	objective_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	objective_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	objective_panel.offset_right = -22
	objective_panel.offset_top = 20
	objective_panel.custom_minimum_size = Vector2(300, 0)
	add_child(objective_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 2)
	objective_panel.add_child(v)
	objective_title = UiTheme.label("", &"SectionLabel", 18)
	objective_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_title.custom_minimum_size.x = 300
	v.add_child(objective_title)
	objective_text = UiTheme.label("", &"", 16)
	objective_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_text.custom_minimum_size.x = 300
	objective_text.add_theme_color_override(&"font_color", UiTheme.TEXT)
	v.add_child(objective_text)


func _build_top() -> void:
	var top := VBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top.offset_top = 10
	top.add_theme_constant_override(&"separation", 4)
	add_child(top)
	compass = HudCompass.new()
	compass.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	top.add_child(compass)
	# spacer for compass labels under the strip
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 14)
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(sp)
	boss_box = VBoxContainer.new()
	boss_box.add_theme_constant_override(&"separation", 2)
	boss_box.visible = false
	boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(boss_box)
	boss_name = UiTheme.label("", &"BannerLabel", 24)
	boss_name.add_theme_constant_override(&"outline_size", 6)
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_box.add_child(boss_name)
	boss_bar = _bar(Vector2(640, 16), Color(0.85, 0.30, 0.16), false)
	boss_bar.chip_speed = 0.35
	boss_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	boss_box.add_child(boss_bar)
	lock_box = VBoxContainer.new()
	lock_box.add_theme_constant_override(&"separation", 1)
	lock_box.visible = false
	lock_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(lock_box)
	lock_name = UiTheme.label("", &"HudLabel", 15)
	lock_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock_box.add_child(lock_name)
	lock_bar = _bar(Vector2(220, 8), Color(0.90, 0.36, 0.26), false)
	lock_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	lock_box.add_child(lock_bar)


func _build_toasts() -> void:
	toasts = VBoxContainer.new()
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toasts.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	toasts.anchor_top = 0.24
	toasts.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	toasts.offset_right = -22
	toasts.offset_left = -362
	toasts.offset_top = 0
	toasts.add_theme_constant_override(&"separation", 6)
	add_child(toasts)


func _build_banner() -> void:
	banner_box = VBoxContainer.new()
	banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner_box.anchor_top = 0.2
	banner_box.anchor_bottom = 0.2
	banner_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner_box.add_theme_constant_override(&"separation", 0)
	banner_box.modulate.a = 0.0
	add_child(banner_box)
	banner_title = UiTheme.label("", &"BannerLabel")
	banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_box.add_child(banner_title)
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(380, 2)
	line.color = Color(UiTheme.GOLD, 0.7)
	line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_box.add_child(line)
	banner_sub = UiTheme.label("", &"HudLabel", 21)
	banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_box.add_child(banner_sub)


# ================================================================ events
func _connect_events() -> void:
	Events.player_stats_changed.connect(_on_stats)
	Events.xp_gained.connect(_on_xp_gained)
	Events.level_up.connect(_on_level_up)
	Events.evolution_changed.connect(_on_evolution)
	Events.stats_upgraded.connect(refresh_progress)
	Events.ability_used.connect(_on_ability_used)
	Events.ability_failed.connect(_on_ability_failed)
	Events.ability_unlocked.connect(_on_ability_unlocked)
	Events.objective_changed.connect(func(_t: String) -> void: refresh_objective())
	Events.quest_updated.connect(func(_q: StringName) -> void: refresh_objective())
	Events.quest_started.connect(func(_q: StringName) -> void: refresh_objective())
	Events.quest_completed.connect(_on_quest_completed)
	Events.game_started.connect(refresh_all)
	Events.game_loaded.connect(refresh_all)
	Events.interaction_prompt_changed.connect(set_prompt)
	Events.notify.connect(toast)
	Events.boss_engaged.connect(_on_boss_engaged)
	Events.boss_health_changed.connect(_on_boss_health)
	Events.boss_disengaged.connect(func(_b: Node3D) -> void: _hide_boss(""))
	Events.boss_defeated.connect(func(_b: Node3D) -> void: _hide_boss("Defeated"))
	Events.lock_target_changed.connect(_on_lock_target)
	Events.player_damaged.connect(func(_i: Variant) -> void: damage_flash = 1.0)
	Events.chapter_completed.connect(func() -> void: banner("Chapter 1 Complete", "A Small Beginning", UiTheme.GOLD))
	Events.landmark_discovered.connect(func(_id: StringName) -> void: compass.queue_redraw())


func refresh_all() -> void:
	refresh_progress()
	refresh_objective()
	var p: Node3D = GameState.player
	if is_instance_valid(p) and p.get(&"health") is HealthComponent:
		var h: HealthComponent = p.get(&"health")
		hp_bar.snap(h.health, h.max_health)
		hp_ratio = h.ratio()
		stamina_bar.snap(float(p.get(&"stamina")), Progression.max_stamina())
		energy_bar.snap(float(p.get(&"energy")), Progression.max_energy())
	else:
		hp_bar.snap(Progression.max_health(), Progression.max_health())
		stamina_bar.snap(Progression.max_stamina(), Progression.max_stamina())
		energy_bar.snap(Progression.max_energy(), Progression.max_energy())


func refresh_progress() -> void:
	level_label.text = str(Progression.level)
	stage_label.text = UiData.stage_name()
	xp_bar.set_values(float(Progression.xp), float(maxi(1, Progression.xp_to_next_level())))


func refresh_objective() -> void:
	var title := str(Quests.get_active_quest_title()) if Quests.has_method(&"get_active_quest_title") else ""
	var text := str(Quests.get_objective_text()) if Quests.has_method(&"get_objective_text") else ""
	var changed := title != objective_title.text or text != objective_text.text
	objective_title.text = title
	objective_title.visible = title != ""
	objective_text.text = text
	objective_panel.visible = title != "" or text != ""
	if compass:
		compass.refresh_objective()
	if changed and objective_panel.visible and is_inside_tree():
		objective_panel.pivot_offset = Vector2(objective_panel.size.x, 0)
		var tw := create_tween()
		objective_panel.modulate = Color(1.6, 1.4, 1.0, 1.0)
		tw.tween_property(objective_panel, "modulate", Color.WHITE, 0.8)


func _on_stats(hp: float, max_hp: float, st: float, max_st: float, en: float, max_en: float) -> void:
	hp_bar.set_values(hp, max_hp)
	stamina_bar.set_values(st, max_st)
	energy_bar.set_values(en, max_en)
	hp_ratio = hp / maxf(max_hp, 1.0)
	hp_bar.set_pulse(hp_ratio < 0.25 and hp > 0.0)


func _on_xp_gained(amount: int, _reason: String) -> void:
	refresh_progress()
	if amount <= 0 or not is_inside_tree():
		return
	var l := UiTheme.label("+%d XP" % amount, &"HudLabel", 17)
	l.add_theme_color_override(&"font_color", UiTheme.XP)
	add_child(l)
	var base := stats_panel.position + Vector2(stats_panel.size.x + 10.0, stats_panel.size.y - 30.0)
	l.position = base
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", base.y - 46.0, 1.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.8)
	tw.chain().tween_callback(l.queue_free)


func _on_level_up(new_level: int) -> void:
	refresh_progress()
	_suppress_until = Time.get_ticks_msec() + 600
	banner("Level %d" % new_level, "+1 upgrade point  ·  open Character (%s)" % UiKeys.hint(&"character_menu"), UiTheme.XP)


func _on_evolution(_stage: StringName) -> void:
	refresh_progress()
	_suppress_until = Time.get_ticks_msec() + 600
	banner("Evolution", "You have become a %s" % UiData.stage_name(), Color(0.65, 0.95, 0.75))


func _on_ability_unlocked(id: StringName) -> void:
	var info := UiData.ability_info(id)
	_suppress_until = Time.get_ticks_msec() + 600
	banner("Essence Acquired", str(info.get("name", id)), info.get("color", Palette.ESSENCE))


func _on_quest_completed(id: StringName) -> void:
	refresh_objective()
	_suppress_until = Time.get_ticks_msec() + 600
	banner("Quest Complete", UiData.quest_title(id), UiTheme.GOLD)


func _on_ability_used(slot: int, _id: StringName) -> void:
	if slot >= 0 and slot < slots.size():
		slots[slot].flash()


func _on_ability_failed(slot: int, reason: String) -> void:
	if slot >= 0 and slot < slots.size():
		slots[slot].shake()
	if reason != "":
		toast(reason, &"warning")


# ================================================================ prompt
func set_prompt(text: String) -> void:
	if text.strip_edges() == "":
		prompt_panel.visible = false
		return
	var parts := UiKeys.split_prompt(text)
	prompt_key.text = parts[0]
	prompt_key.get_parent().visible = parts[0] != ""
	prompt_text.text = parts[1]
	prompt_panel.visible = true
	prompt_panel.reset_size()


# ================================================================ toasts / banners
func toast(text: String, kind: StringName = &"info") -> void:
	if text == "" or not is_inside_tree():
		return
	if Time.get_ticks_msec() < _suppress_until:
		for pre: String in BANNER_TOAST_PREFIXES:
			if text.begins_with(pre):
				return
	while toasts.get_child_count() >= MAX_TOASTS:
		var old := toasts.get_child(0)
		toasts.remove_child(old)
		old.queue_free()
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"HudPanel"
	panel.add_theme_stylebox_override(&"panel", UiTheme.hud_panel(8.0))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	panel.add_child(row)
	var strip := ColorRect.new()
	strip.color = UiTheme.kind_color(kind)
	strip.custom_minimum_size = Vector2(4, 0)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(strip)
	var l := UiTheme.label(text, &"", 16)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 300
	l.add_theme_color_override(&"font_color", UiTheme.TEXT.lerp(UiTheme.kind_color(kind), 0.25))
	row.add_child(l)
	panel.modulate.a = 0.0
	toasts.add_child(panel)
	var tw := panel.create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.25)
	tw.tween_interval(TOAST_LIFE)
	tw.tween_property(panel, "modulate:a", 0.0, 0.6)
	tw.tween_callback(panel.queue_free)


func banner(title: String, sub: String = "", color: Color = UiTheme.GOLD) -> void:
	_banner_queue.append([title, sub, color])
	if not _banner_busy:
		_next_banner()


func _next_banner() -> void:
	if _banner_queue.is_empty() or not is_inside_tree():
		_banner_busy = false
		return
	_banner_busy = true
	var b: Array = _banner_queue.pop_front()
	banner_title.text = b[0]
	banner_title.add_theme_color_override(&"font_color", b[2])
	banner_sub.text = b[1]
	banner_sub.visible = b[1] != ""
	banner_box.reset_size()
	banner_box.pivot_offset = Vector2(banner_box.size.x * 0.5, banner_box.size.y * 0.5)
	banner_box.scale = Vector2(0.92, 0.92)
	if _banner_tween and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.set_parallel(true)
	_banner_tween.tween_property(banner_box, "modulate:a", 1.0, 0.3)
	_banner_tween.tween_property(banner_box, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.chain().tween_interval(BANNER_TIME)
	_banner_tween.chain().tween_property(banner_box, "modulate:a", 0.0, 0.5)
	_banner_tween.chain().tween_callback(_next_banner)


# ================================================================ boss / lock
func _on_boss_engaged(boss: Node3D) -> void:
	var nm := "Ogre"
	if is_instance_valid(boss) and str(boss.get(&"display_name")) not in ["", "<null>"]:
		nm = str(boss.get(&"display_name"))
	boss_name.text = nm
	if is_instance_valid(boss) and boss.get(&"health") is HealthComponent:
		var h: HealthComponent = boss.get(&"health")
		boss_bar.snap(h.health, h.max_health)
	else:
		boss_bar.snap(1.0, 1.0)
	_boss_visible = true
	boss_box.visible = true
	boss_box.modulate.a = 0.0
	create_tween().tween_property(boss_box, "modulate:a", 1.0, 0.4)
	_update_lock_visibility()


func _on_boss_health(current: float, maximum: float) -> void:
	if not boss_box.visible:
		boss_box.visible = true
		boss_box.modulate.a = 1.0
		_boss_visible = true
	boss_bar.set_values(current, maximum)


func _hide_boss(caption: String) -> void:
	if not boss_box.visible:
		return
	_boss_visible = false
	if caption != "":
		boss_bar.set_values(0.0, 1.0)
		boss_name.text = "%s — %s" % [boss_name.text, caption]
	var tw := create_tween()
	tw.tween_interval(1.6 if caption != "" else 0.2)
	tw.tween_property(boss_box, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func() -> void:
		if not _boss_visible:
			boss_box.visible = false)
	_update_lock_visibility()


func _on_lock_target(target: Node3D) -> void:
	_lock_target = target if is_instance_valid(target) else null
	_lock_last = Vector2(-1, -1)
	if _lock_target:
		var nm := str(_lock_target.get(&"display_name"))
		lock_name.text = nm if nm not in ["", "<null>"] else "Target"
	_update_lock_visibility()


func _update_lock_visibility() -> void:
	var show := _lock_target != null and is_instance_valid(_lock_target)
	# The boss already has its own bar.
	if show and _boss_visible and _lock_target.is_in_group(&"boss"):
		show = false
	lock_box.visible = show
	if show:
		_poll_lock(true)


func _poll_lock(force: bool = false) -> void:
	if _lock_target == null:
		return
	if not is_instance_valid(_lock_target) or (_lock_target.has_method(&"is_dead") and _lock_target.is_dead()):
		_lock_target = null
		lock_box.visible = false
		return
	var h: Variant = _lock_target.get(&"health")
	if h is HealthComponent:
		var v := Vector2((h as HealthComponent).health, (h as HealthComponent).max_health)
		if v != _lock_last:
			if force or _lock_last.x < 0.0:
				lock_bar.snap(v.x, v.y)
			else:
				lock_bar.set_values(v.x, v.y)
			_lock_last = v


# ================================================================ per frame
func _process(_delta: float) -> void:
	if lock_box.visible or _lock_target != null:
		_poll_lock()
	var ac := UiData.ability_controller()
	var energy := 1e9
	var p: Node3D = GameState.player
	if is_instance_valid(p):
		var e: Variant = p.get(&"energy")
		if e is float or e is int:
			energy = float(e)
	for i in slots.size():
		var id := UiData.equipped(i)
		var ratio := 0.0
		var remaining := 0.0
		var cost := 0.0
		if ac and id != &"":
			if ac.has_method(&"get_cooldown_ratio"):
				ratio = ac.call(&"get_cooldown_ratio", i)
			elif ac.has_method(&"get_cooldown_total"):
				var tot: float = ac.call(&"get_cooldown_total", i)
				ratio = float(ac.call(&"get_cooldown_remaining", i)) / tot if tot > 0.0 else 0.0
			if ac.has_method(&"get_cooldown_remaining"):
				remaining = ac.call(&"get_cooldown_remaining", i)
			if ac.has_method(&"get_energy_cost"):
				cost = ac.call(&"get_energy_cost", i)
		slots[i].update_state(id, ratio, remaining, energy >= cost)
