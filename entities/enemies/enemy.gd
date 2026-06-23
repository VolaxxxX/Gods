class_name Enemy
extends CharacterBody2D
## Greybox enemy built from EntityData. Chases the player and deals contact
## damage. Everything (health, speed, color, size, behavior) comes from data, so
## new enemies are added as JSON, not code (data-driven §3.1).

const CONTACT_INTERVAL := 0.6  # seconds between contact damage ticks

var data: EntityData
var health: HealthComponent
var movement: MovementComponent
var ai: AIComponent
var hurtbox: HurtboxComponent
var contact: DamageArea
var weapon: WeaponComponent  # only for ranged entities (bosses, casters)
var _target: Node2D
var _pool: ProjectilePool
var _abilities: Array = []
var _ability_cd: Array = []  # parallel to _abilities: seconds until next use
var _phase2_done: bool = false

var _radius: float = 12.0
var _color: Color = Color(0.85, 0.3, 0.3)
var _flash: float = 0.0
var _sprite: Sprite2D  # set if a static texture exists for this entity id
var _sprite_tinted: bool = false  # generic sprite tinted by the enemy colour
var _anim: AnimatedSprite2D  # set if animation sheets exist (takes priority)
var _attack_t: float = 0.0   # time left showing the attack animation
var _attack_anim: String = "attack"  # which animation the active ability requests
var _charge_t: float = 0.0   # time left dashing (charge ability)
var _charge_dir: Vector2 = Vector2.ZERO
var _charge_speed: float = 420.0
var _charge_vanish: bool = false  # fade out while dashing (Sand Veil Dash)
var _melee_swing_cd: float = 0.0  # melee mobs: throttle the attack animation

