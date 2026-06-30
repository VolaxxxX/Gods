class_name Colossus3D
extends SubViewportContainer
## Cthulhu as a living BACKGROUND COLOSSUS (Typhon-style), rendered into a
## SubViewport anchored to the TOP of the screen on a background CanvasLayer and
## framed on the BUST. The model is a single UNRIGGED mesh, so credible motion is
## produced with a VERTEX-DISPLACEMENT SHADER (no bones needed):
##   - wings BEAT independently (displacement keyed to horizontal span, phase-
##     delayed across the wing so it ripples like a real wing-beat),
##   - face-tentacles WRITHE (travelling sine waves in the lower-front region),
##   - the whole body BREATHES (normal-driven swell),
##   - the eyes self-GLOW from the mesh (position-masked emission) with a fresnel
##     eldritch rim, and FLARE on every attack.
## On top, the root node does a slow menacing sway + a forward LUNGE toward the
## arena on each cast (enemy.gd -> group "colossus3d" -> on_boss_attack()).
## Drifting cyan spores add ambience. Tuned for the GL-compat / WebGL2 renderer.

const MODEL := "res://assets/models/cthulhu.glb"
const SKIN := Color(0.20, 0.42, 0.33)
const GLOW := Color(0.25, 1.0, 0.78)
const TARGET_H := 14.0
const CENTER_Y := 0.0
const AIM_Y := 4.8

const SHADER_CODE := """
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec3 ab_min;
uniform vec3 ab_size;
uniform float flare;
uniform float lunge;
uniform vec3 skin : source_color = vec3(0.20, 0.42, 0.33);
uniform vec3 glow : source_color = vec3(0.25, 1.0, 0.78);

varying vec3 vn;

void vertex() {
	vec3 n = (VERTEX - ab_min) / max(ab_size, vec3(0.001, 0.001, 0.001));
	vn = n;
	float t = TIME;
	// WINGS: more motion toward the horizontal extremes, phase-delayed across span.
	float wing = smoothstep(0.42, 1.0, abs(n.x - 0.5) * 2.0);
	float beat = sin(t * 1.7 - abs(n.x - 0.5) * 6.5);
	VERTEX.y += beat * wing * ab_size.y * (0.07 + lunge * 0.08);
	VERTEX.z += -abs(beat) * wing * ab_size.z * 0.06;       // sweep forward on down-beat
	// FACE-TENTACLES: lower (low n.y), front (high n.z), centre (n.x ~ 0.5).
	float tent = clamp((1.0 - n.y) * n.z * (1.0 - abs(n.x - 0.5) * 2.0), 0.0, 1.0);
	tent = pow(tent, 1.4);
	VERTEX.x += sin(t * 2.4 + n.y * 11.0) * tent * ab_size.x * 0.035;
	VERTEX.z += cos(t * 2.0 + n.y * 13.0) * tent * ab_size.z * 0.05;
	VERTEX.y += sin(t * 1.3 + n.x * 8.0) * tent * ab_size.y * 0.02;
	// BREATHING: gentle swell along normals.
	VERTEX += NORMAL * sin(t * 0.9) * ab_size.y * 0.013;
}

void fragment() {
	ALBEDO = skin;
	ROUGHNESS = 0.52;
	METALLIC = 0.12;
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	// EYES: upper-front-centre self-emission, flaring on attack.
	float eyemask = smoothstep(0.54, 0.80, vn.y)
		* smoothstep(0.52, 0.95, vn.z)
		* (1.0 - smoothstep(0.15, 0.42, abs(vn.x - 0.5)));
	EMISSION = glow * (fres * 0.25 + eyemask * (1.8 + flare * 5.5));
	RIM = 0.3;
}
"""

var _vp: SubViewport
var _root: Node3D
var _model: Node3D
var _eyeL: OmniLight3D
var _eyeR: OmniLight3D
var _shader: Shader
var _mats: Array[ShaderMaterial] = []
var _t: float = 0.0
var _lunge: float = 0.0
var _flare: float = 0.0

func _ready() -> void:
	add_to_group("colossus3d")
	anchor_left = 0.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 0.52
	offset_left = 0.0
	offset_right = 0.0
	offset_top = 0.0
	offset_bottom = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.size = Vector2i(720, 420)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)

	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.30, 0.48, 0.42)
	env.ambient_light_energy = 1.25
	we.environment = env
	_vp.add_child(we)

	var cam := Camera3D.new()
	cam.position = Vector3(0.0, AIM_Y, 9.6)
	cam.look_at(Vector3(0.0, AIM_Y, 0.0), Vector3.UP)
	cam.fov = 43.0
	_vp.add_child(cam)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38.0, -28.0, 0.0)
	key.light_color = Color(0.70, 1.0, 0.9); key.light_energy = 1.85
	_vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-12.0, 168.0, 0.0)
	rim.light_color = Color(0.45, 1.0, 0.82); rim.light_energy = 1.55
	_vp.add_child(rim)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-55.0, 40.0, 0.0)
	fill.light_color = Color(0.5, 0.7, 0.9); fill.light_energy = 0.35
	_vp.add_child(fill)

	_shader = Shader.new()
	_shader.code = SHADER_CODE
	_build()
	_add_motes()

