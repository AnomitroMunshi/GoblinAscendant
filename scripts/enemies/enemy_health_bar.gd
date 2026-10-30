class_name EnemyHealthBar
extends Node3D
## World-space billboard health bar (+ optional name) above an enemy. Fades in/out.

const SHADER := preload("res://shaders/enemies/health_bar.gdshader")

var _quad: MeshInstance3D
var _mat: ShaderMaterial
var _label: Label3D
var _ratio := 1.0
var _lag := 1.0
var _lag_delay := 0.0
var _alpha := 0.0
var target_alpha := 0.0
var show_bar := true


func setup(width: float, title: String, p_show_bar: bool = true) -> void:
	show_bar = p_show_bar
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("size", Vector2(width, width * 0.11))
	_mat.set_shader_parameter("alpha", 0.0)
	_quad = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(width, width * 0.11)
	_quad.mesh = q
	_quad.material_override = _mat
	_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_quad.visible = show_bar
	add_child(_quad)
	if title != "":
		_label = Label3D.new()
		_label.text = title
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.pixel_size = 0.004
		_label.font_size = 40
		_label.outline_size = 10
		_label.modulate = Color(1, 0.92, 0.75, 0)
		_label.outline_modulate = Color(0, 0, 0, 0)
		_label.position = Vector3(0, 0.2, 0)
		_label.no_depth_test = false
		add_child(_label)
	visible = false


func set_ratio(r: float) -> void:
	r = clampf(r, 0.0, 1.0)
	if r < _ratio:
		_lag_delay = 0.45
	else:
		_lag = r
	_ratio = r


func _process(delta: float) -> void:
	_alpha = move_toward(_alpha, target_alpha, delta * (4.0 if target_alpha > _alpha else 1.5))
	visible = _alpha > 0.01
	if not visible:
		return
	if _lag_delay > 0.0:
		_lag_delay -= delta
	else:
		_lag = move_toward(_lag, _ratio, delta * 0.8)
	if _mat:
		_mat.set_shader_parameter("ratio", _ratio)
		_mat.set_shader_parameter("lag", maxf(_lag, _ratio))
		_mat.set_shader_parameter("alpha", _alpha)
	if _label:
		_label.modulate.a = _alpha
		_label.outline_modulate.a = _alpha * 0.8
