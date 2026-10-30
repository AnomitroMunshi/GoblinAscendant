class_name UiWindow
extends CenterContainer
## Centred menu window: gold-outlined panel with a serif header, a close (×)
## button and a content VBox. Size adapts to the parent (fits any aspect).
## Emits close_requested when × is clicked.

signal close_requested

var panel: PanelContainer
var content: VBoxContainer
var header: Label
var close_button: Button
var footer: HBoxContainer
var desired := Vector2(720, 640)


func _init(title: String = "", p_desired: Vector2 = Vector2(720, 640), closable: bool = true) -> void:
	desired = p_desired
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override(&"separation", 10)
	panel.add_child(outer)
	var head := HBoxContainer.new()
	outer.add_child(head)
	header = UiTheme.label(title, &"HeaderLabel")
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(header)
	close_button = UiTheme.button("×", 44, 44)
	close_button.add_theme_font_size_override(&"font_size", 26)
	close_button.tooltip_text = "Close (Esc)"
	close_button.pressed.connect(func() -> void: close_requested.emit())
	close_button.visible = closable
	head.add_child(close_button)
	outer.add_child(HSeparator.new())
	content = VBoxContainer.new()
	content.add_theme_constant_override(&"separation", 8)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(content)
	footer = HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override(&"separation", 10)
	outer.add_child(footer)


func _ready() -> void:
	resized.connect(_fit)
	_fit()


## Panel size = desired, clamped to the available area.
func _fit() -> void:
	var avail := size - Vector2(48, 48)
	if avail.x <= 0.0 or avail.y <= 0.0:
		return
	var w := minf(desired.x, avail.x)
	var h := minf(desired.y, avail.y) if desired.y > 0.0 else 0.0
	panel.custom_minimum_size = Vector2(w, h)
	panel.size = Vector2.ZERO


## Scroll area filling the content (for long lists).
func add_scroll() -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override(&"separation", 8)
	sc.add_child(v)
	return v
