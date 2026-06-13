class_name Player
extends CharacterBody2D
## Greybox player: twin-stick movement + shooting, built entirely in code with a
## code-drawn circle. Reads intent from GameInput (touch OR keyboard/mouse).
## Components do the heavy lifting (composition over inheritance).

const RADIUS := 14.0

var health: HealthComponent
var movement: MovementComponent
var weapon: WeaponComponent
var hurtbox: HurtboxComponent

var _last_aim: Vector2 = Vector2.RIGHT

func _ready() -> void:
	add_to_group("player")
	collision_layer = Collision.PLAYER_BODY
	# Collide with walls only; pass through enemies (contact damage is handled by
	# areas), which avoids the player getting shoved/stuck by mobs.
	collision_mask = Collision.WORLD

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	add_child(shape)

	# Health (carries between rooms via RunManager).
	health = HealthComponent.new()
	add_child(health)
	health.setup(RunManager.player_max_health, RunManager.player_health)
	health.damaged.connect(_on_damaged)
	health.healed.connect(_on_healed)
	health.died.connect(_on_died)

	# Hurtbox.
	hurtbox = HurtboxComponent.new()
	hurtbox.health = health
	hurtbox.collision_layer = Collision.PLAYER_HURT
	hurtbox.collision_mask = Collision.ENEMY_DMG
	var hshape := CollisionShape2D.new()
	var hcircle := CircleShape2D.new()
	hcircle.radius = RADIUS
	hshape.shape = hcircle
	hurtbox.add_child(hshape)
	add_child(hurtbox)

	movement = MovementComponent.new()
	movement.max_speed = 200.0
	add_child(movement)

	weapon = WeaponComponent.new()
	weapon.faction_player = true
	weapon.projectile_color = Color(0.9, 0.95, 1.0)
	add_child(weapon)

	_emit_health()

## Called by the run scene to hand the shared projectile pool to the weapon.
func set_pool(pool: ProjectilePool) -> void:
	weapon.pool = pool

func _physics_process(delta: float) -> void:
	velocity = movement.compute(velocity, GameInput.move_vector, delta)
	move_and_slide()

	var aim := _resolve_aim()
	if aim.length() > 0.01:
		_last_aim = aim.normalized()
	if _wants_fire():
		weapon.attempt(global_position + _last_aim * RADIUS, _last_aim)

func _resolve_aim() -> Vector2:
	# 1) Touch right stick.
	if GameInput.aim_vector.length() > 0.1:
		return GameInput.aim_vector
	# 2) Desktop mouse (when held).
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return get_global_mouse_position() - global_position
	# 3) Auto-aim at nearest enemy.
	if GameInput.auto_aim:
		var target := _nearest_enemy()
		if target != null:
			return target.global_position - global_position
	return Vector2.ZERO

func _wants_fire() -> bool:
	return GameInput.fire_held \
		or GameInput.auto_fire \
		or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var d := global_position.distance_squared_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best

func _on_damaged(_amount: float, current: float, _max: float) -> void:
	RunManager.player_health = current
	_emit_health()

func _on_healed(_amount: float, current: float, _max: float) -> void:
	RunManager.player_health = current
	_emit_health()

func _on_died() -> void:
	Events.emit_signal("entity_died", self)

func _emit_health() -> void:
	Events.emit_signal("player_health_changed", health.health, health.max_health)

func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, Color(0.4, 0.85, 1.0))
	# Aim indicator.
	draw_line(Vector2.ZERO, _last_aim * (RADIUS + 10.0), Color(1, 1, 1, 0.8), 3.0)

func _process(_delta: float) -> void:
	queue_redraw()
