class_name Interactable
extends Area3D
## Something the player can use with [E]. Lead-owned shared primitive.
## The player's interaction detector (mask Layers.INTERACT) picks the nearest
## enabled Interactable and shows `prompt` via Events.interaction_prompt_changed.
##
##     var it := Interactable.new()
##     it.interact_id = &"glade_signpost"
##     it.prompt = "Read signpost"
##     it.radius = 2.0
##     it.interacted.connect(_on_used)
##     add_child(it)

signal interacted(actor: Node)

@export var interact_id: StringName = &""
@export var prompt := "Interact"
@export var enabled := true
@export var radius := 2.0


func _init() -> void:
	collision_layer = Layers.INTERACT
	collision_mask = 0
	monitoring = false
	monitorable = true


func _ready() -> void:
	for c in get_children():
		if c is CollisionShape3D:
			return
	var cs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	cs.shape = sphere
	add_child(cs)


func can_interact(_actor: Node) -> bool:
	return enabled and is_inside_tree()


func interact(actor: Node) -> void:
	if not can_interact(actor):
		return
	interacted.emit(actor)
	Events.interacted.emit(interact_id, actor)
