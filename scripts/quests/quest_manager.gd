extends Node
## Quest chain state machine. OWNER: Progression & Quest agent.
## (Lead stub: public API other agents rely on. Keep signatures.)


func _ready() -> void:
	SaveManager.register("quests", self)


## Compact text for the HUD objective line.
func get_objective_text() -> String: return ""
## World position of the current objective for the compass, or null.
func get_objective_position() -> Variant: return null
func get_active_quest_title() -> String: return ""
func is_quest_completed(_quest_id: StringName) -> bool: return false
func is_quest_active(_quest_id: StringName) -> bool: return false
func get_save_data() -> Dictionary: return {}
func load_save_data(_d: Dictionary) -> void: pass
func reset() -> void: pass
