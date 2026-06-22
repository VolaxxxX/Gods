class_name Player
extends CharacterBody2D
## Greybox player: twin-stick movement + shooting, built entirely in code with a
## code-drawn circle. Reads intent from GameInput (touch OR keyboard/mouse).
## Components do the heavy lifting (composition over inheritance).

const RADIUS := 14.0
const MELEE_RANGE := 42.0    # radius of the melee swing hitbox
const MELEE_OFFSET := 30.0   # how far in front of the player it lands
# Dash (dodge): a short burst in the move/aim direction with brief i-frames.
# Lives on the shared Player, so EVERY class gets it regardless of weapon kind.
const DASH_SPEED := 640.0
const DASH_TIME := 0.16     # seconds of dash motion
const DASH_COOLDOWN := 0.85 # seconds before you can dash again

# Base stats before items/blessings/synergies. Everything stacks on top via
# StatBlock (see _recompute_stats).
const BASE_STATS := {
	"max_health": 8.0,
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

# Melee class support.
var _weapon_kind: String = "ranged"
var _melee: DamageArea
var _melee_cd: float = 0.0
var _melee_active_t: float = 0.0
var _melee_damage: float = 4.0
var _melee_rate: float = 2.5
var _swing_t: float = 0.0
var _sprite: Sprite2D
var _anim: AnimatedSprite2D
var _attack_t: float = 0.0
var _dash_t: float = 0.0      # remaining dash time (>0 means dashing)
var _dash_cd: float = 0.0     # remaining cooldown
var _dash_dir: Vector2 = Vector2.RIGHT
var _invuln_t: float = 0.0    # i-frames (set during a dash)

func _ready() -> void:
	add_to_group("player")
	var ch = GameData.characters.get(RunManager.character_id, null)
	if ch != null:
		_body_color = ch.color
	# Visuals: animated sheets > static sprite > greybox. Per-class override first.
	var anim_id := ""
	if Sprites.has_anim("player_" + RunManager.character_id):
		anim_id = "player_" + RunManager.character_id
	elif Sprites.has_anim("player"):
		anim_id = "player"
	if anim_id != "":
		_anim = AnimatedSprite2D.new()
		_anim.sprite_frames = Sprites.build_sprite_frames(anim_id, ["dash"])
		var cs := Sprites.anim_content_size(anim_id)
		if cs > 0.0:
			var sc := 3.4 * RADIUS / cs
			_anim.scale = Vector2.ONE * sc
			# Anchor the opaque feet to the shadow line (no more floating).
			_anim.position.y = RADIUS - Sprites.anim_content_bottom(anim_id) * sc
		add_child(_anim)
		if _anim.sprite_frames.has_animation("idle"):
			_anim.play("idle")
		elif _anim.sprite_frames.has_animation("walk"):
			_anim.play("walk")
	else:
		var tex := Sprites.player(RunManager.character_id)
		if tex != null:
			_sprite = Sprite2D.new()
			_sprite.texture = tex
			var cs := Sprites.content_size(tex)
			if cs > 0.0:
				var sc := 3.2 * RADIUS / cs
				_sprite.scale = Vector2.ONE * sc
				_sprite.position.y = RADIUS - Sprites.content_bottom(tex) * sc
			add_child(_sprite)
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

	# Apply the class's combat style.
	if ch != null:
		_weapon_kind = ch.weapon_kind
		weapon.projectile_count = ch.projectile_count
		weapon.spread_deg = ch.spread_deg
		weapon.pierce = ch.pierce
	if _weapon_kind == "melee":
		_melee = DamageArea.new()
		_melee.collision_layer = Collision.PLAYER_DMG
		_melee.collision_mask = 0
		var msh := CollisionShape2D.new()
		var mc := CircleShape2D.new()
		mc.radius = MELEE_RANGE
		msh.shape = mc
		_melee.add_child(msh)
		add_child(_melee)
		_melee.monitorable = false  # gated to the swing window

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
	# Melee hits harder but swings slower than shots (close-range risk).
	_melee_damage = sb.value("damage") * 2.4
	_melee_rate = sb.value("fire_rate") * 0.7

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
	if _invuln_t > 0.0:  # dash i-frames
		return 0.0
	if _deflect_chance > 0.0 and RNG.stream("combat").randf() < _deflect_chance:
		return 0.0
	return amount

## Called by the run scene to hand the shared projectile pool to the weapon.
func set_pool(pool: ProjectilePool) -> void:
	weapon.pool = pool

func _physics_process(delta: float) -> void:
	_dash_cd = maxf(0.0, _dash_cd - delta)
	if _invuln_t > 0.0:
		_invuln_t -= delta
	# Start a dash on a fresh tap, if off cooldown and not already dashing.
	if _dash_t <= 0.0 and _dash_cd <= 0.0 and GameInput.consume_dash():
		var ddir := GameInput.move_vector
		if ddir.length() < 0.1:
			ddir = _last_aim
		if ddir.length() > 0.01:
			_dash_dir = ddir.normalized()
			_dash_t = DASH_TIME
			_dash_cd = DASH_COOLDOWN
			_invuln_t = DASH_TIME + 0.05
			Fx.play("muzzle", global_position, 22.0)
	if _dash_t > 0.0:
		_dash_t -= delta
		velocity = _dash_dir * DASH_SPEED
	else:
		velocity = movement.compute(velocity, GameInput.move_vector, delta)
	move_and_slide()

	var aim := _resolve_aim()
	if aim.length() > 0.01:
		_last_aim = aim.normalized()
	if _weapon_kind == "melee":
		_update_melee(delta)
	elif _wants_fire():
		if weapon.attempt(global_position + _last_aim * RADIUS, _last_aim):
			_attack_t = 0.22
			Fx.play("muzzle", global_position + _last_aim * (RADIUS + 6.0), 30.0)

## Close-range swing: a brief damage area in front of the player.
func _update_melee(delta: float) -> void:
	_melee_cd -= delta
	if _melee_active_t > 0.0:
		_melee_active_t -= delta
		_melee.position = _last_aim * MELEE_OFFSET
		if _melee_active_t <= 0.0:
			_melee.set_deferred("monitorable", false)
	if _wants_fire() and _melee_cd <= 0.0:
		_melee_cd = 1.0 / maxf(0.01, _melee_rate)
		_melee_active_t = 0.16
		_swing_t = 0.16
		_attack_t = 0.22
		Fx.play("slash", global_position + _last_aim * MELEE_OFFSET, 60.0)
		_melee.position = _last_aim * MELEE_OFFSET
		var rng := RNG.stream("combat")
		var rolled := Damage.compute(_melee_damage, {
			"crit_chance": weapon.crit_chance, "crit_mult": weapon.crit_mult,
		}, rng)
		var d := Damage.new(rolled["amount"], ["melee"], self)
		d.is_crit = rolled["is_crit"]
		_melee.setup(d, false, 0.4)  # each enemy hit at most ~once per swing
		_melee.set_deferred("monitorable", true)

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
	# Soft contact shadow under the feet so the player stays readable on any floor.
	draw_set_transform(Vector2(0, RADIUS * 1.2), 0.0, Vector2(1.0, 0.42))
	draw_circle(Vector2.ZERO, RADIUS * 1.15, Color(0, 0, 0, 0.34))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _sprite == null and _anim == null:  # greybox body only when no sprite/anim
		var body_color := _body_color
		if _flash > 0.0:
			body_color = Color(1, 1, 1)
		draw_circle(Vector2.ZERO, RADIUS, body_color)
	# Aim indicator.
	draw_line(Vector2.ZERO, _last_aim * (RADIUS + 10.0), Color(1, 1, 1, 0.8), 3.0)
	# Melee swing arc feedback.
	if _swing_t > 0.0:
		var a := _last_aim.angle()
		draw_arc(_last_aim * MELEE_OFFSET, MELEE_RANGE, a - 1.0, a + 1.0, 16,
			Color(1, 1, 1, 0.7), 4.0)

func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash -= delta
	if _swing_t > 0.0:
		_swing_t -= delta
	if _attack_t > 0.0:
		_attack_t -= delta
	if _sprite != null:
		_sprite.modulate = Color(1.8, 1.8, 1.8) if _flash > 0.0 else Color.WHITE
	if _anim != null:
		_anim.modulate = Color(1.8, 1.8, 1.8) if _flash > 0.0 else Color.WHITE
		_update_anim()
	queue_redraw()

## Pick walk/attack/idle and face the aim/movement direction.
func _update_anim() -> void:
	var sf := _anim.sprite_frames
	var st := "idle"
	if _dash_t > 0.0 and sf.has_animation("dash"):
		st = "dash"
	elif _attack_t > 0.0 and sf.has_animation("attack"):
		st = "attack"
	elif velocity.length() > 12.0 and sf.has_animation("walk"):
		st = "walk"
	if not sf.has_animation(st):
		st = "idle"
	if sf.has_animation(st) and _anim.animation != st:
		_anim.play(st)
	if absf(_last_aim.x) > 0.1:
		_anim.flip_h = _last_aim.x < 0.0
