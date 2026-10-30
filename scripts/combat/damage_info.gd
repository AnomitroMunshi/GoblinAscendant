class_name DamageInfo
extends RefCounted
## Describes one hit. Passed to `take_damage(info) -> int` on any damageable.
## Return one of Result. Lead-owned shared interface.

enum Result { IGNORED, HIT, BLOCKED, KILLED }

var amount: float = 10.0
var source: Node3D                       # attacker (may be null for environment)
var knockback_force: float = 2.0         # metres/second impulse magnitude
var knockback: Vector3 = Vector3.ZERO    # filled by Hitbox from attacker -> target
var hit_position: Vector3 = Vector3.ZERO
var stagger: float = 0.3                 # 0..1; >= 0.5 interrupts the target (hurt state)
var is_heavy: bool = false               # heavy hits trigger hit-stop + stronger shake
var element: StringName = &"physical"    # &"physical", &"fire"
var unblockable: bool = false            # e.g. ogre grab/slam shockwave
var attack_id: StringName = &""          # for debugging / analytics


static func make(p_amount: float, p_source: Node3D = null, p_knockback: float = 2.0, p_stagger: float = 0.3) -> DamageInfo:
	var d := DamageInfo.new()
	d.amount = p_amount
	d.source = p_source
	d.knockback_force = p_knockback
	d.stagger = p_stagger
	return d


func copy() -> DamageInfo:
	var d := DamageInfo.new()
	d.amount = amount
	d.source = source
	d.knockback_force = knockback_force
	d.knockback = knockback
	d.hit_position = hit_position
	d.stagger = stagger
	d.is_heavy = is_heavy
	d.element = element
	d.unblockable = unblockable
	d.attack_id = attack_id
	return d
