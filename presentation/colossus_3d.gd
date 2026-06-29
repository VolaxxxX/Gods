class_name Colossus3D
extends SubViewportContainer
## A real-time 3D colossus (Cthulhu) rendered into a SubViewport and shown behind
## the 2D arena, Typhon-style. Built fully from procedural meshes (no external
## model). Tentacles writhe INDEPENDENTLY (each its own phase/speed); eyes glow
## and pulse; the body breathes and sways. Kept light for the GL-compat mobile
## renderer (low-res viewport, NEAREST upscale = pixel look).

var _vp: SubViewport
var _root: Node3D
var _body: Node3D
var _eyeL: OmniLight3D
var _eyeR: OmniLight3D
var _eye_mats: Array = []
var _tentacles: Array = []   # {segs:Array, origin:Vector3, dir:Vector3, phase, speed, len, bend}
var _t: float = 0.0

const TEAL := Color(0.10, 0.27, 0.21)
const TEAL_DARK := Color(0.06, 0.17, 0.14)

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # crisp pixel upscale
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.size = Vector2i(420, 420)
	_vp.disable_3d = false
	_vp.own_world_3d = true
	add_child(_vp)

	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.18, 0.30, 0.27)
	env.ambient_light_energy = 0.7
	we.environment = env
	_vp.add_child(we)

	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 1.2, 9.2)
	cam.look_at(Vector3(0.0, 3.0, 0.0), Vector3.UP)  # look UP at the towering god
	cam.fov = 55.0
	_vp.add_child(cam)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-45.0, -35.0, 0.0)
	key.light_color = Color(0.55, 0.85, 0.75)
	key.light_energy = 0.8
	_vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20.0, 150.0, 0.0)
	rim.light_color = Color(0.4, 0.9, 0.7)
	rim.light_energy = 0.5
	_vp.add_child(rim)

	_build()

func _mat(col: Color, emis: Color = Color(0, 0, 0), emis_e: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.72
	m.metallic = 0.05
	if emis_e > 0.0:
		m.emission_enabled = true
		m.emission = emis
		m.emission_energy_multiplier = emis_e
	return m

func _build() -> void:
	_root = Node3D.new()
	_vp.add_child(_root)
	_body = Node3D.new()
	_body.position = Vector3(0.0, 2.6, 0.0)
	_root.add_child(_body)

	var bmat := _mat(TEAL, Color(0.04, 0.12, 0.09), 0.6)
	# Torso (big squashed sphere)
	var torso := MeshInstance3D.new()
	var ts := SphereMesh.new(); ts.radius = 1.7; ts.height = 3.4
	torso.mesh = ts; torso.material_override = bmat
	torso.position = Vector3(0.0, -0.4, 0.0); torso.scale = Vector3(1.25, 1.15, 1.0)
	_body.add_child(torso)
	# Head
	var head := MeshInstance3D.new()
	var hs := SphereMesh.new(); hs.radius = 1.15; hs.height = 2.0
	head.mesh = hs; head.material_override = bmat
	head.position = Vector3(0.0, 1.3, 0.25)
	_body.add_child(head)
	# Wings (thin angled boxes behind)
	var wmat := _mat(TEAL_DARK, Color(0.03, 0.10, 0.08), 0.4)
	for sgn in [-1.0, 1.0]:
		var wing := MeshInstance3D.new()
		var wb := BoxMesh.new(); wb.size = Vector3(2.6, 3.4, 0.18)
		wing.mesh = wb; wing.material_override = wmat
		wing.position = Vector3(sgn * 1.7, 0.6, -0.9)
		wing.rotation_degrees = Vector3(8.0, sgn * -28.0, sgn * 14.0)
		_body.add_child(wing)
	# Eyes
	var emat := _mat(Color(0.9, 0.1, 0.05), Color(1.4, 0.12, 0.05), 4.0)
	for sgn in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var es := SphereMesh.new(); es.radius = 0.22; es.height = 0.44
		eye.mesh = es; eye.material_override = emat
		eye.position = Vector3(sgn * 0.42, 1.45, 1.18)
		_body.add_child(eye)
		_eye_mats.append(emat)
		var lt := OmniLight3D.new()
		lt.light_color = Color(1.0, 0.15, 0.08); lt.light_energy = 2.0; lt.omni_range = 5.0
		lt.position = Vector3(sgn * 0.42, 1.45, 1.4)
		_body.add_child(lt)
		if sgn < 0.0: _eyeL = lt
		else: _eyeR = lt

	# Face tentacles — independent writhing chains hanging from the lower head
	var tmat := _mat(TEAL_DARK, Color(0.05, 0.14, 0.10), 0.5)
	var ntent := 6
	for i in ntent:
		var u := float(i) / float(ntent - 1) - 0.5
		var segs: Array = []
		var nseg := 7
		for s in nseg:
			var seg := MeshInstance3D.new()
			var ss := SphereMesh.new()
			var rr: float = lerpf(0.30, 0.10, float(s) / float(nseg - 1))
			ss.radius = rr; ss.height = rr * 2.0
			seg.mesh = ss; seg.material_override = tmat
			_body.add_child(seg)
			segs.append(seg)
		_tentacles.append({
			"segs": segs,
			"origin": Vector3(u * 1.5, 0.55, 1.05),
			"dir": Vector3(u * 0.5, -1.0, 0.25).normalized(),
			"phase": randf() * TAU,
			"speed": 1.1 + randf() * 1.2,
			"len": 2.6 + randf() * 1.0,
			"bend": 0.22 + randf() * 0.12,
		})

func _process(delta: float) -> void:
	_t += delta
	if _root == null:
		return
	# Slow menacing sway + breathing
	_root.rotation.y = 0.13 * sin(_t * 0.45)
	_root.rotation.x = 0.04 * sin(_t * 0.7)
	if _body != null:
		var br := 1.0 + 0.035 * sin(_t * 1.1)
		_body.scale = Vector3(1.0, br, 1.0)
	# Eye pulse
	var e := 1.7 + 0.7 * sin(_t * 3.0)
	if _eyeL != null: _eyeL.light_energy = e
	if _eyeR != null: _eyeR.light_energy = e
	# Independent tentacle writhe
	for tt in _tentacles:
		var p: Vector3 = tt["origin"]
		var dir: Vector3 = tt["dir"]
		var segs: Array = tt["segs"]
		var seglen: float = float(tt["len"]) / float(segs.size())
		for si in segs.size():
			var node: MeshInstance3D = segs[si]
			node.position = p
			var wob: float = sin(_t * float(tt["speed"]) + float(tt["phase"]) + float(si) * 0.6) * float(tt["bend"])
			# bend the direction sideways + a little forward over the chain length
			dir = (dir + Vector3(cos(float(tt["phase"]) + float(si)) * wob, wob * 0.3, sin(float(tt["phase"])) * wob * 0.5)).normalized()
			p += dir * seglen
