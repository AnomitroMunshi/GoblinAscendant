class_name HudBar
extends Control
## Resource bar with a smooth fill and a delayed "damage chip" trail.
## Call set_values(current, maximum); it animates only while changing
## (processing is switched off when settled, so idle bars cost nothing).

@export var fill_color := Color(0.86, 0.22, 0.20)
@export var chip_color := Color(1.0, 0.86, 0.55)
@export var back_color := Color(0.05, 0.04, 0.03, 0.85)
@export var show_text := false
@export var text_size := 13
@export var chip_delay := 0.45
@export var chip_speed := 0.6

var ratio := 1.0      # target
var shown := 1.0      # displayed fill
var chip := 1.0       # trailing chip
var flash := 0.0      # brief white flash on damage
var pulse := false    # low-value pulse (health)
var _hold := 0.0
var _text := ""
var _bg: StyleBoxFlat
var _fill_sb: StyleBoxFlat
var _chip_sb: StyleBoxFlat
var _t := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	var r := int(clampf(maxf(size.y, custom_minimum_size.y) * 0.5 - 1.0, 2.0, 5.0))
	_bg = UiTheme.flat(back_color, r + 1, Color(UiTheme.GOLD_DIM, 0.55), 1)
	_fill_sb = UiTheme.flat(fill_color, r)
	_chip_sb = UiTheme.flat(chip_color, r)
	set_process(false)


func set_colors(fill: Color, chip_c: Color = Color(1.0, 0.86, 0.55)) -> void:
	fill_color = fill
	chip_color = chip_c
	if _fill_sb:
		_fill_sb.bg_color = fill
		_chip_sb.bg_color = chip_c
	queue_redraw()


## Sets the value immediately (no animation), e.g. on first show.
func snap(current: float, maximum: float) -> void:
	set_values(current, maximum)
	shown = ratio
	chip = ratio
	_hold = 0.0


func set_values(current: float, maximum: float) -> void:
	var r := clampf(current / maxf(maximum, 0.001), 0.0, 1.0)
	if show_text:
		var t := "%d / %d" % [ceili(current), roundi(maximum)]
		if t != _text:
			_text = t
	if is_equal_approx(r, ratio):
		return
	if r < ratio:
		_hold = chip_delay
		flash = 0.6
	ratio = r
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	shown = lerpf(shown, ratio, 1.0 - exp(-delta * 14.0))
	if _hold > 0.0:
		_hold -= delta
	else:
		chip = move_toward(chip, ratio, delta * chip_speed)
	chip = maxf(chip, shown)
	flash = maxf(0.0, flash - delta * 3.0)
	if not pulse and absf(shown - ratio) < 0.001 and absf(chip - ratio) < 0.001 and flash <= 0.0:
		shown = ratio
		chip = ratio
		set_process(false)
	queue_redraw()


func set_pulse(on: bool) -> void:
	if pulse == on:
		return
	pulse = on
	if on:
		set_process(true)
	queue_redraw()


func _draw() -> void:
	if _bg == null:
		return
	var rect := Rect2(Vector2.ZERO, size)
	draw_style_box(_bg, rect)
	var inner := rect.grow(-2.0)
	if chip > shown + 0.002:
		var cw := inner.size.x * chip
		if cw >= 2.0:
			draw_style_box(_chip_sb, Rect2(inner.position, Vector2(cw, inner.size.y)))
	var fw := inner.size.x * shown
	if fw >= 2.0:
		var fill_rect := Rect2(inner.position, Vector2(fw, inner.size.y))
		var c := fill_color
		if pulse:
			c = c.lerp(Color(1, 0.75, 0.7), 0.25 + 0.25 * sin(_t * 7.0))
		if flash > 0.0:
			c = c.lerp(Color.WHITE, flash * 0.5)
		_fill_sb.bg_color = c
		draw_style_box(_fill_sb, fill_rect)
		# glossy top highlight
		draw_rect(Rect2(fill_rect.position + Vector2(1, 1), Vector2(fw - 2.0, inner.size.y * 0.4)), Color(1, 1, 1, 0.16))
	if show_text and _text != "":
		var font := get_theme_default_font()
		var ts := font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size)
		var pos := Vector2((size.x - ts.x) * 0.5, (size.y + text_size * 0.75) * 0.5)
		draw_string_outline(font, pos, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, 3, Color(0, 0, 0, 0.7))
		draw_string(font, pos, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, Color(1, 0.97, 0.9))
