class_name UiCharacterPanel
extends UiWindow
## Character sheet: level/XP/stage, stats + upgrade points, abilities,
## evolution status, inventory and quest log. Rebuilt when shown and when
## relevant events fire while open (menus may allocate; the HUD does not).

const STATS := [
	[&"health", "Max Health", "max_health", "%d"],
	[&"stamina", "Max Stamina", "max_stamina", "%d"],
	[&"", "Max Energy", "max_energy", "%d"],
	[&"attack", "Attack", "attack_power", "%.0f"],
]

var _col_stats: VBoxContainer
var _col_abilities: VBoxContainer
var _col_log: VBoxContainer


func _init() -> void:
	super._init("Character", Vector2(1120, 680))


func _ready() -> void:
	super._ready()
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override(&"separation", 18)
	content.add_child(row)
	_col_stats = _column(row, 0.9)
	_col_abilities = _column(row, 1.1)
	_col_log = _column(row, 1.1)
	var hint := UiTheme.label("%s / Esc to close" % UiKeys.hint(&"character_menu"), &"SmallLabel", 14)
	footer.alignment = BoxContainer.ALIGNMENT_BEGIN
	footer.add_child(hint)
	Events.stats_upgraded.connect(_on_changed)
	Events.level_up.connect(_on_changed.unbind(1))
	Events.ability_unlocked.connect(_on_changed.unbind(1))
	Events.quest_updated.connect(_on_changed.unbind(1))
	Events.quest_completed.connect(_on_changed.unbind(1))
	Events.evolution_changed.connect(_on_changed.unbind(1))
	Events.item_collected.connect(_on_changed.unbind(2))
	Events.xp_gained.connect(_on_changed.unbind(2))
	visibility_changed.connect(func() -> void:
		if visible:
			refresh())


func _on_changed() -> void:
	if visible:
		refresh.call_deferred()


func _column(parent: HBoxContainer, ratio: float) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_stretch_ratio = ratio
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override(&"separation", 6)
	sc.add_child(v)
	return v


func _clear(c: Container) -> void:
	for ch in c.get_children():
		c.remove_child(ch)
		ch.queue_free()


func _section(c: Container, t: String) -> void:
	if c.get_child_count() > 0:
		var sp := Control.new()
		sp.custom_minimum_size.y = 8
		c.add_child(sp)
	c.add_child(UiTheme.label(t, &"SectionLabel"))