func setup(p_data: EntityData, target: Node2D, pool: ProjectilePool = null) -> void:
	data = p_data
	_target = target
	_pool = pool
	_radius = data.radius
	_color = data.color

	# Visuals, in priority order: animated sheets > bespoke static sprite >
	# generic monster tinted by colour > greybox circle. Bosses also load a sheet
	# per bespoke attack (the `anim` named on each ability).
	var attack_anims := _ability_anim_names()
	if Sprites.has_anim(data.id, attack_anims):
		_anim = AnimatedSprite2D.new()
		_anim.sprite_frames = Sprites.build_sprite_frames(data.id, attack_anims)
		var cs := Sprites.anim_content_size(data.id)
		if cs > 0.0:
			var sc := 3.0 * _radius / cs
			_anim.scale = Vector2.ONE * sc
			_anim.position.y = _radius - Sprites.anim_content_bottom(data.id) * sc
		add_child(_anim)
		if _anim.sprite_frames.has_animation("idle"):
			_anim.play("idle")
		elif _anim.sprite_frames.has_animation("walk"):
			_anim.play("walk")
	else:
		var tex := Sprites.entity(data.id)
		var tinted := false
		if tex == null:
			tex = Sprites.entity_generic()
			tinted = true
		if tex != null:
			_sprite = Sprite2D.new()
			_sprite.texture = tex
			if tinted:
				_sprite.modulate = _color
				_sprite_tinted = true
			var cs := Sprites.content_size(tex)
			if cs > 0.0:
				var sc := 2.8 * _radius / cs
				_sprite.scale = Vector2.ONE * sc
				_sprite.position.y = _radius - Sprites.content_bottom(tex) * sc
			add_child(_sprite)

	collision_layer = Collision.ENEMY_BODY
	collision_mask = Collision.WORLD

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = _radius
	shape.shape = circle
	add_child(shape)

	health = HealthComponent.new()
	add_child(health)
	health.setup(data.max_health)
	health.died.connect(_on_died)
	health.damaged.connect(func(_a, _c, _m): _flash = 0.07)
	# Floating damage number (juice). Spawned into the room (world space).
	health.damaged.connect(func(a, _c, _m): FloatingText.spawn(
		get_parent(), global_position + Vector2(randf_range(-6, 6), -_radius - 8),
		str(int(round(a))), Color(1.0, 0.93, 0.65)))

	hurtbox = HurtboxComponent.new()
	hurtbox.health = health
	hurtbox.collision_layer = Collision.ENEMY_HURT
	hurtbox.collision_mask = Collision.PLAYER_DMG
	var hshape := CollisionShape2D.new()
	var hcircle := CircleShape2D.new()
	hcircle.radius = _radius
	hshape.shape = hcircle
	hurtbox.add_child(hshape)
	add_child(hurtbox)

	movement = MovementComponent.new()
	movement.max_speed = data.move_speed
	movement.acceleration = 900.0
	add_child(movement)

	ai = AIComponent.new()
	ai.behavior = data.ai
	ai.target = target
	add_child(ai)

	# Contact damage area.
	contact = DamageArea.new()
	contact.collision_layer = Collision.ENEMY_DMG
	contact.collision_mask = Collision.PLAYER_HURT
	contact.setup(Damage.new(data.contact_damage, ["contact"], self), false, CONTACT_INTERVAL)
	var cshape := CollisionShape2D.new()
	var ccircle := CircleShape2D.new()
	ccircle.radius = _radius
	cshape.shape = ccircle
	contact.add_child(cshape)
	add_child(contact)

	# Optional ranged attack (bosses/casters fire at the player).
	if data.ranged and pool != null:
		weapon = WeaponComponent.new()
		weapon.faction_player = false
		weapon.pool = pool
		weapon.base_damage = data.range_damage
		weapon.fire_rate = data.range_rate
		weapon.projectile_speed = data.range_speed
		weapon.projectile_color = Color(1.0, 0.45, 0.4)
		weapon.projectile_sprite = "projectile_" + data.id
		weapon.projectile_radius = 8.0
		weapon.projectile_life = 2.5
		add_child(weapon)

	# Bespoke patterns (bosses/minibosses). Stagger initial cooldowns so the
	# abilities don't all fire on the same frame.
	_abilities = data.abilities
	for i in _abilities.size():
		var cd: float = float(_abilities[i].get("cooldown", 4.0))
		_ability_cd.append(cd * (0.5 + 0.35 * i))

func _ready() -> void:
	add_to_group("enemies")

func _physics_process(delta: float) -> void:
	if _charge_t > 0.0:
		# Dashing toward the player (charge ability) — overrides normal movement.
		_charge_t -= delta
		velocity = _charge_dir * _charge_speed
		move_and_slide()
	elif ai != null:
		var dir := ai.desired_direction(global_position)
		velocity = movement.compute(velocity, dir, delta)
		move_and_slide()
	# Ranged entities fire at the player (the weapon throttles via fire_rate).
	if weapon != null and is_instance_valid(_target):
		var aim := _target.global_position - global_position
		if weapon.attempt(global_position + aim.normalized() * (_radius + 8.0), aim):
			_attack_t = 0.35
	# Melee mobs (no weapon/abilities) play their attack anim when adjacent.
	if weapon == null and _abilities.is_empty() and is_instance_valid(_target):
		_melee_swing_cd -= delta
		if _melee_swing_cd <= 0.0 \
				and global_position.distance_to(_target.global_position) < _radius + 28.0:
			_melee_swing_cd = CONTACT_INTERVAL
			_attack_t = 0.3
			if _anim != null and _anim.sprite_frames != null \
					and _anim.sprite_frames.has_animation("attack"):
				_anim.play("attack")
	# Final-boss second phase: unlock new attacks + a burst at the threshold.
	if not _phase2_done and not data.phase2_abilities.is_empty() \
			and health.fraction() <= data.phase2_at:
		_enter_phase2()
	# Bespoke ability patterns; fire faster when enraged (below 40% HP).
	if not _abilities.is_empty() and is_instance_valid(_target):
		var enrage := 1.6 if health.fraction() < 0.4 else 1.0
		for i in _abilities.size():
			_ability_cd[i] -= delta * enrage
			if _ability_cd[i] <= 0.0:
				_execute_ability(_abilities[i])
				_ability_cd[i] = float(_abilities[i].get("cooldown", 4.0))
	# Contact damage now ticks via the hurtbox cooldown (retrigger_interval).
	if _flash > 0.0:
		_flash -= delta
	if _attack_t > 0.0:
		_attack_t -= delta
	var fade := 0.3 if (_charge_t > 0.0 and _charge_vanish) else 1.0  # Sand Veil Dash
	if _sprite != null:
		var m := Color(1.8, 1.8, 1.8) if _flash > 0.0 else (_color if _sprite_tinted else Color.WHITE)
		m.a = fade
		_sprite.modulate = m
	if _anim != null:
		var m2 := Color(1.8, 1.8, 1.8) if _flash > 0.0 else Color.WHITE
		m2.a = fade
		_anim.modulate = m2
		_update_anim()
	queue_redraw()

