class_name Projectile
extends DamageArea
## A pooled, moving damage area. Greybox visual is code-drawn. Despawns on world
## hit, on hurtbox hit (unless piercing), or when its lifetime expires. Pooled by
## ProjectilePool to keep allocations (and Web GC pressure) near zero.

var velocity: Vector2 = Vector2.ZERO
var radius: float = 6.0
var color: Color = Color(1, 1, 0.6)
var _life: float = 0.0
var _max_life: float = 2.0
var active: bool = false
var by_player: bool = false  # set on fire(): player shots add crunch (knockback/juice) on hit

## Optional on-hit hook (pos, hurtbox) for blessing/synergy effects.
var on_hit_extra: Callable = Callable()

const ANIM_FPS := 16.0

var _shape: CollisionShape2D
var _spr: Sprite2D  # optional projectile texture; greybox disc when absent
var _hit_ids: Dictionary = {}  # hurtboxes already hit this shot (pierce: once each)
# Animated-projectile state: a sprite whose width > height is a horizontal strip
# (frames = width/height) — it cycles and faces its velocity (flames, bolts, …).
var _atlas: AtlasTexture
var _frames: int = 1
var _fs: int = 0
var _aframe: float = 0.0

func _ready() -> void:
	_shape = CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	_shape.shape = circle
	add_child(_shape)
	_spr = Sprite2D.new()
	_spr.visible = false
	add_child(_spr)
	_atlas = AtlasTexture.new()
	hit.connect(_on_hit)
	# Walls are physics bodies, not areas, so despawn on body contact too.
	body_entered.connect(_on_body_entered)
	_deactivate()

func fire(p_pos: Vector2, p_velocity: Vector2, dmg: Damage, faction_player: bool,
		p_radius: float = 6.0, p_color: Color = Color(1, 1, 0.6), life: float = 2.0,
		pierce_through: bool = false, sprite_name: String = "") -> void:
	global_position = p_pos
	velocity = p_velocity
	by_player = faction_player
	radius = p_radius
	color = p_color
	_max_life = life
	_life = 0.0
	on_hit_extra = Callable()  # reset; weapon re-assigns per shot if needed
	_hit_ids.clear()           # fresh per shot (pierce hits each target once)
	setup(dmg, pierce_through, 0.0)  # projectiles are single-hit
	(_shape.shape as CircleShape2D).radius = radius
	# Player projectiles hit enemy hurtboxes (+ walls); enemy projectiles hit
	# the player hurtbox (+ walls).
	if faction_player:
		collision_layer = Collision.PLAYER_DMG
		collision_mask = Collision.ENEMY_HURT | Collision.WORLD
	else:
		collision_layer = Collision.ENEMY_DMG
		collision_mask = Collision.PLAYER_HURT | Collision.WORLD
	# Optional projectile sprite; greybox disc otherwise. A faction-specific art
	# (e.g. blue/red orb) is shown as-is; only a generic projectile is tinted.
	var faction_name := "projectile_player" if faction_player else "projectile_enemy"
	# A per-source themed projectile (e.g. projectile_greece_hydra) wins if present.
	var use_name := faction_name
	if sprite_name != "" and Sprites.has_fx(sprite_name):
		use_name = sprite_name
	var has_specific := Sprites.has_fx(use_name)
	var tex := Sprites.fx(use_name)
	_spr.visible = tex != null
	_frames = 1
	_spr.rotation = 0.0
	if tex != null:
		_spr.modulate = Color.WHITE if has_specific else color
		var w := tex.get_width()
		var h := tex.get_height()
		if w > h and h > 0:
			# Animated horizontal strip: cycle frames and point along the shot.
			_frames = maxi(1, int(round(float(w) / float(h))))
			_fs = h
			_aframe = 0.0
			_atlas.atlas = tex
			_atlas.region = Rect2(0, 0, _fs, _fs)
			_spr.texture = _atlas
			_spr.scale = Vector2.ONE * (2.0 * radius / float(_fs))
			_spr.rotation = velocity.angle()
		else:
			_spr.texture = tex
			var dim: float = maxf(w, h)
			if dim > 0.0:
				_spr.scale = Vector2.ONE * (2.0 * radius / dim)
	_activate()

