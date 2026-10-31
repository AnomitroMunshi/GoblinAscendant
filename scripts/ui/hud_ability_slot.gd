class_name HudAbilitySlot
extends Control
## One ability slot (custom drawn): glyph in the ability colour, key hint,
## name below, vertical cooldown sweep + seconds, dim when not enough energy,
## padlock when empty. flash() on use, shake() on failure.

const SLOT := 60.0

var slot := 0
var key_text := "1"
var ability_id: StringName = &""
var _name := ""
var _color := Color.WHITE
var _glyph := ""
var _cd_ratio := 0.0
var _cd_secs := 0
var _cd_tenths := 0
var _cd_text := ""
var _no_energy := false
var _flash := 0.0
var _shake := 0.0
var _sb_bg: StyleBoxFlat
var _sb_border: StyleBoxFlat
var _poly := PackedVector2Array()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(88, SLOT + 22)


func _ready() -> void:
	_sb_bg = UiTheme.flat(Color(0.07, 0.055, 0.045, 0.82), 9)
	_sb_border = UiTheme.flat(Color(0, 0, 0, 0), 9, Color(UiTheme.GOLD_DIM, 0.6), 2)
	_sb_border.draw_center = false
	set_process(false)


## Called every frame by the bar; redraws only when something visible changed.
func update_state(id: StringName, cd_ratio: float, cd_remaining: float, enough_energy: bool) -> void:
	var dirty := false
	if id != ability_id:
		ability_id = id
		var info := UiData.ability_info(id)
		_name = info.get("name", "")
		_color = info.get("color", Color.WHITE)
		_glyph = info.get("glyph", "")
		dirty = true
	cd_ratio = clampf(cd_ratio, 0.0, 1.0)
	if absf(cd_ratio - _cd_ratio) > 0.002 or (cd_ratio == 0.0) != (_cd_ratio == 0.0):
		_cd_ratio = cd_ratio
		dirty = true
	var tenths := ceili(cd_remaining * 10.0)
	if tenths != _cd_tenths:
		_cd_tenths = tenths
		if cd_remaining <= 0.0:
			_cd_text = ""
		elif cd_remaining < 3.0:
			_cd_text = "%.1f" % (tenths / 10.0)
		elif ceili(cd_remaining) != _cd_secs:
			_cd_text = str(ceili(cd_remaining))
		_cd_secs = ceili(cd_remaining)
		dirty = true
	if enough_energy == _no_energy:
		_no_energy = not enough_energy
		dirty = true
	if dirty:
		queue_redraw()


func flash() -> void:
	_flash = 1.0
	set_process(true)


func shake() -> void:
	_shake = 1.0
	set_process(true)


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta * 3.0)
	_shake = maxf(0.0, _shake - delta * 2.5)
	if _flash <= 0.0 and _shake <= 0.0:
		set_process(false)
	queue_redraw()


