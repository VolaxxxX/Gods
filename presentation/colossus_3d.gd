class_name Colossus3D
extends SubViewportContainer
## Cthulhu as a living BACKGROUND COLOSSUS (Typhon-style), rendered into a
## SubViewport anchored to the TOP of the screen and framed on the BUST.
## The model is now a RIGGED, SKINNED glb (assets/models/cthulhu.glb) carrying a
## looping "idle" skeletal animation (wings beat, tentacles writhe, head bob,
## breathing) authored in Blender. An AnimationPlayer drives it; on top, the root
## node does a slow sway and a forward LUNGE toward the arena on every cast, and
## the eyes FLARE cyan (enemy.gd -> group "colossus3d" -> on_boss_attack()).
## Drifting cyan spores add ambience. Tuned for the GL-compat / WebGL2 renderer.

const MODEL := "res://assets/models/cthulhu.glb"
const SKIN := Color(0.20, 0.42, 0.33)
const GLOW := Color(0.25, 1.0, 0.78)
const TARGET_H := 14.0
const CENTER_Y := 0.0
const AIM_Y := 4.8

var _vp: SubViewport
var _root: Node3D
var _model: Node3D
var _eyeL: OmniLight3D
var _eyeR: OmniLight3D
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

	_build()
	_add_motes()

func _mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = SKIN
	m.roughness = 0.55
	m.metallic = 0.12
	m.emission_enabled = true
	m.emission = Color(0.08, 0.22, 0.17)
	m.emission_energy_multiplier = 1.3
	m.rim_enabled = true
	m.rim = 0.5
	m.rim_tint = 0.4
	return m

func _build() -> void:
	_root = Node3D.new()
	_vp.add_child(_root)
	if not ResourceLoader.exists(MODEL):
		return
	_model = load(MODEL).instantiate()
	_root.add_child(_model)
	_apply_material(_model, _mat())
	_fit(_model)
	_play_idle(_model)
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

## Find the glb's AnimationPlayer and loop its skeletal idle clip.
func _play_idle(n: Node) -> void:
	var ap := _find_anim_player(n)
	if ap == null:
		return
	var list := ap.get_animation_list()
	if list.is_empty():
		return
	var an: String = list[0]
	var a := ap.get_animation(an)
	if a != null:
		a.loop_mode = Animation.LOOP_LINEAR
	ap.play(an)

func _find_anim_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n as AnimationPlayer
	for c in n.get_children():
		var r := _find_anim_player(c)
		if r != null:
			return r
	return null

func _apply_material(n: Node, mat: StandardMaterial3D) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_override = mat
	for c in n.get_children():
		_apply_material(c, mat)

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
	if _root == null:
		return
	var lunge_e: float = _lunge * _lunge
	var bob: float = 0.20 * sin(_t * 0.8)
	_root.rotation.y = 0.10 * sin(_t * 0.4)
	_root.rotation.x = 0.04 * sin(_t * 0.6) + lunge_e * 0.20
	_root.position.y = bob - lunge_e * 0.7
	_root.position.z = lunge_e * 1.3
	var e: float = 3.0 + 1.3 * sin(_t * 2.4) + _flare * 7.0
	if _eyeL != null: _eyeL.light_energy = e
	if _eyeR != null: _eyeR.light_energy = e