func _text(c: Container, t: String, color: Color = UiTheme.TEXT, size: int = 17) -> Label:
	var l := UiTheme.label(t, &"", size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override(&"font_color", color)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_child(l)
	return l


func refresh() -> void:
	_build_stats()
	_build_abilities()
	_build_log()


func _build_stats() -> void:
	_clear(_col_stats)
	_section(_col_stats, UiData.stage_name())
	_text(_col_stats, "Level %d" % Progression.level, UiTheme.GOLD, 20)
	var need := maxi(1, Progression.xp_to_next_level())
	var xb := HudBar.new()
	xb.custom_minimum_size = Vector2(0, 14)
	xb.fill_color = UiTheme.XP
	xb.show_text = false
	_col_stats.add_child(xb)
	xb.snap(float(Progression.xp), float(need))
	_text(_col_stats, "%d / %d XP" % [Progression.xp, need], UiTheme.TEXT_DIM, 15)
	_section(_col_stats, "Attributes")
	var points: int = int(Progression.get(&"upgrade_points")) if Progression.get(&"upgrade_points") != null else 0
	var can_spend := points > 0 and Progression.has_method(&"spend_point")
	for st: Array in STATS:
		var hb := HBoxContainer.new()
		hb.custom_minimum_size.y = 40
		_col_stats.add_child(hb)
		var l := UiTheme.label(st[1])
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.size_flags_vertical = Control.SIZE_FILL
		hb.add_child(l)
		var val: Variant = Progression.call(st[2]) if Progression.has_method(st[2]) else 0
		var lv := UiTheme.label(st[3] % float(val))
		lv.add_theme_color_override(&"font_color", UiTheme.GOLD)
		lv.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lv.size_flags_vertical = Control.SIZE_FILL
		hb.add_child(lv)
		if st[0] != &"":
			if Progression.has_method(&"get_upgrade_level"):
				var ul := UiTheme.label(" +%d" % int(Progression.call(&"get_upgrade_level", st[0])), &"SmallLabel", 13)
				ul.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				ul.size_flags_vertical = Control.SIZE_FILL
				hb.add_child(ul)
			var b := UiTheme.button("+", 40, 36)
			b.theme_type_variation = &"PlusButton"
			b.disabled = not can_spend
			b.tooltip_text = "Spend an upgrade point"
			var stat: StringName = st[0]
			b.pressed.connect(func() -> void:
				if Progression.has_method(&"spend_point"):
					Progression.call(&"spend_point", stat)
				refresh())
			hb.add_child(b)
		else:
			var sp := Control.new()
			sp.custom_minimum_size.x = 40
			hb.add_child(sp)
	_text(_col_stats, "Upgrade points: %d" % points, UiTheme.GOOD if points > 0 else UiTheme.TEXT_DIM, 16)
	# Evolution
	_section(_col_stats, "Evolution")
	var nxt: Dictionary = Progression.call(&"get_next_stage") if Progression.has_method(&"get_next_stage") else {}
	if Progression.has_method(&"can_evolve") and Progression.call(&"can_evolve"):
		_text(_col_stats, "Ready to evolve into a %s! Return to your home's hearth." % str(nxt.get("name", "new form")), UiTheme.GOOD, 16)
	elif not nxt.is_empty():
		_text(_col_stats, "Next form: %s" % str(nxt.get("name", "?")), UiTheme.TEXT, 16)
		if Progression.has_method(&"get_missing_requirements"):
			for req: Variant in Progression.call(&"get_missing_requirements"):
				var r := str(req)
				_text(_col_stats, "•  " + r.left(1).to_upper() + r.substr(1), UiTheme.TEXT_DIM, 15)
	else:
		_text(_col_stats, "No further evolution available yet.", UiTheme.TEXT_DIM, 15)


func _build_abilities() -> void:
	_clear(_col_abilities)
	_section(_col_abilities, "Essence Abilities")
	var unlocked: Array = Progression.get(&"unlocked_abilities") if Progression.get(&"unlocked_abilities") is Array else []
	if unlocked.is_empty():
		_text(_col_abilities, "No essences absorbed yet. Defeat powerful foes or find ancient shrines.", UiTheme.TEXT_DIM, 15)
	for id: StringName in unlocked:
		var info := UiData.ability_info(id)
		var slot := -1
		for i in 3:
			if UiData.equipped(i) == id:
				slot = i
		var card := PanelContainer.new()
		card.add_theme_stylebox_override(&"panel", UiTheme.hud_panel(8.0))
		_col_abilities.add_child(card)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override(&"separation", 10)
		card.add_child(hb)
		var sw := ColorRect.new()
		sw.color = info.get("color", Color.WHITE)
		sw.custom_minimum_size = Vector2(6, 0)
		hb.add_child(sw)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override(&"separation", 0)
		hb.add_child(v)
		var title := "%s" % info.get("name", id)
		if slot >= 0:
			title += "   [slot %s]" % UiKeys.hint(StringName("ability_%d" % (slot + 1)))
		var tl := _text(v, title, (info.get("color", Color.WHITE) as Color).lightened(0.2), 18)
		tl.autowrap_mode = TextServer.AUTOWRAP_OFF
		_text(v, str(info.get("desc", "")), UiTheme.TEXT_DIM, 15)
		if float(info.get("cost", 0.0)) > 0.0:
			_text(v, "Energy %d  ·  Cooldown %ds" % [roundi(info["cost"]), roundi(info["cooldown"])], Color(0.6, 0.75, 1.0), 14)
	var passives: Array = Progression.get(&"unlocks") if Progression.get(&"unlocks") is Array else []
	if not passives.is_empty():
		_section(_col_abilities, "Passive Gifts")
		for id: StringName in passives:
			var info := UiData.ability_info(id)
			_text(_col_abilities, str(info.get("name", id)), (info.get("color", Color.WHITE) as Color).lightened(0.2), 17)
			_text(_col_abilities, str(info.get("desc", "")), UiTheme.TEXT_DIM, 15)
	_section(_col_abilities, "Inventory")
	var inv: Dictionary = Progression.get(&"inventory") if Progression.get(&"inventory") is Dictionary else {}
	if inv.is_empty():
		_text(_col_abilities, "Your pouch is empty.", UiTheme.TEXT_DIM, 15)
	for item: Variant in inv:
		_text(_col_abilities, "%s  ×%d" % [UiData.item_name(StringName(str(item))), int(inv[item])], UiTheme.TEXT, 16)


func _build_log() -> void:
	_clear(_col_log)
	_section(_col_log, "Quest Log")
	var qlog: Array = Quests.call(&"get_quest_log") if Quests.has_method(&"get_quest_log") else []
	if qlog.is_empty():
		var t := str(Quests.get_active_quest_title())
		_text(_col_log, t if t != "" else "No quests yet.", UiTheme.TEXT_DIM, 15)
		return
	for q: Variant in qlog:
		if not q is Dictionary:
			_text(_col_log, str(q), UiTheme.TEXT, 16)
			continue
		var d: Dictionary = q
		var done := bool(d.get("completed", false))
		var tl := _text(_col_log, str(d.get("title", "")), UiTheme.TEXT_MUTED if done else UiTheme.GOLD, 18)
		if done:
			tl.text += "  (complete)"
		if not done:
			if str(d.get("summary", "")) != "":
				_text(_col_log, str(d["summary"]), UiTheme.TEXT_DIM, 14)
			for s: Variant in d.get("steps", []):
				if s is Dictionary:
					var sd: Dictionary = s
					var ok := bool(sd.get("done", false))
					_text(_col_log, ("–  " if ok else "•  ") + str(sd.get("text", "")), UiTheme.TEXT_MUTED if ok else UiTheme.TEXT, 15)
