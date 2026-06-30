class_name Colossus3D
extends SubViewportContainer
## A MONUMENTAL 3D Cthulhu (assets/models/cthulhu.glb) rendered into a SubViewport
## and shown looming behind/above the arena, Typhon-style: only his massive bust,
## face tentacles and wing-span fill the TOP of the screen; the rest sinks behind
## the play field. The model ships with no textures/colour/rig, so we apply an
## eldritch material, intense glowing eyes, dynamic light and a procedural idle
## (deep breathing + menacing sway + eye pulse). Light for the GL-compat mobile
## renderer (low-res viewport, NEAREST upscale = pixel look).

const MODEL := "res://assets/models/cthulhu.glb"
const SKIN := Color(0.17, 0.35, 0.28)          # lighter so he reads against the green bg
const EYE := Color(0.25, 1.0, 0.75)            # electric cyan-green divine glare
const TARGET_H := 11.0                          # monumental: model far taller than the frame
const CENTER_Y := 3.2

var _vp: SubViewport
var _root: Node3D
var _model: Node3D
var _eyeL: OmniLight3D
var _eyeR: OmniLight3D
var _t: float = 0.0

func _ready() -> void:
	# Saturate the upper screen: full width, top ~64% height (only his bust shows).
	anchor_left = 0.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 0.64
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
	_vp.size = Vector2i(640, 420)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)

	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.22, 0.36, 0.32)
	env.ambient_light_energy = 0.9
	we.environment = env
	_vp.add_child(we)

	# Camera level with the bust so we read his upper mass; body falls below frame.
	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 5.2, 11.0)
	cam.look_at(Vector3(0.0, 5.0, 0.0), Vector3.UP)
	cam.fov = 52.0
	_vp.add_child(cam)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40.0, -30.0, 0.0)
	key.light_color = Color(0.65, 0.95, 0.85); key.light_energy = 1.1
	_vp.add_child(key)
	var rim := DirectionalLight3D.new()   # back rim for silhouette against the green bg
	rim.rotation_degrees = Vector3(-10.0, 165.0, 0.0)
	rim.light_color = Color(0.4, 1.0, 0.8); rim.light_energy = 1.0
	_vp.add_child(rim)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-60.0, 40.0, 0.0)
	fill.light_color = Color(0.5, 0.7, 0.9); fill.light_energy = 0.4
	_vp.add_child(fill)

	_build()

func _mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = SKIN
	m.roughness = 0.6
	m.metallic = 0.1
	m.emission_enabled = true
	m.emission = Color(0.08, 0.20, 0.16)
	m.emission_energy_multiplier = 0.9
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
	# Intense glowing eyes high on the head (electric cyan-green).
	for sgn in [-1.0, 1.0]:
		var lt := OmniLight3D.new()
		lt.light_color = EYE
		lt.light_energy = 3.2
		lt.omni_range = 9.0
		lt.position = Vector3(sgn * 0.9, CENTER_Y + TARGET_H * 0.30, 2.6)
		_root.add_child(lt)
		var orb := MeshInstance3D.new()
		var os := SphereMesh.new(); os.radius = 0.32; os.height = 0.64
		var em := StandardMaterial3D.new()
		em.albedo_color = EYE; em.emission_enabled = true; em.emission = EYE; em.emission_energy_multiplier = 6.0
		orb.mesh = os; orb.material_override = em
		orb.position = lt.position
		_root.add_child(orb)
		if sgn < 0.0: _eyeL = lt
		else: _eyeR = lt

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

func _process(delta: float) -> void:
	_t += delta
	if _root == null:
		return
	_root.rotation.y = 0.10 * sin(_t * 0.4)        # slow menacing sway
	_root.rotation.x = 0.03 * sin(_t * 0.65)
	if _model != null:
		var br := 1.0 + 0.045 * sin(_t * 0.9)       # deep breathing
		_model.scale.y = _model.scale.x * br
		_model.position.y = CENTER_Y + 0.15 * sin(_t * 0.9)
	var e: float = 2.6 + 1.1 * sin(_t * 2.6)        # eye pulse
	if _eyeL != null: _eyeL.light_energy = e
	if _eyeR != null: _eyeR.light_energy = e
