class_name AbilityData
extends Resource
## Static description of one essence ability. Instances live in AbilityLibrary.
## UI reads display_name / description / icon_color / icon_glyph.

@export var id: StringName = &""
@export var display_name := ""
@export_multiline var description := ""
@export var energy_cost := 0.0
@export var cooldown := 1.0
@export var icon_color := Color.WHITE
@export var icon_glyph := "?"          # short text glyph the UI can draw in the slot
@export var slottable := true          # false = passive unlock (never equipped)
@export var sfx: StringName = &""


static func make(p_id: StringName, p_name: String, p_desc: String, p_cost: float, p_cd: float,
		p_color: Color, p_glyph: String, p_sfx: StringName, p_slottable: bool = true) -> AbilityData:
	var a := AbilityData.new()
	a.id = p_id
	a.display_name = p_name
	a.description = p_desc
	a.energy_cost = p_cost
	a.cooldown = p_cd
	a.icon_color = p_color
	a.icon_glyph = p_glyph
	a.sfx = p_sfx
	a.slottable = p_slottable
	return a