## Pick walk/attack/idle and face the movement direction.
func _update_anim() -> void:
	var sf := _anim.sprite_frames
	var st := "idle"
	if _attack_t > 0.0 and sf.has_animation(_attack_anim):
		st = _attack_anim  # bespoke per-attack animation
	elif _attack_t > 0.0 and sf.has_animation("attack"):
		st = "attack"
	elif velocity.length() > 8.0 and sf.has_animation("walk"):
		st = "walk"
	if not sf.has_animation(st):
		st = "idle"
	if sf.has_animation(st) and _anim.animation != st:
		_anim.play(st)
	if absf(velocity.x) > 1.0:
		_anim.flip_h = velocity.x < 0.0

func _enter_phase2() -> void:
	_phase2_done = true
	for ab in data.phase2_abilities:
		_abilities.append(ab)
		_ability_cd.append(0.6)  # the new attacks come online almost at once
	_flash = 0.25
	_fire_pattern(16, TAU, 0.0, 200.0, 1.0)  # dramatic phase-change burst
	Juice.add_trauma(0.6)

func _execute_ability(ab: Dictionary) -> void:
	_attack_t = 0.4  # show the attack animation when an ability fires
	_attack_anim = String(ab.get("anim", "attack"))  # bespoke per-attack sheet
	match ab.get("kind", ""):
		"nova":
			_fire_pattern(int(ab.get("count", 8)), TAU, 0.0,
				float(ab.get("speed", 200.0)), float(ab.get("damage", 1.0)))
			Fx.play(_burst_fx(), global_position, _radius * 4.0)
		"spread":
			if is_instance_valid(_target):
				var base := (_target.global_position - global_position).angle()
				_fire_pattern(int(ab.get("count", 5)), deg_to_rad(float(ab.get("spread", 40.0))),
					base, float(ab.get("speed", 240.0)), float(ab.get("damage", 1.0)))
		"summon":
			_summon(String(ab.get("entity", "")), int(ab.get("count", 2)), bool(ab.get("regen", false)))
		"charge":
			if is_instance_valid(_target):
				_charge_dir = (_target.global_position - global_position).normalized()
				_charge_speed = float(ab.get("speed", 420.0))
				_charge_t = float(ab.get("duration", 0.45))
				_charge_vanish = bool(ab.get("vanish", false))  # fade during the dash
				Fx.play(_burst_fx(), global_position, _radius * 3.0)
		"barrage":
			# A tight, fast volley aimed at the player.
			if is_instance_valid(_target):
				var base := (_target.global_position - global_position).angle()
				_fire_pattern(int(ab.get("count", 5)), deg_to_rad(float(ab.get("spread", 12.0))),
					base, float(ab.get("speed", 300.0)), float(ab.get("damage", 1.0)))

