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

## Optional on-hit hook (pos, hurtbox) for blessing/synergy effects.
var on_hit_extra: Callable = Callable()

var _shape: CollisionShape2D
var _spr: Sprite2D  # optional projectile texture; greybox disc when absent

func _ready() -> void:
	_shape = CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	_shape.shape = circle
	add_child(_shape)
	_spr = Sprite2D.new()
	_spr.visible = false
	add_child(_spr)
	hit.connect(_on_hit)
	# Walls are physics bodies, not areas, so despawn on body contact too.
	body_entered.connect(_on_body_entered)
	_deactivate()

func fire(p_pos: Vector2, p_velocity: Vector2, dmg: Damage, faction_player: bool,
		p_radius: float = 6.0, p_color: Color = Color(1, 1, 0.6), life: float = 2.0,
		pierce_through: bool = false, sprite_name: String = "") -> void:
	global_position = p_pos
	velocity = p_velocity
	radius = p_radius
	color = p_color
	_max_life = life
	_life = 0.0
	on_hit_extra = Callable()  # reset; weapon re-assigns per shot if needed
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
	_spr.texture = tex
	_spr.visible = tex != null
	if tex != null:
		_spr.modulate = Color.WHITE if has_specific else color
		var dim: float = maxf(tex.get_width(), tex.get_height())
		if dim > 0.0:
			_spr.scale = Vector2.ONE * (2.0 * radius / dim)
	_activate()

func _physics_process(delta: float) -> void:
	if not active:
		return
	global_position += velocity * delta
	_life += delta
	if _life >= _max_life:
		_deactivate()

func _on_hit(hurtbox: HurtboxComponent) -> void:
	if on_hit_extra.is_valid():
		on_hit_extra.call(global_position, hurtbox)
	Fx.play("impact", global_position, 36.0)
	if not pierce:
		_deactivate()

func _on_body_entered(_body: Node) -> void:
	# Any solid body (wall/obstacle) stops the projectile.
	_deactivate()

func _draw() -> void:
	# Only the greybox look (no bespoke sprite). A dark outline + bright core makes
	# shots read clearly on ANY floor, light marble included.
	if active and (_spr == null or not _spr.visible):
		draw_circle(Vector2.ZERO, radius + 2.5, Color(0, 0, 0, 0.55))
		draw_circle(Vector2.ZERO, radius, color)
		draw_circle(Vector2.ZERO, radius * 0.5, Color(1, 1, 1, 0.92))

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
