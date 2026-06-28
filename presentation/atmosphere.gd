class_name Atmosphere
extends RefCounted
## Procedural lighting + ambient particles — NO art assets required. Provides a
## radial light texture (generated once) for PointLight2D, an ambient particle
## overlay per realm, and a test for which props are light sources.

static var _light_tex: Texture2D

## A soft white radial gradient texture for 2D lights (generated, cached).
static func light_texture() -> Texture2D:
	if _light_tex != null:
		return _light_tex
	var n := 256
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := float(n) * 0.5
	for y in n:
		for x in n:
			var d := Vector2(x - c, y - c).length() / c
			var f: float = clampf(1.0 - d, 0.0, 1.0)
			f = f * f  # smoother falloff
			img.set_pixel(x, y, Color(1, 1, 1, f))
	_light_tex = ImageTexture.create_from_image(img)
	return _light_tex

## A PointLight2D with the generated texture, sized to `radius` world px.
static func point_light(color: Color, energy: float, radius: float) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = light_texture()
	l.color = color
	l.energy = energy
	l.texture_scale = radius / 128.0  # texture is 256px (128 = half)
	l.blend_mode = Light2D.BLEND_MODE_ADD
	return l

## Light-source props get their own warm glow.
static func is_light_prop(id: String) -> bool:
	for k in ["brazier", "torch", "lantern", "incense", "lava", "rune"]:
		if id.findn(k) != -1:
			return true
	return false

## A drifting ambient particle overlay covering a room of `size`. Kind:
## ember | dust | snow | petal. Returns null for an unknown/empty kind.
static func ambient_particles(kind: String, size: Vector2) -> CPUParticles2D:
	if kind == "":
		return null
	var p := CPUParticles2D.new()
	p.amount = 48
	p.lifetime = 6.0
	p.preprocess = 6.0  # already mid-fall when the room opens
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(size.x * 0.5, size.y * 0.5)
	p.position = size * 0.5
	p.local_coords = false
	match kind:
		"ember":
			p.gravity = Vector2(0, -28)            # embers rise
			p.color = Color(1.0, 0.55, 0.2, 0.8)
			p.scale_amount_min = 1.5
			p.scale_amount_max = 3.5
			p.initial_velocity_min = 6.0
			p.initial_velocity_max = 22.0
			p.angular_velocity_min = -40.0
			p.angular_velocity_max = 40.0
		"snow":
			p.gravity = Vector2(0, 26)
			p.color = Color(0.92, 0.96, 1.0, 0.85)
			p.scale_amount_min = 2.0
			p.scale_amount_max = 4.0
			p.initial_velocity_min = 8.0
			p.initial_velocity_max = 18.0
		"rain":
			p.amount = 90
			p.gravity = Vector2(0, 320)            # heavy fast rain
			p.color = Color(0.62, 0.74, 0.9, 0.5)
			p.scale_amount_min = 1.0
			p.scale_amount_max = 2.2
			p.initial_velocity_min = 130.0
			p.initial_velocity_max = 200.0
		"petal":
			p.gravity = Vector2(0, 22)
			p.color = Color(1.0, 0.7, 0.85, 0.85)
			p.scale_amount_min = 2.5
			p.scale_amount_max = 5.0
			p.initial_velocity_min = 10.0
			p.initial_velocity_max = 24.0
			p.angular_velocity_min = -80.0
			p.angular_velocity_max = 80.0
		_:  # dust (default)
			p.gravity = Vector2(0, 6)
			p.color = Color(0.9, 0.88, 0.8, 0.5)
			p.scale_amount_min = 1.0
			p.scale_amount_max = 2.5
			p.initial_velocity_min = 3.0
			p.initial_velocity_max = 10.0
	# A little horizontal drift so it never falls in straight lines.
	p.direction = Vector2(0.2, 1).normalized() if kind != "ember" else Vector2(-0.1, -1).normalized()
	p.spread = 35.0
	p.z_index = 30  # above the floor/props, below the HUD layer
	return p