## Themed nova/charge burst for this enemy if its art exists, else the generic ring.
func _burst_fx() -> String:
	var n := "burst_" + data.id
	return n if Fx.has(n) else "shockwave"

## Fires `count` projectiles spanning `arc` radians centered on `center` (use a
## full TAU arc for an omni "nova").
func _fire_pattern(count: int, arc: float, center: float, speed: float, dmg: float) -> void:
	if _pool == null or count <= 0:
		return
	for k in count:
		var t := 0.0 if count == 1 else (float(k) / (count - 1) - 0.5)
		var angle := center + t * arc if arc < TAU else center + TAU * k / count
		var dir := Vector2.from_angle(angle)
		var d := Damage.new(dmg, ["enemy"], self)
		_pool.spawn(global_position + dir * (_radius + 8.0), dir * speed, d, false,
			8.0, Color(1, 0.5, 0.4), 3.0, false, "projectile_" + data.id)

func _summon(entity_id: String, count: int, regen: bool = false) -> void:
	if entity_id == "" or count <= 0:
		return
	var ed := GameData.get_entity(entity_id)
	var parent := get_parent()
	if ed == null or parent == null:
		return
	for k in count:
		var add := Enemy.new()
		add.setup(ed, _target, _pool)
		add.position = global_position + Vector2.from_angle(TAU * k / count) * (_radius + 28.0)
		parent.add_child(add)
		# Hydra "heads grow back": a slain add is replaced 1:1 while the boss lives.
		if regen and add.health != null:
			add.health.died.connect(_on_regen_add.bind(entity_id))

## Replace a killed regenerating add, deferred so it doesn't spawn mid-death.
func _on_regen_add(entity_id: String) -> void:
	if health == null or health.fraction() <= 0.0:
		return  # boss is dead — stop regenerating
	call_deferred("_summon", entity_id, 1, true)

## The bespoke attack-animation names declared on this entity's abilities, so the
## sprite pipeline can load a sheet per attack (<id>_<anim>.png).
func _ability_anim_names() -> Array:
	var names: Array = []
	for src in [data.abilities, data.phase2_abilities]:
		if src is Array:
			for ab in src:
				var n := String(ab.get("anim", ""))
				if n != "" and not names.has(n):
					names.append(n)
	return names

func _on_died() -> void:
	RunManager.on_enemy_killed(data.gold)
	Events.emit_signal("entity_died", self)
	# Play the death animation before despawning, if there is one.
	if _anim != null and _anim.sprite_frames != null and _anim.sprite_frames.has_animation("death"):
		set_physics_process(false)
		if contact != null:
			contact.set_deferred("monitorable", false)
		_anim.play("death")
		await _anim.animation_finished
	queue_free()

func _draw() -> void:
	# Contact shadow so enemies read against any floor.
	draw_set_transform(Vector2(0, _radius * 1.1), 0.0, Vector2(1.0, 0.42))
	draw_circle(Vector2.ZERO, _radius * 1.05, Color(0, 0, 0, 0.30))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Soft contact shadow under the feet so every mob reads as grounded (sprite or
	# greybox), and doesn't look like it floats over the floor.
	var sh := 0.30 if (_charge_t > 0.0 and _charge_vanish) else 1.0
	draw_set_transform(Vector2(0, _radius * 0.95), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, _radius * 1.05, Color(0, 0, 0, 0.28 * sh))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _sprite == null and _anim == null:  # greybox body only when no sprite/anim
		var c := Color(1, 1, 1) if _flash > 0.0 else _color
		if _charge_t > 0.0 and _charge_vanish:
			c.a = 0.3  # Sand Veil Dash fade
		draw_circle(Vector2.ZERO, _radius, c)
	# Health pip (thin bar) so damage is readable.
	if health != null and health.fraction() < 1.0:
		var w := _radius * 2.0 * health.fraction()
		draw_rect(Rect2(-_radius, -_radius - 8.0, w, 3.0), Color(0.2, 1.0, 0.3))
