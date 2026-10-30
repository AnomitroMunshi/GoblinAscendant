class_name EnemyAttack
extends RefCounted
## One telegraphed enemy attack: wind-up -> explicit active window -> recovery.
## Shapes are sized to the actual weapon reach (no oversized volumes).

var id: StringName = &"attack"
var anim: StringName = &"chop"     # pose family used by the model animation
var min_range := 0.0
var max_range := 2.0               # start the attack only when the target is inside this
var windup := 0.5
var active := 0.15
var recovery := 0.7
var damage := 10.0
var knockback := 3.0
var stagger := 0.4
var heavy := false
var unblockable := false
var element: StringName = &"physical"
var shape: Shape3D
var offset := Vector3(0, 1, -1)    # hitbox centre in the attacker's body space (-Z forward)
var lunge_speed := 0.0             # forward dash during the active window
var step_back := 0.0               # m/s backwards during wind-up (anticipation)
var cooldown := 0.0
var weight := 1.0
var track := 1.0                   # how much the attacker keeps turning during wind-up
var marker_radius := 0.0           # > 0: ground danger decal at the impact point during wind-up
var ring_radius := 0.0             # telegraph ring around the feet (0 = max_range)
var los_required := true           # hitbox requires LOS (false for ground AoE)
var enabled := true
var ready_at := 0.0


static func make(p_id: StringName, p_anim: StringName, p_damage: float, p_windup: float, p_active: float,
		p_recovery: float, p_max_range: float, p_shape: Shape3D, p_offset: Vector3) -> EnemyAttack:
	var a := EnemyAttack.new()
	a.id = p_id
	a.anim = p_anim
	a.damage = p_damage
	a.windup = p_windup
	a.active = p_active
	a.recovery = p_recovery
	a.max_range = p_max_range
	a.shape = p_shape
	a.offset = p_offset
	return a


static func sphere(r: float) -> SphereShape3D:
	var s := SphereShape3D.new()
	s.radius = r
	return s


static func box(size: Vector3) -> BoxShape3D:
	var b := BoxShape3D.new()
	b.size = size
	return b


func is_ready(now: float) -> bool:
	return enabled and now >= ready_at


func make_info(src: Node3D) -> DamageInfo:
	var d := DamageInfo.make(damage, src, knockback, stagger)
	d.is_heavy = heavy
	d.unblockable = unblockable
	d.element = element
	d.attack_id = id
	return d
