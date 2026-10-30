class_name EnemyAdventurer
extends EnemyHumanoid
## Neutral human/elf adventurer. Never initiates (aggression 0). Whoever damages
## it (player or monster) gets a personal grudge; same-faction adventurers within
## ally_assist_radius help. Calms down ~20 s after the offender leaves.
## Talk: Interactable "adventurer_talk" -> short placeholder line via Events.notify.

## Placeholder dialogue, keyed by variant (data only; extend freely).
const LINES := [
	["Easy there, little one. We're just passing through.", "Wolves have been bold this season. Watch the woods.", "A goblin with manners? Now I've seen everything."],
	["Don't mind the shield. It's for the raiders, not you.", "The outpost to the east is trouble. Keep clear.", "Need a rest? The fire's warm."],
	["The forest remembers kindness, small one.", "I heard an ogre roar from the north clearing.", "Your kind are not all raiders. I see that now."],
]
const ANGRY_LINE := "Back off! We're done talking."

var talk: Interactable
var _line_index := 0


func _default_type() -> StringName:
	return &"adventurer"


func _after_ready() -> void:
	talk = Interactable.new()
	talk.name = "Talk"
	talk.interact_id = &"adventurer_talk"
	talk.prompt = "Talk to %s" % display_name
	talk.radius = 2.2
	talk.position = Vector3(0, 1.0, 0)
	talk.interacted.connect(_on_talk)
	add_child(talk)


func _custom_process(_delta: float) -> void:
	if talk:
		talk.enabled = _grudges.is_empty() and state not in [State.CHASE, State.ATTACK, State.RECOVER, State.HURT]


func _on_talk(actor: Node) -> void:
	if is_dead():
		return
	if has_grudge(actor):
		Events.notify.emit("%s: %s" % [display_name, ANGRY_LINE], &"info")
		return
	var lines: Array = LINES[variant % LINES.size()]
	Events.notify.emit("%s: %s" % [display_name, lines[_line_index % lines.size()]], &"info")
	_line_index += 1
	if actor is Node3D:
		_face_dir = _flat((actor as Node3D).global_position - global_position)
		rotation.y = atan2(-_face_dir.x, -_face_dir.z)


func _die(info: DamageInfo) -> void:
	if talk:
		talk.enabled = false
	super(info)