func _physics_process(delta: float) -> void:
	if not active:
		return
	global_position += velocity * delta
	if _frames > 1:
		_aframe += delta * ANIM_FPS
		_atlas.region = Rect2((int(_aframe) % _frames) * _fs, 0, _fs, _fs)
	elif _spr == null or not _spr.visible:
		queue_redraw()  # greybox bolt: animate the pulse + comet trail along flight
	_life += delta
	if _life >= _max_life:
		_deactivate()

## Each target is damaged at most once per shot — so a piercing projectile that
## lingers inside a big hurtbox can't re-hit it every frame.
func can_hit(hurtbox: HurtboxComponent) -> bool:
	return not _hit_ids.has(hurtbox.get_instance_id())

func mark_hit(hurtbox: HurtboxComponent) -> void:
	_hit_ids[hurtbox.get_instance_id()] = true

func _on_hit(hurtbox: HurtboxComponent) -> void:
	if on_hit_extra.is_valid():
		on_hit_extra.call(global_position, hurtbox)
	Fx.play("impact", global_position, 46.0)
	if by_player:
		# Crunch so a shot feels like it LANDS: shove the struck enemy back along
		# the shot's line (bosses/minibosses stand their ground). The white flash,
		# damage number and hit SFX already fire from the health/Juice/Audio buses.
		var struck = hurtbox.get_parent() if hurtbox != null else null
		if struck != null and struck.has_method("apply_knockback"):
			var is_boss: bool = struck.data != null and String(struck.data.role) in ["boss", "miniboss"]
			if not is_boss:
				struck.apply_knockback(velocity.normalized() * 95.0)
	if not pierce:
		_deactivate()

func _on_body_entered(_body: Node) -> void:
	# Any solid body (wall/obstacle) stops the projectile.
	_deactivate()

func _draw() -> void:
	if not active:
		return
	var dir := velocity.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	# A soft coloured glow halo under EVERYTHING (bespoke sprite OR greybox), so a
	# shot is always clearly visible on any floor — even a small/dim sprite pops.
	draw_circle(Vector2.ZERO, radius * 2.6, Color(color.r, color.g, color.b, 0.10))
	draw_circle(Vector2.ZERO, radius * 1.7, Color(color.r, color.g, color.b, 0.22))
	if _spr != null and _spr.visible:
		return  # the bespoke sprite draws the body; the glow above is enough
	# Greybox comet bolt: fading trail + an elongated body + a hot core, oriented
	# along the flight direction — reads as a real energy bolt, not an "ugly ball".
	var back := -dir
	var pulse := 1.0 + 0.10 * sin(_life * 26.0)
	var r := radius * pulse
	for i in range(1, 6):
		var t := float(i)
		draw_circle(back * (t * r * 0.8), maxf(r * (1.0 - t * 0.14), 1.0),
			Color(color.r, color.g, color.b, 0.30 * (1.0 - t / 6.0)))
	draw_circle(Vector2.ZERO, r + 1.5, Color(0, 0, 0, 0.45))  # dark rim for contrast
	var perp := dir.orthogonal()
	draw_colored_polygon(PackedVector2Array([
		dir * (r * 2.3), perp * r * 0.95, back * r * 0.8, -perp * r * 0.95,
	]), color)
	draw_circle(Vector2.ZERO, r * 0.6, Color(1, 1, 1, 0.95))
	draw_circle(dir * r * 0.5, r * 0.34, Color(1, 1, 1, 1.0))

func _activate() -> void:
	active = true
	visible = true
	# Toggling Area2D monitoring must be deferred — these run inside physics /
	# collision callbacks, where direct changes are blocked by the engine.
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)
	set_physics_process(true)
	queue_redraw()

func _deactivate() -> void:
	active = false
	visible = false
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	set_physics_process(false)
	global_position = Vector2(-100000, -100000)