func _make_mat(ab_min: Vector3, ab_size: Vector3) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("ab_min", ab_min)
	m.set_shader_parameter("ab_size", ab_size)
	m.set_shader_parameter("skin", SKIN)
	m.set_shader_parameter("glow", GLOW)
	m.set_shader_parameter("flare", 0.0)
	m.set_shader_parameter("lunge", 0.0)
	return m

func _build() -> void:
	_root = Node3D.new()
	_vp.add_child(_root)
	if not ResourceLoader.exists(MODEL):
		return
	_model = load(MODEL).instantiate()
	_root.add_child(_model)
	_apply_shader(_model)
	_fit(_model)
	for sgn in [-1.0, 1.0]:
		var lt := OmniLight3D.new()
		lt.light_color = GLOW
		lt.light_energy = 3.4
		lt.omni_range = 7.5
		lt.omni_attenuation = 1.0
		lt.position = Vector3(sgn * 1.1, AIM_Y + 1.2, 3.8)
		_root.add_child(lt)
		if sgn < 0.0: _eyeL = lt
		else: _eyeR = lt

## Each mesh gets its OWN shader material carrying that mesh's local AABB, so the
## vertex shader can normalise positions and place wing/tentacle/eye regions.
func _apply_shader(n: Node) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var ab: AABB = (n as MeshInstance3D).mesh.get_aabb()
		var m := _make_mat(ab.position, ab.size)
		(n as MeshInstance3D).material_override = m
		_mats.append(m)
	for c in n.get_children():
		_apply_shader(c)

func _fit(model: Node3D) -> void:
	var ab := _calc_aabb(model)
	if ab.size.length() < 0.001:
		return
	var maxd: float = maxf(ab.size.x, maxf(ab.size.y, ab.size.z))
	var s: float = TARGET_H / maxd
	model.scale = Vector3(s, s, s)
	var c: Vector3 = ab.position + ab.size * 0.5
	model.position = -c * s + Vector3(0.0, CENTER_Y, 0.0)

func _calc_aabb(n: Node) -> AABB:
	var out := AABB()
	var has := false
	var stack: Array = [n]
	while not stack.is_empty():
		var x = stack.pop_back()
		if x is MeshInstance3D and (x as MeshInstance3D).mesh != null:
			var wa: AABB = (x as MeshInstance3D).global_transform * (x as MeshInstance3D).mesh.get_aabb()
			if not has:
				out = wa; has = true
			else:
				out = out.merge(wa)
		for c in x.get_children():
			stack.append(c)
	return out

## Drifting cyan spores for ambience. Added last so a failure here never blocks
## the colossus itself.
func _add_motes() -> void:
	var p := CPUParticles3D.new()
	p.amount = 40
	p.lifetime = 7.0
	p.position = Vector3(0.0, AIM_Y, 3.0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(7.5, 4.5, 1.5)
	p.direction = Vector3(0.0, 1.0, 0.0)
	p.spread = 35.0
	p.gravity = Vector3(0.0, 0.18, 0.0)
	p.initial_velocity_min = 0.04
	p.initial_velocity_max = 0.26
	p.scale_amount_min = 0.03
	p.scale_amount_max = 0.10
	var qm := QuadMesh.new()
	qm.size = Vector2(0.13, 0.13)
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	pm.albedo_color = Color(0.30, 1.0, 0.80, 0.45)
	pm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.material = pm
	p.mesh = qm
	_vp.add_child(p)

## Called by enemy.gd via call_group("colossus3d", ...) on every ability cast.
func on_boss_attack(_kind: String) -> void:
	_lunge = 1.0
	_flare = 1.0

func _process(delta: float) -> void:
	_t += delta
	_lunge = maxf(0.0, _lunge - delta * 2.0)
	_flare = maxf(0.0, _flare - delta * 1.5)
	var lunge_e: float = _lunge * _lunge
	for m in _mats:
		m.set_shader_parameter("flare", _flare)
		m.set_shader_parameter("lunge", lunge_e)
	if _root == null:
		return
	var bob: float = 0.20 * sin(_t * 0.8)
	_root.rotation.y = 0.10 * sin(_t * 0.4)
	_root.rotation.x = 0.04 * sin(_t * 0.6) + lunge_e * 0.20
	_root.position.y = bob - lunge_e * 0.7
	_root.position.z = lunge_e * 1.3
	var breathe: float = 1.0 + 0.04 * sin(_t * 0.9)
	_root.scale = Vector3(1.0, breathe, 1.0) * (1.0 + lunge_e * 0.05)
	var e: float = 3.0 + 1.3 * sin(_t * 2.4) + _flare * 7.0
	if _eyeL != null: _eyeL.light_energy = e
	if _eyeR != null: _eyeR.light_energy = e
