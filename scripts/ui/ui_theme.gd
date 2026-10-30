class_name UiTheme
extends RefCounted
## Shared fantasy UI theme built in code (OWNER: UI agent).
## Soft vertical-gradient panels with rounded corners and a thin warm-gold
## outline (generated once as small nine-patch textures), warm parchment text,
## serif headings. Everything is cached so menus/HUD share one Theme.

const TEXT := Color(0.95, 0.91, 0.83)
const TEXT_DIM := Color(0.74, 0.69, 0.60)
const TEXT_MUTED := Color(0.56, 0.52, 0.46)
const GOLD := Palette.GOLD
const GOLD_DIM := Color(0.72, 0.56, 0.27)
const HP := Color(0.86, 0.22, 0.20)
const STAMINA := Color(0.62, 0.84, 0.30)
const ENERGY := Color(0.30, 0.62, 1.0)
const XP := Color(0.96, 0.78, 0.34)
const GOOD := Color(0.55, 0.88, 0.45)
const BAD := Color(0.98, 0.42, 0.36)

## Toast accent per Events.notify kind.
const KIND_COLORS := {
	&"info": Color(0.75, 0.85, 0.95), &"quest": Color(0.96, 0.78, 0.34),
	&"xp": Color(0.70, 0.92, 0.45), &"warning": Color(0.98, 0.45, 0.35),
	&"essence": Color(0.55, 0.85, 1.0),
}

static var _theme: Theme
static var _serif: Font
static var _tex_cache: Dictionary = {}


static func kind_color(kind: StringName) -> Color:
	return KIND_COLORS.get(kind, KIND_COLORS[&"info"])


static func serif() -> Font:
	if _serif == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Georgia", "Palatino Linotype", "Book Antiqua", "Cambria", "Noto Serif", "serif"])
		f.font_weight = 600
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		_serif = f
	return _serif


static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


# ------------------------------------------------------------------ textures
## Rounded rect with a vertical gradient, AA border and a faint top highlight.
static func panel_texture(top: Color, bottom: Color, border: Color, radius: float = 10.0, border_w: float = 1.5, w: int = 48, h: int = 96) -> ImageTexture:
	var key := "%s%s%s%.1f%.1f%dx%d" % [top.to_html(), bottom.to_html(), border.to_html(), radius, border_w, w, h]
	if _tex_cache.has(key):
		return _tex_cache[key]
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var half := Vector2(w, h) * 0.5
	for y in h:
		var grad := lerpf(0.0, 1.0, float(y) / (h - 1))
		var base := top.lerp(bottom, grad)
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5) - half
			var q := (p.abs() - half + Vector2(radius, radius))
			var d := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - radius
			var cov := clampf(0.5 - d, 0.0, 1.0)
			if cov <= 0.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var c := base
			# soft inner highlight along the top edge
			if y < 6:
				c = c.lerp(Color(1, 0.95, 0.8, c.a), 0.06 * (1.0 - y / 6.0))
			var bt := clampf(d + border_w + 0.5, 0.0, 1.0)
			c = c.lerp(Color(border.r, border.g, border.b, maxf(border.a, c.a)), bt * border.a)
			c.a *= cov
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	_tex_cache[key] = tex
	return tex


static func panel_box(top: Color, bottom: Color, border: Color, radius: float = 10.0, margin: float = 12.0, border_w: float = 1.5) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = panel_texture(top, bottom, border, radius, border_w)
	var m := radius + border_w + 2.0
	sb.texture_margin_left = m
	sb.texture_margin_right = m
	sb.texture_margin_top = m
	sb.texture_margin_bottom = m
	sb.content_margin_left = margin + 2.0
	sb.content_margin_right = margin + 2.0
	sb.content_margin_top = margin
	sb.content_margin_bottom = margin
	return sb


## Standard menu panel (dark wood/parchment, gold outline).
static func menu_panel() -> StyleBoxTexture:
	return panel_box(Color(0.17, 0.13, 0.10, 0.95), Color(0.08, 0.06, 0.05, 0.95), Color(GOLD_DIM, 0.85), 12.0, 18.0)


## Lighter translucent panel for HUD widgets.
static func hud_panel(margin: float = 10.0) -> StyleBoxTexture:
	return panel_box(Color(0.14, 0.11, 0.08, 0.72), Color(0.05, 0.04, 0.03, 0.72), Color(GOLD_DIM, 0.45), 9.0, margin)


