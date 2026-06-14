class_name Player
extends CharacterBody2D
## Greybox player: twin-stick movement + shooting, built entirely in code with a
## code-drawn circle. Reads intent from GameInput (touch OR keyboard/mouse).
## Components do the heavy lifting (composition over inheritance).

const RADIUS := 14.0

# Base stats before items/blessings/synergies. Everything stacks on top via
# StatBlock (see _recompute_stats).
const BASE_STATS := {
	"max_health": 6.0,
	"move_speed": 200.0,
	"damage": 2.0,
	"fire_rate": 4.0,
	"projectile_speed": 420.0,
	"crit_chance": 0.0,
	"crit_mult": 2.0,
}

var health: HealthComponent
var movement: MovementComponent
var weapon: WeaponComponent
var hurtbox: HurtboxComponent

var _last_aim: Vector2 = Vector2.RIGHT
var _deflect_chance: float = 0.0
var _flash: float = 0.0
var _body_color: Color = Color(0.4, 0.85, 1.0)

func _ready() -> void:
	add_to_group("player")
	var ch = GameData.characters.get(RunManager.character_id, null)
	if ch != null:
		_body_color = ch.color
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
	health.damage_filter = _filter_damage
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

	# Recompute stats whenever the build changes during the run.
	Events.item_picked_up.connect(func(_id): _recompute_stats())
	Events.blessing_chosen.connect(func(_id): _recompute_stats())
	_recompute_stats()
	_emit_health()

## Rebuilds final stats from base + items + blessings + active synergies and
## applies them to the components. Called on ready and whenever the build changes.
func _recompute_stats() -> void:
	var sb := StatBlock.new(BASE_STATS)
	for m in RunManager.collect_modifiers():
		sb.add_modifiers(m)

	movement.max_speed = sb.value("move_speed")
	weapon.base_damage = sb.value("damage")
	weapon.fire_rate = sb.value("fire_rate")
	weapon.projectile_speed = sb.value("projectile_speed")
	weapon.crit_chance = sb.value("crit_chance")
	weapon.crit_mult = sb.value("crit_mult")

	# Max health: grow current health by any increase so +HP items feel good.
	var new_max := sb.value("max_health")
	var delta := new_max - health.max_health
	health.max_health = new_max
	if delta > 0.0:
		health.heal(delta)
	health.health = minf(health.health, new_max)
	RunManager.player_max_health = new_max
	RunManager.player_health = health.health

	# Special effects.
	weapon.on_hit_effects = []
	_deflect_chance = 0.0
	for fx in RunManager.collect_effects():
		match fx.get("effect", ""):
			"chain_lightning":
				weapon.on_hit_effects.append(fx)
			"deflect_chance":
				_deflect_chance = maxf(_deflect_chance, float(fx.get("value", 0.0)))
	_emit_health()

## Pay health as a deliberate cost (altars of sacrifice). Guaranteed, unfiltered.
func pay_health(amount: float) -> void:
	health.spend(amount)

## Damage filter hook for HealthComponent: chance to fully deflect a hit.
func _filter_damage(amount: float) -> float:
	if _deflect_chance > 0.0 and RNG.stream("combat").randf() < _deflect_chance:
		return 0.0
	return amount

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
	_flash = 0.08
	_emit_health()

func _on_healed(_amount: float, current: float, _max: float) -> void:
	RunManager.player_health = current
	_emit_health()

func _on_died() -> void:
	Events.emit_signal("entity_died", self)

func _emit_health() -> void:
	Events.emit_signal("player_health_changed", health.health, health.max_health)

func _draw() -> void:
	var body_color := _body_color
	if _flash > 0.0:
		body_color = Color(1, 1, 1)
	draw_circle(Vector2.ZERO, RADIUS, body_color)
	# Aim indicator.
	draw_line(Vector2.ZERO, _last_aim * (RADIUS + 10.0), Color(1, 1, 1, 0.8), 3.0)

func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash -= delta
	queue_redraw()
