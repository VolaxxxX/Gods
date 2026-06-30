class_name Colossus3D
extends SubViewportContainer
## Cthulhu as a BACKGROUND COLOSSUS (Typhon-style), NOT a grid entity.
## A 3D model (assets/models/cthulhu.glb) is rendered into a SubViewport that is
## anchored to the TOP of the screen on a background CanvasLayer (see run_scene
## _enter_boss_camera, layer behind/over the floor). The camera frames only his
## BUST — head, face-tentacles, shoulders and wings fill the top; legs sit below
## the viewport and are never shown. Eyes are a SUBTLE cyan glow (soft lights),
## not geometric circles. Static model (no rig) → procedural breathing + sway.
## Light enough for the GL-compat mobile renderer (low-res viewport, NEAREST).

const MODEL := "res://assets/models/cthulhu.glb"
const SKIN := Color(0.20, 0.42, 0.33)
const GLOW := Color(0.25, 1.0, 0.78)   # electric cyan-green eye glow
const TARGET_H := 14.0                  # huge: only the upper body fits the frame
const CENTER_Y := 0.0
const AIM_Y := 4.8                      # camera frames the bust/shoulders/head

var _vp: SubViewport
var _root: Node3D
var _model: Node3D
var _eyeL: OmniLight3D
var _eyeR: OmniLight3D
var _t: float = 0.0

func _ready() -> void:
	# Top band, full width: the bust closes the horizon at the top of the screen.
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

	# Tight camera on the bust; legs fall below the frame.
	var cam := Camera3D.new()
	cam.position = Vector3(0.0, AIM_Y, 9.6)
	cam.look_at(Vector3(0.0, AIM_Y, 0.0), Vector3.UP)
	cam.fov = 43.0
	_vp.add_child(cam)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38.0, -28.0, 0.0)
	key.light_color = Color(0.70, 1.0, 0.9); key.light_energy = 1.75
	_vp.add_child(key)
	var rim := DirectionalLight3D.new()       # back rim → detaches him from the green bg
	rim.rotation_degrees = Vector3(-12.0, 168.0, 0.0)
	rim.light_color = Color(0.45, 1.0, 0.82); rim.light_energy = 1.5
	_vp.add_child(rim)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-55.0, 40.0, 0.0)
	fill.light_color = Color(0.5, 0.7, 0.9); fill.light_energy = 0.35
	_vp.add_child(fill)

	_build()

func _mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = SKIN
	m.roughness = 0.6
	m.metallic = 0.1
	m.emission_enabled = true
	m.emission = Color(0.10, 0.26, 0.20)
	m.emission_energy_multiplier = 1.4
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
	# SUBTLE eye glow: soft cyan lights near the head-front. No orb meshes / circles.
	for sgn in [-1.0, 1.0]:
		var lt := OmniLight3D.new()
		lt.light_color = GLOW
		lt.light_energy = 3.6
		lt.omni_range = 7.5
		lt.omni_attenuation = 1.0
		lt.position = Vector3(sgn * 1.1, AIM_Y + 1.2, 3.8)
		_root.add_child(lt)
		if sgn < 0.0: _eyeL = lt
		else: _eyeR = lt

func _apply_material(n: Node, mat: StandardMaterial3D) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_override = mat
	for c in n.get_children():
		_apply_material(c, mat)

## Normalise to TARGET_H tall, centred at (0, CENTER_Y, 0), robust to baked glb
## transforms — so the camera can frame the bust deterministically.
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
	_root.rotation.y = 0.10 * sin(_t * 0.4)
	_root.rotation.x = 0.025 * sin(_t * 0.6)
	if _model != null:
		_model.scale.y = _model.scale.x * (1.0 + 0.04 * sin(_t * 0.9))   # breathing
	var e: float = 3.0 + 1.4 * sin(_t * 2.4)                              # eye pulse
	if _eyeL != null: _eyeL.light_energy = e
	if _eyeR != null: _eyeR.light_energy = e
