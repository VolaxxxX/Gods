class_name Colossus3D
extends SubViewportContainer
## Renders a real 3D Cthulhu model (assets/models/cthulhu.glb) into a SubViewport
## shown behind the 2D arena, Typhon-style. The model has no textures/colour/rig,
## so we apply an eldritch material, glowing eyes, dynamic light, and a procedural
## idle (breathe + menacing sway + eye pulse). Kept light for the GL-compat mobile
## renderer (low-res viewport, NEAREST upscale = pixel look).

const MODEL := "res://assets/models/cthulhu.glb"
const TEAL := Color(0.11, 0.27, 0.21)

var _vp: SubViewport
var _root: Node3D
var _model: Node3D
var _eyeL: OmniLight3D
var _eyeR: OmniLight3D
var _t: float = 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.size = Vector2i(480, 480)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)

	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.20, 0.32, 0.29)
	env.ambient_light_energy = 0.8
	we.environment = env
	_vp.add_child(we)

	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 1.2, 9.4)
	cam.look_at(Vector3(0.0, 3.0, 0.0), Vector3.UP)  # look UP at the towering god
	cam.fov = 55.0
	_vp.add_child(cam)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-45.0, -35.0, 0.0)
	key.light_color = Color(0.6, 0.9, 0.8); key.light_energy = 0.9
	_vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-15.0, 150.0, 0.0)
	rim.light_color = Color(0.35, 0.9, 0.7); rim.light_energy = 0.6
	_vp.add_child(rim)

	_build()

func _mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = TEAL
	m.roughness = 0.7
	m.metallic = 0.08
	m.emission_enabled = true
	m.emission = Color(0.05, 0.13, 0.10)
	m.emission_energy_multiplier = 0.5
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
	# Glowing eyes (the model has none): two red lights near the upper-front head.
	for sgn in [-1.0, 1.0]:
		var lt := OmniLight3D.new()
		lt.light_color = Color(1.0, 0.16, 0.08)
		lt.light_energy = 2.0
		lt.omni_range = 6.5
		lt.position = Vector3(sgn * 0.55, 4.1, 1.9)
		_root.add_child(lt)
		if sgn < 0.0: _eyeL = lt
		else: _eyeR = lt

func _apply_material(n: Node, mat: StandardMaterial3D) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_override = mat
	for c in n.get_children():
		_apply_material(c, mat)

## Auto-fit: normalise the model to ~5 units tall and centre it at (0, 2.6, 0),
## robust to whatever baked transforms the .glb ships with.
func _fit(model: Node3D) -> void:
	var ab := _calc_aabb(model)
	if ab.size.length() < 0.001:
		return
	var maxd: float = maxf(ab.size.x, maxf(ab.size.y, ab.size.z))
	var s: float = 5.0 / maxd
	model.scale = Vector3(s, s, s)
	var c: Vector3 = ab.position + ab.size * 0.5
	model.position = -c * s + Vector3(0.0, 2.6, 0.0)

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
	_root.rotation.y = 0.14 * sin(_t * 0.45)   # slow menacing sway
	_root.rotation.x = 0.04 * sin(_t * 0.7)
	if _model != null:
		_model.scale.y = _model.scale.x * (1.0 + 0.03 * sin(_t * 1.1))  # breathing
	var e: float = 1.7 + 0.7 * sin(_t * 3.0)
	if _eyeL != null: _eyeL.light_energy = e
	if _eyeR != null: _eyeR.light_energy = e
