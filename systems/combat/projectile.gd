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

var _shape: CollisionShape2D

func _ready() -> void:
	_shape = CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	_shape.shape = circle
	add_child(_shape)
	hit.connect(_on_hit)
	# Walls are physics bodies, not areas, so despawn on body contact too.
	body_entered.connect(_on_body_entered)
	_deactivate()

func fire(p_pos: Vector2, p_velocity: Vector2, dmg: Damage, faction_player: bool,
		p_radius: float = 6.0, p_color: Color = Color(1, 1, 0.6), life: float = 2.0,
		pierce_through: bool = false) -> void:
	global_position = p_pos
	velocity = p_velocity
	radius = p_radius
	color = p_color
	_max_life = life
	_life = 0.0
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
	_activate()

func _physics_process(delta: float) -> void:
	if not active:
		return
	global_position += velocity * delta
	_life += delta
	if _life >= _max_life:
		_deactivate()

func _on_hit(_hurtbox: HurtboxComponent) -> void:
	if not pierce:
		_deactivate()

func _on_body_entered(_body: Node) -> void:
	# Any solid body (wall/obstacle) stops the projectile.
	_deactivate()

func _draw() -> void:
	if active:
		draw_circle(Vector2.ZERO, radius, color)

func _activate() -> void:
	active = true
	visible = true
	monitoring = true
	monitorable = true
	set_physics_process(true)
	queue_redraw()

func _deactivate() -> void:
	active = false
	visible = false
	monitoring = false
	monitorable = false
	set_physics_process(false)
	global_position = Vector2(-100000, -100000)