static func flat(color: Color, radius: int = 4, border: Color = Color(0, 0, 0, 0), border_w: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	if border_w > 0:
		sb.border_color = border
		sb.set_border_width_all(border_w)
	return sb


static func _circle_tex(d: int, fill: Color, ring: Color) -> ImageTexture:
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var c := Vector2(d, d) * 0.5
	var r := d * 0.5 - 1.0
	for y in d:
		for x in d:
			var dist := (Vector2(x + 0.5, y + 0.5) - c).length()
			var cov := clampf(r - dist + 0.5, 0.0, 1.0)
			var col := fill.lerp(ring, clampf(dist - (r - 2.5), 0.0, 1.0))
			col.a *= cov
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


static func _toggle_tex(on: bool) -> ImageTexture:
	var w := 46
	var h := 26
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var r := h * 0.5 - 1.0
	var track := Color(0.78, 0.6, 0.26) if on else Color(0.22, 0.18, 0.15)
	var knob_x := w - h * 0.5 if on else h * 0.5
	for y in h:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5)
			var cx := clampf(p.x, h * 0.5, w - h * 0.5)
			var d_track := (p - Vector2(cx, h * 0.5)).length()
			var cov := clampf(r - d_track + 0.5, 0.0, 1.0)
			var col := track
			col = col.lerp(Color(GOLD_DIM, 1.0), clampf(d_track - (r - 1.5), 0.0, 1.0) * 0.7)
			var d_knob := (p - Vector2(knob_x, h * 0.5)).length()
			var kc := clampf(r - 3.0 - d_knob + 0.5, 0.0, 1.0)
			col = col.lerp(Color(0.98, 0.94, 0.85) if on else Color(0.62, 0.58, 0.52), kc)
			col.a = cov
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