func _draw() -> void:
	if _sb_bg == null:
		return
	var font := get_theme_default_font()
	var x0 := (size.x - SLOT) * 0.5
	if _shake > 0.0:
		x0 += sin(_shake * 40.0) * 6.0 * _shake
	var r := Rect2(x0, 0, SLOT, SLOT)
	var c := r.get_center()
	var locked := ability_id == &""
	draw_style_box(_sb_bg, r)
	if locked:
		_draw_padlock(c, Color(0.55, 0.5, 0.44, 0.55))
	else:
		# soft colour wash
		draw_rect(r.grow(-3), Color(_color, 0.12))
		_draw_glyph(c, _color.lightened(0.15))
	# energy shortfall: cold desaturating overlay
	if not locked and _no_energy and _cd_ratio <= 0.0:
		draw_rect(r.grow(-2), Color(0.04, 0.07, 0.16, 0.6))
	# cooldown: vertical sweep draining downward
	if not locked and _cd_ratio > 0.0:
		var h := (SLOT - 4.0) * _cd_ratio
		draw_rect(Rect2(r.position.x + 2, r.position.y + 2, SLOT - 4.0, h), Color(0, 0, 0, 0.62))
		draw_line(Vector2(r.position.x + 3, r.position.y + 2 + h), Vector2(r.end.x - 3, r.position.y + 2 + h), Color(_color, 0.9), 2.0)
		if _cd_text != "":
			_text_centered(font, _cd_text, c + Vector2(0, 8), 22, Color(1, 0.97, 0.9))
	if _flash > 0.0:
		draw_rect(r.grow(-2), Color(1, 1, 1, 0.45 * _flash))
	var border_col := Color(UiTheme.GOLD_DIM, 0.5) if locked else (_color if not _no_energy else Color(0.35, 0.45, 0.7))
	if _shake > 0.0:
		border_col = border_col.lerp(UiTheme.BAD, _shake)
	_sb_border.border_color = border_col
	draw_style_box(_sb_border, r)
	# key hint (top-left keycap)
	var kp := r.position + Vector2(-4, -6)
	draw_rect(Rect2(kp, Vector2(20, 20)), Color(0.1, 0.08, 0.06, 0.95))
	draw_rect(Rect2(kp, Vector2(20, 20)), Color(UiTheme.GOLD, 0.8), false, 1.0)
	_text_centered(font, key_text, kp + Vector2(10, 15), 14, UiTheme.GOLD)
	# name
	if not locked:
		_text_centered(font, _name, Vector2(size.x * 0.5, SLOT + 17), 13, Color(UiTheme.TEXT, 0.92), true)


func _text_centered(font: Font, t: String, baseline_center: Vector2, fs: int, col: Color, outline: bool = true) -> void:
	var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var p := Vector2(baseline_center.x - w * 0.5, baseline_center.y)
	if outline:
		draw_string_outline(font, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.75))
	draw_string(font, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _draw_padlock(c: Vector2, col: Color) -> void:
	draw_arc(c + Vector2(0, -4), 7.0, PI, TAU, 12, col, 3.0, true)
	draw_rect(Rect2(c + Vector2(-10, -4), Vector2(20, 15)), col)
	draw_circle(c + Vector2(0, 3), 2.2, Color(0.07, 0.055, 0.045))


## Simple vector glyphs per ability (the default font lacks most symbols).
func _draw_glyph(c: Vector2, col: Color) -> void:
	match ability_id:
		&"wolf_dash":
			for i in 3:
				var o := Vector2(-12 + i * 9, 0)
				draw_polyline(PackedVector2Array([c + o + Vector2(-5, -11), c + o + Vector2(5, 0), c + o + Vector2(-5, 11)]), Color(col, 0.55 + 0.22 * i), 4.0, true)
		&"stone_guard":
			var pts := PackedVector2Array([c + Vector2(0, -15), c + Vector2(13, -9), c + Vector2(11, 6), c + Vector2(0, 16), c + Vector2(-11, 6), c + Vector2(-13, -9)])
			draw_colored_polygon(pts, Color(col, 0.85))
			pts.append(pts[0])
			draw_polyline(pts, col.lightened(0.35), 2.0, true)
			draw_line(c + Vector2(0, -11), c + Vector2(0, 12), Color(0.2, 0.13, 0.06, 0.7), 2.0)
		&"flame_burst":
			_poly.resize(0)
			for i in 16:
				var a := float(i) / 16.0 * TAU
				var rad := 10.0
				var p := Vector2(sin(a) * rad, cos(a) * rad)
				if p.y < 0.0:
					p.x *= 1.0 + p.y / 16.0
					p.y *= 2.0
				_poly.append(c + p + Vector2(0, 4))
			draw_colored_polygon(_poly, Color(col, 0.95))
			draw_circle(c + Vector2(0, 7), 5.0, Color(1, 0.9, 0.5))
		_:
			var font := get_theme_default_font()
			if _glyph != "" and font.has_char(_glyph.unicode_at(0)):
				_text_centered(font, _glyph, c + Vector2(0, 10), 28, col)
			else:
				draw_circle(c, 11.0, Color(col, 0.85))
				draw_arc(c, 15.0, 0, TAU, 24, col, 2.0, true)