# ------------------------------------------------------------------ theme
static func _build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 18

	# Panels
	t.set_stylebox(&"panel", &"PanelContainer", menu_panel())
	t.set_stylebox(&"panel", &"Panel", menu_panel())
	t.add_type(&"HudPanel")
	t.set_type_variation(&"HudPanel", &"PanelContainer")
	t.set_stylebox(&"panel", &"HudPanel", hud_panel())

	# Labels
	t.set_color(&"font_color", &"Label", TEXT)
	t.set_color(&"font_shadow_color", &"Label", Color(0, 0, 0, 0.55))
	t.set_constant(&"shadow_offset_x", &"Label", 1)
	t.set_constant(&"shadow_offset_y", &"Label", 2)
	t.set_color(&"font_outline_color", &"Label", Color(0.05, 0.03, 0.02, 0.85))
	_variation(t, &"HudLabel", &"Label", 16, TEXT, 4)
	_variation(t, &"SmallLabel", &"Label", 15, TEXT_DIM, 0)
	_variation(t, &"HeaderLabel", &"Label", 28, GOLD, 0, serif())
	_variation(t, &"SectionLabel", &"Label", 20, GOLD, 0, serif())
	_variation(t, &"TitleLabel", &"Label", 86, GOLD, 10, serif())
	_variation(t, &"BannerLabel", &"Label", 44, GOLD, 8, serif())

	# Buttons
	var b_normal := panel_box(Color(0.27, 0.20, 0.13, 0.96), Color(0.15, 0.11, 0.08, 0.96), Color(GOLD_DIM, 0.55), 8.0, 10.0)
	var b_hover := panel_box(Color(0.36, 0.27, 0.16, 0.98), Color(0.20, 0.15, 0.10, 0.98), Color(GOLD, 0.95), 8.0, 10.0)
	var b_pressed := panel_box(Color(0.12, 0.09, 0.06, 0.98), Color(0.22, 0.16, 0.10, 0.98), Color(GOLD, 0.95), 8.0, 10.0)
	var b_disabled := panel_box(Color(0.16, 0.14, 0.12, 0.7), Color(0.11, 0.10, 0.09, 0.7), Color(0.4, 0.36, 0.3, 0.4), 8.0, 10.0)
	var b_focus := flat(Color(0, 0, 0, 0), 9, Color(GOLD, 0.9), 2)
	b_focus.draw_center = false
	b_focus.expand_margin_left = 2
	b_focus.expand_margin_right = 2
	b_focus.expand_margin_top = 2
	b_focus.expand_margin_bottom = 2
	for type: StringName in [&"Button", &"OptionButton"]:
		t.set_stylebox(&"normal", type, b_normal)
		t.set_stylebox(&"hover", type, b_hover)
		t.set_stylebox(&"pressed", type, b_pressed)
		t.set_stylebox(&"hover_pressed", type, b_pressed)
		t.set_stylebox(&"disabled", type, b_disabled)
		t.set_stylebox(&"focus", type, b_focus)
		t.set_color(&"font_color", type, TEXT)
		t.set_color(&"font_hover_color", type, GOLD)
		t.set_color(&"font_focus_color", type, Color(1.0, 0.92, 0.7))
		t.set_color(&"font_pressed_color", type, GOLD)
		t.set_color(&"font_hover_pressed_color", type, GOLD)
		t.set_color(&"font_disabled_color", type, Color(0.5, 0.47, 0.42))
		t.set_font_size(&"font_size", type, 20)
	t.add_type(&"PlusButton")
	t.set_type_variation(&"PlusButton", &"Button")
	t.set_font_size(&"font_size", &"PlusButton", 22)

	# CheckButton (toggle switch)
	var empty := StyleBoxEmpty.new()
	for s in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
		t.set_stylebox(s, &"CheckButton", empty)
	t.set_stylebox(&"focus", &"CheckButton", b_focus)
	t.set_icon(&"checked", &"CheckButton", _toggle_tex(true))
	t.set_icon(&"unchecked", &"CheckButton", _toggle_tex(false))
	t.set_icon(&"checked_disabled", &"CheckButton", _toggle_tex(true))
	t.set_icon(&"unchecked_disabled", &"CheckButton", _toggle_tex(false))
	t.set_color(&"font_color", &"CheckButton", TEXT)
	t.set_color(&"font_hover_color", &"CheckButton", GOLD)
	t.set_color(&"font_pressed_color", &"CheckButton", TEXT)
	t.set_color(&"font_hover_pressed_color", &"CheckButton", GOLD)
	t.set_color(&"font_focus_color", &"CheckButton", TEXT)

	# Sliders
	var track := flat(Color(0.06, 0.05, 0.04, 0.95), 4, Color(GOLD_DIM, 0.5), 1)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	t.set_stylebox(&"slider", &"HSlider", track)
	var area := flat(Color(0.80, 0.62, 0.27), 4)
	area.content_margin_top = 4
	area.content_margin_bottom = 4
	t.set_stylebox(&"grabber_area", &"HSlider", area)
	t.set_stylebox(&"grabber_area_highlight", &"HSlider", flat(Color(0.93, 0.76, 0.34), 4))
	var grab := _circle_tex(26, Color(0.98, 0.92, 0.78), Color(0.55, 0.40, 0.18))
	t.set_icon(&"grabber", &"HSlider", grab)
	t.set_icon(&"grabber_highlight", &"HSlider", _circle_tex(26, Color(1.0, 0.95, 0.8), GOLD))
	t.set_icon(&"grabber_disabled", &"HSlider", grab)
	t.set_stylebox(&"focus", &"HSlider", b_focus)

	# Scrollbars / scroll container
	var sc_bg := flat(Color(0, 0, 0, 0.25), 5)
	sc_bg.content_margin_left = 4
	sc_bg.content_margin_right = 4
	t.set_stylebox(&"scroll", &"VScrollBar", sc_bg)
	t.set_stylebox(&"grabber", &"VScrollBar", flat(Color(GOLD_DIM, 0.75), 5))
	t.set_stylebox(&"grabber_highlight", &"VScrollBar", flat(GOLD, 5))
	t.set_stylebox(&"grabber_pressed", &"VScrollBar", flat(GOLD, 5))
	t.set_stylebox(&"panel", &"ScrollContainer", StyleBoxEmpty.new())

	# Popup menu (OptionButton list)
	t.set_stylebox(&"panel", &"PopupMenu", panel_box(Color(0.17, 0.13, 0.10, 0.98), Color(0.10, 0.08, 0.06, 0.98), Color(GOLD_DIM, 0.8), 8.0, 6.0))
	t.set_stylebox(&"hover", &"PopupMenu", flat(Color(0.45, 0.33, 0.16, 0.9), 5))
	t.set_color(&"font_color", &"PopupMenu", TEXT)
	t.set_color(&"font_hover_color", &"PopupMenu", Color(1, 0.95, 0.8))
	t.set_font_size(&"font_size", &"PopupMenu", 20)
	t.set_constant(&"v_separation", &"PopupMenu", 14)

	# Separators
	var sep := StyleBoxLine.new()
	sep.color = Color(GOLD_DIM, 0.4)
	sep.thickness = 1
	t.set_stylebox(&"separator", &"HSeparator", sep)
	t.set_constant(&"separation", &"HSeparator", 10)

	# Tooltips
	t.set_stylebox(&"panel", &"TooltipPanel", hud_panel(8.0))
	t.set_color(&"font_color", &"TooltipLabel", TEXT)
	return t


static func _variation(t: Theme, name: StringName, base: StringName, size: int, color: Color, outline: int, font: Font = null) -> void:
	t.add_type(name)
	t.set_type_variation(name, base)
	t.set_font_size(&"font_size", name, size)
	t.set_color(&"font_color", name, color)
	t.set_constant(&"outline_size", name, outline)
	t.set_color(&"font_outline_color", name, Color(0.08, 0.05, 0.03, 0.9))
	t.set_color(&"font_shadow_color", name, Color(0, 0, 0, 0.55))
	if font:
		t.set_font(&"font", name, font)


# ------------------------------------------------------------------ factories
static func label(text: String = "", variation: StringName = &"", size: int = 0) -> Label:
	var l := Label.new()
	l.text = text
	if variation != &"":
		l.theme_type_variation = variation
	if size > 0:
		l.add_theme_font_size_override(&"font_size", size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func button(text: String, min_w: float = 0.0, min_h: float = 52.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, min_h)
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func() -> void: Audio.play_sfx(&"ui_click", null, -6.0, 0.03))
	return b


static func full_rect(c: Control) -> Control:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c
