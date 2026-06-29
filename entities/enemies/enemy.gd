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
var _feigned: bool = false   # final boss: has he already played his fake death?
var _feign_y0: float = 0.0

var _radius: float = 12.0
var _color: Color = Color(0.85, 0.3, 0.3)
var _difficulty: float = 1.0  # per-realm enemy-damage multiplier
var _flash: float = 0.0
var _sprite: Sprite2D  # set if a static texture exists for this entity id
var _sprite_tinted: bool = false  # generic sprite tinted by the enemy colour
var _anim: AnimatedSprite2D  # set if animation sheets exist (takes priority)
var _attack_t: float = 0.0   # time left showing the attack animation
var _attack_anim: String = "attack"  # which animation the active ability requests
var _idle_anims: Array = []   # background colossus: idle variants to cycle through
var _idle_cur: String = "idle"
var _idle_t: float = 0.0
var _tentacles: Array = []   # final boss: independently-swaying face tentacles
var intro_lock: bool = false  # boss-intro cinematic: freeze AI/abilities, run visuals only
var _eyeL: PointLight2D       # final boss: glowing red eyes that ignite on the roar
var _eyeR: PointLight2D
var _eye_base: float = 0.0    # current eye glow (lerps toward target)
var _eye_target: float = 0.0  # 0 dark; raised on the roar, brighter in phase 2
var _phase2_tint: Color = Color.WHITE  # blood-lit overlay once the Old God enrages
var _hz_cd: float = 4.0       # phase-2 arena hazard (void pool) spawn timer
var _knockback: Vector2 = Vector2.ZERO  # decaying shove (player melee)
var _statuses: Dictionary = {}  # kind -> {"t": seconds_left, "mag": per-tick}
var _dot_t: float = 0.0         # shared damage-over-time tick accumulator
var _charge_t: float = 0.0   # time left dashing (charge ability)
var _charge_dir: Vector2 = Vector2.ZERO
var _charge_speed: float = 420.0
var _charge_vanish: bool = false  # fade out while dashing (Sand Veil Dash)
var _melee_swing_cd: float = 0.0  # melee mobs: throttle the attack animation
var _melee_cd: float = 0.0  # bosses/minibosses: cooldown for the close-range melee strike

func setup(p_data: EntityData, target: Node2D, pool: ProjectilePool = null,
		difficulty: float = 1.0) -> void:
	data = p_data
	_target = target
	_pool = pool
	_radius = data.radius
	_color = data.color
	# Per-realm difficulty: regular enemies get more HP; bosses/minibosses are
	# already hand-tuned so their HP is left alone. ALL enemy damage scales, so a
	# harder realm hits harder without fights dragging.
	var hp_mult: float = 1.0 if data.role in ["boss", "miniboss"] else difficulty
	_difficulty = difficulty

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
			if data.background_boss:
				sc *= 1.5  # colossus: looms larger than its hurtbox
				if data.id == "hell_cthulhu":
					sc *= 1.5  # Typhon-style: a towering god that overhangs the arena
			_anim.scale = Vector2.ONE * sc
			_anim.position.y = _radius - Sprites.anim_content_bottom(data.id) * sc
		add_child(_anim)
		if _anim.sprite_frames.has_animation("idle"):
			_anim.play("idle")
		elif _anim.sprite_frames.has_animation("walk"):
			_anim.play("walk")
		if data.background_boss:
			for n in ["idle", "idle2", "idle3"]:
				if _anim.sprite_frames.has_animation(n):
					_idle_anims.append(n)
			_idle_cur = "idle"
			_idle_t = randf_range(3.0, 5.5)
			if data.id == "hell_cthulhu":
				_setup_tentacles()
		if data.id == "hell_cthulhu":
			_setup_eyes()
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
	health.setup(data.max_health * hp_mult)
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
	contact.setup(Damage.new(data.contact_damage * _difficulty, ["contact"], self), false, CONTACT_INTERVAL)
	var cshape := CollisionShape2D.new()
	var ccircle := CircleShape2D.new()
	ccircle.radius = _radius
	cshape.shape = ccircle
	contact.add_child(cshape)
	add_child(contact)
	if data.background_boss:
		contact.monitoring = false   # the colossus never deals CONTACT damage
		contact.monitorable = false
		z_index = 2                  # sits behind the player/projectiles (background)

	# Optional ranged attack (bosses/casters fire at the player).
	if data.ranged and pool != null:
		weapon = WeaponComponent.new()
		weapon.faction_player = false
		weapon.pool = pool
		weapon.base_damage = data.range_damage * _difficulty
		weapon.fire_rate = data.range_rate
		weapon.projectile_speed = data.range_speed
		weapon.projectile_color = Color(1.0, 0.45, 0.4)
		weapon.projectile_sprite = "projectile_" + data.id
		weapon.projectile_radius = 8.0
		weapon.projectile_life = 2.5
		# Per-type shot pitch so each ranged mob sounds like its own creature.
		weapon.pitch_bias = (float(absi(hash(data.id)) % 100) / 100.0 - 0.5) * 0.4
		add_child(weapon)

	# Bespoke patterns (bosses/minibosses). Stagger initial cooldowns so the
	# abilities don't all fire on the same frame.
	_abilities = data.abilities
	for i in _abilities.size():
		var cd: float = float(_abilities[i].get("cooldown", 4.0))
		_ability_cd.append(cd * (0.15 + 0.3 * i))  # first signature attack fires fast

func _ready() -> void:
	add_to_group("enemies")

## A decaying shove (player melee knockback) so close combat can create space.
func apply_knockback(v: Vector2) -> void:
	_knockback = v

## Apply an elemental status: burn/poison deal per-tick damage; chill slows. The
## stronger magnitude and longer duration win when refreshed.
func apply_status(kind: String, duration: float, magnitude: float) -> void:
	var cur = _statuses.get(kind, {})
	_statuses[kind] = {
		"t": maxf(float(cur.get("t", 0.0)), duration),
		"mag": maxf(float(cur.get("mag", 0.0)), magnitude),
	}

func _tick_statuses(delta: float) -> void:
	_dot_t += delta
	var do_tick := _dot_t >= 0.5
	if do_tick:
		_dot_t = 0.0
	for kind in _statuses.keys():
		_statuses[kind]["t"] -= delta
		if _statuses[kind]["t"] <= 0.0:
			_statuses.erase(kind)
			continue
		if do_tick and health != null and (kind == "burn" or kind == "poison"):
			health.take(float(_statuses[kind]["mag"]))

## A tint blended onto the sprite to show the active status at a glance.
func _status_tint() -> Color:
	if _statuses.has("burn"):
		return Color(1.6, 0.7, 0.4)
	if _statuses.has("poison"):
		return Color(0.7, 1.5, 0.6)
	if _statuses.has("chill"):
		return Color(0.6, 0.9, 1.6)
	return Color.WHITE

func _physics_process(delta: float) -> void:
	if intro_lock:
		# Boss-intro cinematic: no AI — the emerge sheet (if any) plays itself while
		# run_scene tweens the rise from under the rain; eyes ignite on the roar.
		if _attack_t > 0.0:
			_attack_t -= delta
		_update_eyes(delta)
		queue_redraw()
		return
	if not _statuses.is_empty():
		_tick_statuses(delta)
	if data.background_boss:
		velocity = Vector2.ZERO  # pinned colossus — looms, never walks the arena
	elif _knockback.length() > 12.0:
		# Being shoved — overrides AI/charge briefly so melee actually pushes foes.
		velocity = _knockback
		move_and_slide()
		_knockback = _knockback.lerp(Vector2.ZERO, clampf(delta * 9.0, 0.0, 1.0))
	elif _charge_t > 0.0:
		# Dashing toward the player (charge ability) — overrides normal movement.
		_charge_t -= delta
		velocity = _charge_dir * _charge_speed
		move_and_slide()
	elif ai != null:
		var dir := ai.desired_direction(global_position)
		velocity = movement.compute(velocity, dir, delta)
		if _statuses.has("chill"):
			velocity *= 0.5  # frozen/chilled enemies move at half speed
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
	# Bosses & minibosses: a REAL close-range melee strike (burst hit + swing),
	# distinct from passive contact damage. Only when the player is right next to
	# them and not mid-dash, so they never swing at empty air.
	if not _abilities.is_empty() and is_instance_valid(_target) and _charge_t <= 0.0 \
			and not data.background_boss:
		_melee_cd -= delta
		if _melee_cd <= 0.0 \
				and global_position.distance_to(_target.global_position) <= _radius + 30.0:
			_melee_cd = 2.2
			_melee_strike()
	# Final-boss second phase: unlock new attacks + a burst at the threshold.
	if not _phase2_done and not data.phase2_abilities.is_empty() \
			and health.fraction() <= data.phase2_at:
		_enter_phase2()
	# Phase-2 arena hazard: void pools erupt under the player (telegraphed).
	if _phase2_done and data.id == "hell_cthulhu" and is_instance_valid(_target):
		_hz_cd -= delta
		if _hz_cd <= 0.0:
			_hz_cd = 3.6
			_spawn_void_pool(_target.global_position)
	# Bespoke ability patterns; fire faster when enraged (below 45% HP).
	if not _abilities.is_empty() and is_instance_valid(_target):
		var enrage := 1.9 if health.fraction() < 0.45 else 1.0
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
	var tint := _status_tint() if (_flash <= 0.0 and not _statuses.is_empty()) else Color.WHITE
	if _sprite != null:
		var m := Color(1.8, 1.8, 1.8) if _flash > 0.0 else (_color if _sprite_tinted else Color.WHITE)
		m = Color(m.r * tint.r, m.g * tint.g, m.b * tint.b)
		m.a = fade
		_sprite.modulate = m
	if _anim != null:
		var m2 := Color(1.8, 1.8, 1.8) if _flash > 0.0 else Color.WHITE
		m2 = Color(m2.r * tint.r, m2.g * tint.g, m2.b * tint.b)
		if _phase2_done:
			m2 = Color(m2.r * _phase2_tint.r, m2.g * _phase2_tint.g, m2.b * _phase2_tint.b)
		m2.a = fade
		_anim.modulate = m2
		if _idle_anims.size() > 1 and _attack_t <= 0.0 and velocity.length() <= 8.0:
			_idle_t -= delta
			if _idle_t <= 0.0:
				_idle_cur = _idle_anims[randi() % _idle_anims.size()]
				_idle_t = randf_range(3.0, 5.5)
		_update_anim()
	_update_eyes(delta)
	_update_tentacles(delta)
	queue_redraw()

## Pick walk/attack/idle and face the movement direction.
func _update_anim() -> void:
	var sf := _anim.sprite_frames
	var st := _idle_cur if not _idle_anims.is_empty() else "idle"
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
	if data.phase2_replace:
		_abilities.clear()  # phase 2 is a wholly new moveset, not additive
		_ability_cd.clear()
	for ab in data.phase2_abilities:
		_abilities.append(ab)
		_ability_cd.append(0.6)  # the new attacks come online almost at once
	_flash = 0.25
	_fire_pattern(16, TAU, 0.0, 200.0, 1.0)  # dramatic phase-change burst
	Juice.add_trauma(0.6)
	if data.id == "hell_cthulhu":
		_phase2_tint = Color(1.35, 0.62, 0.62)  # blood-lit, enraged
		_eye_target = 2.8                        # the eyes blaze brighter
		Events.emit_signal("boss_phase2", self)

## Length (s) of the named attack sheet for THIS boss, so the swing plays in
## full and never cuts mid-frame or freezes on the last frame. Falls back to a
## sane default when the entity has no animation.
func _attack_anim_duration() -> float:
	if _anim != null and _anim.sprite_frames != null and _anim.sprite_frames.has_animation(_attack_anim):
		var fc := _anim.sprite_frames.get_frame_count(_attack_anim)
		var fps := _anim.sprite_frames.get_animation_speed(_attack_anim)
		if fps > 0.0:
			return clampf(float(fc) / fps, 0.3, 0.85)
	return 0.4

## A real close-range melee STRIKE for bosses/minibosses: a short-lived melee
## hitbox toward the player (one burst hit), the attack swing animation, and a
## slash FX. Separate from the always-on contact damage.
func _melee_strike() -> void:
	if not is_instance_valid(_target):
		return
	var dir := (_target.global_position - _shoot_origin()).normalized()
	_attack_anim = "attack"
	_attack_t = _attack_anim_duration()  # play the full swing for THIS boss (no cut/freeze)
	var dmg := (data.contact_damage + 1.0) * _difficulty
	var hitarea := DamageArea.new()
	hitarea.collision_layer = Collision.ENEMY_DMG
	hitarea.collision_mask = Collision.PLAYER_HURT
	hitarea.setup(Damage.new(dmg, ["enemy", "melee"], self), false, 0.0)
	var cs := CollisionShape2D.new()
	var cc := CircleShape2D.new()
	cc.radius = _radius * 0.85
	cs.shape = cc
	hitarea.add_child(cs)
	hitarea.position = dir * (_radius + 14.0)
	add_child(hitarea)
	Fx.play("slash", global_position + dir * (_radius + 18.0), _radius * 2.4)
	Juice.add_trauma(0.3)
	get_tree().create_timer(0.2).timeout.connect(hitarea.queue_free)

func _execute_ability(ab: Dictionary) -> void:
	_attack_t = 0.4  # show the attack animation when an ability fires
	_attack_anim = String(ab.get("anim", "attack"))  # bespoke per-attack sheet
	# Projectile attacks were silent (they bypass the weapon); give each boss a
	# shot cue with a per-creature pitch so every attack is heard.
	var _k := String(ab.get("kind", ""))
	if _k in ["nova", "spread", "barrage", "breath", "gaze", "beam"]:
		var _pitch := 0.8 + (float(absi(hash(data.id)) % 100) / 100.0 - 0.5) * 0.5
		Events.shot_fired.emit(false, _pitch)
	match ab.get("kind", ""):
		"nova":
			_fire_pattern(int(ab.get("count", 8)), TAU, 0.0,
				float(ab.get("speed", 200.0)), float(ab.get("damage", 1.0)))
			Fx.play(_burst_fx(), global_position, _radius * 4.0)
		"spread":
			if is_instance_valid(_target):
				var base := (_target.global_position - _shoot_origin()).angle()
				_fire_pattern(int(ab.get("count", 5)), deg_to_rad(float(ab.get("spread", 40.0))),
					base, float(ab.get("speed", 240.0)), float(ab.get("damage", 1.0)))
		"summon":
			_summon(String(ab.get("entity", "")), int(ab.get("count", 2)), bool(ab.get("regen", false)))
		"charge":
			if is_instance_valid(_target):
				_charge_dir = (_target.global_position - _shoot_origin()).normalized()
				_charge_speed = float(ab.get("speed", 420.0))
				_charge_t = float(ab.get("duration", 0.45))
				_charge_vanish = bool(ab.get("vanish", false))  # fade during the dash
				Fx.play(_burst_fx(), global_position, _radius * 3.0)
		"barrage":
			# A tight, fast volley aimed at the player.
			if is_instance_valid(_target):
				var base := (_target.global_position - _shoot_origin()).angle()
				_fire_pattern(int(ab.get("count", 5)), deg_to_rad(float(ab.get("spread", 12.0))),
					base, float(ab.get("speed", 300.0)), float(ab.get("damage", 1.0)))
		"breath":
			_breath(ab)
		"beam":
			# A fast, thin PIERCING bolt fired straight at the player — reads as a
			# laser lance that streaks through in a line.
			if is_instance_valid(_target) and _pool != null:
				var bdir := (_target.global_position - _shoot_origin()).normalized()
				var bd := Damage.new(float(ab.get("damage", 1.0)) * _difficulty, ["enemy", "beam"], self)
				_pool.spawn(_shoot_origin() + bdir * (_radius + 8.0),
					bdir * float(ab.get("speed", 560.0)), bd, false,
					float(ab.get("radius", 5.0)), Color(0.6, 1.0, 0.9),
					float(ab.get("life", 1.1)), true, "projectile_" + data.id)
				Fx.play(_burst_fx(), global_position, _radius * 2.5)
		"gaze":
			# Ancient-god gaze: a telegraphed THICK eye-beam that scorches the arena.
			_eye_beam(ab)
		"slam":
			# A giant tentacle hammers the ground where the player stands, then a
			# shockwave ring bursts out from the impact.
			if is_instance_valid(_target):
				_tentacle_slam(_target.global_position, ab)
		"ringwave":
			# Several full rings in quick succession, each rotated a touch — a pulsing
			# shock-bloom that reads as expanding waves rolling outward.
			_attack_t = maxf(_attack_t, 1.1)
			var rw_waves := int(ab.get("waves", 3))
			var rw_count := int(ab.get("count", 18))
			var rw_speed := float(ab.get("speed", 185.0))
			var rw_dmg := float(ab.get("damage", 1.0))
			for w in rw_waves:
				get_tree().create_timer(float(w) * 0.26).timeout.connect(func() -> void:
					if not is_instance_valid(self) or _pool == null:
						return
					var off := float(w) * 0.20
					for i in rw_count:
						_shoot(Vector2.from_angle(off + TAU * float(i) / float(rw_count)), rw_speed, rw_dmg)
					Fx.play(_burst_fx(), _shoot_origin(), _radius * 2.4)
					Events.shot_fired.emit(false, 0.7))
		"spiral":
			# A rotating multi-arm spiral: bullets stream while the firing angle turns,
			# painting curved arms across the arena.
			_attack_t = maxf(_attack_t, 1.2)
			var sp_shots := int(ab.get("count", 26))
			var sp_arms := int(ab.get("arms", 2))
			var sp_speed := float(ab.get("speed", 200.0))
			var sp_step := deg_to_rad(float(ab.get("step", 15.0)))
			var sp_dmg := float(ab.get("damage", 1.0))
			for i in sp_shots:
				get_tree().create_timer(float(i) * 0.05).timeout.connect(func() -> void:
					if not is_instance_valid(self) or _pool == null:
						return
					for a in sp_arms:
						_shoot(Vector2.from_angle(float(i) * sp_step + TAU * float(a) / float(sp_arms)), sp_speed, sp_dmg, 9.0, Color(0.7, 0.55, 1.0), "projectile_spiral")
					Events.shot_fired.emit(false, 0.85))
		"fan":
			# A sweeping fan aimed at the hero — a wall of bullets that wipes across an
			# arc like a searchlight.
			if is_instance_valid(_target):
				_attack_t = maxf(_attack_t, 1.1)
				var fn_shots := int(ab.get("count", 14))
				var fn_sweep := deg_to_rad(float(ab.get("sweep", 120.0)))
				var fn_speed := float(ab.get("speed", 240.0))
				var fn_dmg := float(ab.get("damage", 1.0))
				var fn_base := (_target.global_position - _shoot_origin()).angle() - fn_sweep * 0.5
				for i in fn_shots:
					get_tree().create_timer(float(i) * 0.06).timeout.connect(func() -> void:
						if not is_instance_valid(self) or _pool == null:
							return
						var fa := fn_base + fn_sweep * float(i) / float(maxi(1, fn_shots - 1))
						_shoot(Vector2.from_angle(fa), fn_speed, fn_dmg)
						Events.shot_fired.emit(false, 0.9))
		"flower":
			# Several concentric rings released at once at different speeds/offsets —
			# blooms outward like petals.
			var fl_petals := int(ab.get("count", 12))
			var fl_layers := int(ab.get("layers", 3))
			var fl_dmg := float(ab.get("damage", 1.0))
			for fl in fl_layers:
				var fl_off := float(fl) * 0.13
				var fl_spd := 120.0 + float(fl) * 75.0
				for i in fl_petals:
					_shoot(Vector2.from_angle(fl_off + TAU * float(i) / float(fl_petals)), fl_spd, fl_dmg, 10.0, Color(1.0, 0.8, 0.9), "projectile_petal")
			Fx.play(_burst_fx(), _shoot_origin(), _radius * 3.0)
			Events.shot_fired.emit(false, 0.8)
		"hydra_heads":
			# HYDRA signature: many heads spit venom from spread mouths, staggered.
			if is_instance_valid(_target):
				_attack_t = maxf(_attack_t, 1.0)
				var hh_n := int(ab.get("heads", 5))
				var hh_sp := float(ab.get("speed", 230.0))
				var hh_dmg := float(ab.get("damage", 2.0))
				var hh_org := _shoot_origin()
				var hh_aim := (_target.global_position - hh_org).angle()
				for hh in hh_n:
					get_tree().create_timer(float(hh) * 0.09).timeout.connect(func() -> void:
						if not is_instance_valid(self) or _pool == null:
							return
						var hpos := hh_org + Vector2((float(hh) - float(hh_n - 1) / 2.0) * (_radius * 0.45), -_radius * 0.25)
						for j in 3:
							var a := hh_aim + deg_to_rad((float(j) - 1.0) * 9.0)
							var d := Damage.new(hh_dmg * _difficulty, ["enemy"], self)
							_pool.spawn(hpos, Vector2.from_angle(a) * hh_sp, d, false, 9.0, Color(0.5, 0.95, 0.4), 3.0, false, "projectile_" + data.id)
						Events.shot_fired.emit(false, 0.85))
		"hex":
			# RANGDA signature: the witch plants delayed curse-zones around the hero.
			if is_instance_valid(_target):
				_attack_t = maxf(_attack_t, 1.0)
				var hx_n := int(ab.get("spots", 5))
				var hx_rad := float(ab.get("radius", 58.0))
				var hx_dmg := float(ab.get("damage", 2.0))
				var hx_rng := RNG.stream("combat")
				var hx_base := _target.global_position
				for sidx in hx_n:
					var hx_pos := hx_base + Vector2.from_angle(hx_rng.randf() * TAU) * (hx_rng.randf() * hx_rad * 2.4)
					_ground_zone(hx_pos, hx_rad, hx_dmg, 0.7 + float(sidx) * 0.12, Color(0.7, 0.2, 0.85))
				Events.shot_fired.emit(false, 0.55)
		"coil":
			# APOPHIS signature: the world-serpent coils a closing ring around the
			# hero (with one gap to slip through) that converges inward.
			if _pool != null:
				_attack_t = maxf(_attack_t, 1.0)
				var co_n := int(ab.get("count", 30))
				var co_rr := float(ab.get("ring_radius", 340.0))
				var co_sp := float(ab.get("speed", 150.0))
				var co_dmg := float(ab.get("damage", 2.0))
				var co_gap := deg_to_rad(float(ab.get("gap", 42.0)))
				var co_gd := randf() * TAU
				var co_c := _target.global_position if is_instance_valid(_target) else _shoot_origin()
				for k in co_n:
					var ang := TAU * float(k) / float(co_n)
					if absf(wrapf(ang - co_gd, -PI, PI)) < co_gap * 0.5:
						continue
					var spawn := co_c + Vector2.from_angle(ang) * co_rr
					var d := Damage.new(co_dmg * _difficulty, ["enemy"], self)
					_pool.spawn(spawn, (co_c - spawn).normalized() * co_sp, d, false, 9.0, Color(0.9, 0.8, 0.4), 4.0, false, "projectile_" + data.id)
				Events.shot_fired.emit(false, 0.7)
		"pounce":
			# FENRIR signature: the wolf LEAPS onto the hero, then a landing shock.
			if is_instance_valid(_target):
				_attack_t = maxf(_attack_t, 0.9)
				_charge_dir = (_target.global_position - global_position).normalized()
				_charge_speed = float(ab.get("speed", 620.0))
				_charge_t = float(ab.get("duration", 0.4))
				_charge_vanish = false
				var po_dmg := float(ab.get("damage", 3.0))
				var po_rad := float(ab.get("radius", 85.0))
				Fx.play(_burst_fx(), global_position, _radius * 2.0)
				Audio.play_sfx("hit", 0.9)
				get_tree().create_timer(float(ab.get("duration", 0.4))).timeout.connect(func() -> void:
					if is_instance_valid(self):
						_ground_zone(global_position, po_rad, po_dmg, 0.22, Color(0.6, 0.7, 1.0)))
		"sequence_heads":
			# OROCHI signature: eight heads strike one after another across an arc.
			if is_instance_valid(_target):
				_attack_t = maxf(_attack_t, 1.2)
				var sh_n := int(ab.get("heads", 8))
				var sh_sp := float(ab.get("speed", 300.0))
				var sh_dmg := float(ab.get("damage", 2.0))
				var sh_arc := deg_to_rad(float(ab.get("arc", 120.0)))
				var sh_org := _shoot_origin()
				var sh_aim := (_target.global_position - sh_org).angle()
				for hh in sh_n:
					get_tree().create_timer(float(hh) * 0.12).timeout.connect(func() -> void:
						if not is_instance_valid(self) or _pool == null:
							return
						var a := sh_aim + (float(hh) / float(maxi(1, sh_n - 1)) - 0.5) * sh_arc
						for j in 2:
							var d := Damage.new(sh_dmg * _difficulty, ["enemy"], self)
							_pool.spawn(sh_org + Vector2.from_angle(a) * (_radius * 0.5), Vector2.from_angle(a) * (sh_sp - float(j) * 40.0), d, false, 10.0, Color(0.6, 0.3, 0.9), 3.0, false, "projectile_" + data.id)
						Events.shot_fired.emit(false, 0.8 + float(hh) * 0.03))
		"erupt_lines":
			# CIPACTLI signature: rows of ground spikes erupt outward in rays.
			_attack_t = maxf(_attack_t, 1.1)
			var er_rays := int(ab.get("rays", 6))
			var er_steps := int(ab.get("steps", 5))
			var er_rad := float(ab.get("radius", 46.0))
			var er_dmg := float(ab.get("damage", 2.0))
			var er_gap := float(ab.get("step_gap", 70.0))
			var er_base := _shoot_origin()
			var er_off := randf() * TAU
			for r in er_rays:
				var er_ang := er_off + TAU * float(r) / float(er_rays)
				for st in er_steps:
					_ground_zone(er_base + Vector2.from_angle(er_ang) * (er_gap * float(st + 1)), er_rad, er_dmg, 0.5 + float(st) * 0.14, Color(0.8, 0.55, 0.2))

## A flame/energy BREATH: a dense, fast stream of short-lived projectiles in a
## tight cone toward the player — reads as a long jet of flame when the projectile
## art (projectile_<id>) is an animated flame strip. Stays deterministic (seeded).
func _breath(ab: Dictionary) -> void:
	if _pool == null or not is_instance_valid(_target):
		return
	var rng := RNG.stream("combat")
	var base := (_target.global_position - _shoot_origin()).angle()
	var spread := deg_to_rad(float(ab.get("spread", 34.0)))
	var dmg := float(ab.get("damage", 1.0))
	var prad := float(ab.get("radius", 11.0))
	var life := float(ab.get("life", 1.0))
	var smax := float(ab.get("speed", 360.0))
	var col := Color(1.0, 0.55, 0.2)  # tinted only if generic art (themed wins)
	for k in int(ab.get("count", 16)):
		var ang := base + (rng.randf() - 0.5) * spread
		var sp := lerpf(smax * 0.5, smax, rng.randf())
		var dir := Vector2.from_angle(ang)
		var d := Damage.new(dmg * _difficulty, ["enemy", "fire"], self)
		_pool.spawn(_shoot_origin() + dir * (_radius + 6.0), dir * sp, d, false,
			prad, col, life, false, "projectile_" + data.id)
	Fx.play(_burst_fx(), global_position, _radius * 3.0)

## Where this enemy's ranged attacks ORIGINATE. The background colossus is drawn
## high up while its hurtbox sits low, so shots must leave from the visible body
## (the torso), otherwise they look detached from him.
func _shoot_origin() -> Vector2:
	if data.background_boss and _anim != null:
		return global_position + _anim.position
	return global_position

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
		var d := Damage.new(dmg * _difficulty, ["enemy"], self)
		_pool.spawn(_shoot_origin() + dir * (_radius + 8.0), dir * speed, d, false,
			8.0, Color(1, 0.5, 0.4), 3.0, false, "projectile_" + data.id)

## Fire ONE themed projectile from the body in `dir` at `speed` (pattern helper).
func _shoot(dir: Vector2, speed: float, dmg: float, radius: float = 8.0, col: Color = Color(1.0, 0.5, 0.4), sprite: String = "") -> void:
	if _pool == null:
		return
	var sn := sprite if sprite != "" and Fx.has(sprite) else "projectile_" + data.id
	var d := Damage.new(dmg * _difficulty, ["enemy"], self)
	_pool.spawn(_shoot_origin() + dir * (_radius + 8.0), dir * speed, d, false,
		radius, col, 3.0, false, sn)

## A telegraphed ground zone: a ring swells at `pos`, then after `delay` a damage
## disc fires once with a burst. Building block for bespoke boss attacks
## (curses, eruptions, pounce landings). `dmg` is base (scaled by difficulty here).
func _ground_zone(pos: Vector2, rad: float, dmg: float, delay: float, col: Color) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var root := Node2D.new()
	root.global_position = pos
	root.z_index = 5
	parent.add_child(root)
	var disk := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 22:
		pts.append(Vector2.from_angle(TAU * float(i) / 22.0) * rad)
	disk.polygon = pts
	disk.color = Color(col.r, col.g, col.b, 0.0)
	disk.scale = Vector2(0.35, 0.35)
	root.add_child(disk)
	var tele := create_tween()
	tele.set_parallel(true)
	tele.tween_property(disk, "color:a", 0.5, delay)
	tele.tween_property(disk, "scale", Vector2.ONE, delay)
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		if not is_instance_valid(root):
			return
		var area := DamageArea.new()
		area.collision_layer = Collision.ENEMY_DMG
		area.collision_mask = Collision.PLAYER_HURT
		area.setup(Damage.new(dmg * _difficulty, ["enemy"], self), false, 0.3)
		var cs := CollisionShape2D.new()
		var circ := CircleShape2D.new()
		circ.radius = rad
		cs.shape = circ
		area.add_child(cs)
		root.add_child(area)
		Fx.play(_burst_fx(), pos, rad * 2.5)
		Audio.play_sfx("hit", 0.7)
		get_tree().create_timer(0.35).timeout.connect(func() -> void:
			if is_instance_valid(root):
				root.queue_free()))

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
	# Small delay so a slain head doesn't pop back instantly (telegraphed regrowth).
	get_tree().create_timer(0.9).timeout.connect(func():
		if is_instance_valid(self) and health != null and health.fraction() > 0.0:
			_summon(entity_id, 1, true))

## The bespoke attack-animation names declared on this entity's abilities, so the
## sprite pipeline can load a sheet per attack (<id>_<anim>.png).
func _ability_anim_names() -> Array:
	var names: Array = []
	names.append("emerge")  # boss-intro rise sheet (loaded only if the file exists)
	names.append("scream")  # the animated roar sheet (loaded if present)
	names.append("idle2")  # background-colossus idle variety (loaded if present)
	names.append("idle3")
	for src in [data.abilities, data.phase2_abilities]:
		if src is Array:
			for ab in src:
				var n := String(ab.get("anim", ""))
				if n != "" and not names.has(n):
					names.append(n)
	return names

## Final boss: a fringe of face tentacles, each swaying on its OWN phase/speed so
## they writhe independently (alive), layered over the colossus sprite.
func _setup_tentacles() -> void:
	var head := (_anim.position if _anim != null else Vector2.ZERO) + Vector2(0.0, -_radius * 0.55)
	var n := 7
	for i in n:
		var t := Line2D.new()
		t.width = _radius * 0.085
		t.default_color = Color(0.16, 0.30, 0.24, 0.95)
		t.joint_mode = Line2D.LINE_JOINT_ROUND
		t.begin_cap_mode = Line2D.LINE_CAP_ROUND
		t.end_cap_mode = Line2D.LINE_CAP_ROUND
		t.z_index = 3
		add_child(t)
		var u := float(i) / float(n - 1) - 0.5
		_tentacles.append({
			"node": t,
			"base": head + Vector2(u * _radius * 1.2, _radius * 0.2),
			"ang": PI * 0.5 + u * 1.3,
			"phase": randf() * TAU,
			"speed": 1.3 + randf() * 1.1,
			"len": _radius * (1.1 + randf() * 0.7),
		})

func _update_tentacles(delta: float) -> void:
	if _tentacles.is_empty():
		return
	var time := Time.get_ticks_msec() / 1000.0
	for tt in _tentacles:
		var node: Line2D = tt["node"]
		var pts := PackedVector2Array()
		var segs := 9
		var p: Vector2 = tt["base"]
		var ang: float = tt["ang"]
		var seglen: float = float(tt["len"]) / float(segs)
		for sidx in segs:
			pts.append(p)
			var wob := sin(time * float(tt["speed"]) + float(tt["phase"]) + float(sidx) * 0.55) * 0.28
			ang += wob
			p += Vector2.from_angle(ang) * seglen
		node.points = pts

## Final boss: two glowing red eyes (PointLight2D) near the head, dark until the
## roar ignites them. Pulse handled in _update_eyes.
func _setup_eyes() -> void:
	_eyeL = Atmosphere.point_light(Color(1.0, 0.12, 0.06), 0.0, 72.0)
	_eyeL.position = Vector2(-_radius * 0.22, -_radius * 0.52)
	add_child(_eyeL)
	_eyeR = Atmosphere.point_light(Color(1.0, 0.12, 0.06), 0.0, 72.0)
	_eyeR.position = Vector2(_radius * 0.22, -_radius * 0.52)
	add_child(_eyeR)

## Ease the eye glow toward its target and add a slow living pulse.
func _update_eyes(delta: float) -> void:
	if _eyeL == null:
		return
	_eye_base = lerpf(_eye_base, _eye_target, clampf(delta * 3.0, 0.0, 1.0))
	var t := Time.get_ticks_msec() / 1000.0
	var e: float = _eye_base * (0.72 + 0.28 * sin(t * 6.0))
	_eyeL.energy = e
	_eyeR.energy = e

## Light the eyes (called on the roar beat by the intro cinematic).
func ignite_eyes() -> void:
	_eye_target = 1.8

## Play the animated roar (the colossus thrashes its tentacles and flares).
func play_scream() -> void:
	if _anim == null or _anim.sprite_frames == null or not _anim.sprite_frames.has_animation("scream"):
		return
	_attack_anim = "scream"
	_attack_t = maxf(_attack_t, 1.1)
	_anim.play("scream")

## Play the bespoke rise sheet during the intro, if it exists.
func play_intro_emerge() -> void:
	if _anim != null and _anim.sprite_frames != null and _anim.sprite_frames.has_animation("emerge"):
		_anim.play("emerge")

## A telegraphed tentacle SLAM: a marker grows on the floor, then a tentacle
## crashes down (impact damage) and a shockwave ring of projectiles bursts out.
## Ancient-god GAZE: a thin red telegraph line from the eyes, then a thick beam
## that fires through the player's position, damaging everything along its length.
func _eye_beam(ab: Dictionary) -> void:
	if not is_instance_valid(_target):
		return
	var parent := get_parent()
	if parent == null:
		return
	_eye_target = maxf(_eye_target, 2.8)
	var origin: Vector2 = global_position + Vector2(0.0, -_radius * 0.2)
	var dir: Vector2 = (_target.global_position - origin).normalized()
	var length := 1600.0
	var endp: Vector2 = origin + dir * length
	var dmg := float(ab.get("damage", 2.0)) * _difficulty
	# Telegraph: a thin pulsing red line for ~0.5s.
	var warn := Line2D.new()
	warn.width = 3.0
	warn.default_color = Color(1.0, 0.2, 0.2, 0.6)
	warn.points = PackedVector2Array([origin, endp])
	warn.z_index = 6
	parent.add_child(warn)
	var wt := warn.create_tween()
	wt.set_loops(3)
	wt.tween_property(warn, "modulate:a", 0.25, 0.12)
	wt.tween_property(warn, "modulate:a", 1.0, 0.12)
	get_tree().create_timer(0.5).timeout.connect(func() -> void:
		if is_instance_valid(warn):
			warn.queue_free()
		# The beam itself: a stretched pixel-art beam sprite (PixelLab) along the ray.
		var beam: Node2D
		if ResourceLoader.exists("res://assets/sprites/fx/beam_cthulhu.png"):
			var bs := Sprite2D.new()
			bs.texture = load("res://assets/sprites/fx/beam_cthulhu.png")
			bs.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			bs.global_position = origin + dir * (length * 0.5)
			bs.rotation = dir.angle()
			bs.scale = Vector2(length / float(bs.texture.get_width()), 34.0 / float(bs.texture.get_height()))
			bs.z_index = 7
			parent.add_child(bs)
			beam = bs
		else:
			var bl := Line2D.new()
			bl.width = 28.0
			bl.default_color = Color(1.0, 0.28, 0.22, 0.95)
			bl.begin_cap_mode = Line2D.LINE_CAP_ROUND
			bl.end_cap_mode = Line2D.LINE_CAP_ROUND
			bl.points = PackedVector2Array([origin, endp])
			bl.z_index = 7
			parent.add_child(bl)
			beam = bl
		var area := DamageArea.new()
		area.collision_layer = Collision.ENEMY_DMG
		area.collision_mask = Collision.PLAYER_HURT
		area.setup(Damage.new(dmg, ["enemy", "beam"], self), false, 0.2)
		var cs := CollisionShape2D.new()
		var cap := CapsuleShape2D.new()
		cap.radius = 16.0
		cap.height = length
		cs.shape = cap
		cs.position = origin + dir * (length * 0.5)
		cs.rotation = dir.angle() + PI / 2.0
		area.add_child(cs)
		parent.add_child(area)
		Fx.play(_burst_fx(), origin, _radius * 2.0)
		Juice.add_trauma(0.4)
		get_tree().create_timer(0.28).timeout.connect(func() -> void:
			if is_instance_valid(beam):
				beam.queue_free()
			if is_instance_valid(area):
				area.queue_free()))

func _tentacle_slam(pos: Vector2, ab: Dictionary) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var dmg := float(ab.get("damage", 2.0)) * _difficulty
	var rad := float(ab.get("radius", 95.0))
	var shock_n := int(ab.get("shock_count", 18))
	var shock_sp := float(ab.get("shock_speed", 210.0))
	# Telegraph marker (a dark ring that swells), no damage yet.
	var root := Node2D.new()
	root.global_position = pos
	root.z_index = 5
	parent.add_child(root)
	var disk := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 22:
		pts.append(Vector2.from_angle(TAU * float(i) / 22.0) * rad)
	disk.polygon = pts
	disk.color = Color(0.5, 0.08, 0.12, 0.0)
	disk.scale = Vector2(0.4, 0.4)
	root.add_child(disk)
	var tele := create_tween()
	tele.set_parallel(true)
	tele.tween_property(disk, "color:a", 0.5, 0.55)
	tele.tween_property(disk, "scale", Vector2.ONE, 0.55)
	# Impact after the telegraph: damage zone + burst FX + shockwave ring + shake.
	get_tree().create_timer(0.55).timeout.connect(func() -> void:
		if not is_instance_valid(root):
			return
		var area := DamageArea.new()
		area.collision_layer = Collision.ENEMY_DMG
		area.collision_mask = Collision.PLAYER_HURT
		area.setup(Damage.new(dmg, ["enemy", "slam"], self), false, 0.4)
		var cs := CollisionShape2D.new()
		var circ := CircleShape2D.new()
		circ.radius = rad
		cs.shape = circ
		area.add_child(cs)
		root.add_child(area)
		Fx.play(_burst_fx(), pos, rad * 3.0)
		Juice.add_trauma(0.45)
		Audio.play_sfx("hit", 0.6)  # heavy slam thud
		if data.background_boss:
			# A real pixel-art tentacle ERUPTS at the struck spot (PixelLab art).
			Fx.play("burst_cthulhu_tentacle" if Fx.has("burst_cthulhu_tentacle") else _burst_fx(), pos, rad * 4.0)
		if _pool != null:
			for k in shock_n:
				var dir := Vector2.from_angle(TAU * float(k) / float(maxi(1, shock_n)))
				var sd := Damage.new(dmg * 0.5, ["enemy"], self)
				_pool.spawn(pos + dir * (rad * 0.4), dir * shock_sp, sd, false,
					8.0, Color(1.0, 0.4, 0.4), 2.2, false, "projectile_" + data.id)
		get_tree().create_timer(0.45).timeout.connect(func() -> void:
			if is_instance_valid(root):
				root.queue_free()))

## Phase-2 arena hazard: a telegraphed pool of void that erupts under the player,
## then ticks damage for a few seconds. A dark disk + a purple glow read it clearly.
func _spawn_void_pool(pos: Vector2) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var root := Node2D.new()
	root.global_position = pos
	root.z_index = 5
	parent.add_child(root)
	var disk := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 20:
		pts.append(Vector2.from_angle(TAU * float(i) / 20.0) * 72.0)
	disk.polygon = pts
	disk.color = Color(0.32, 0.05, 0.46, 0.0)
	disk.scale = Vector2(0.4, 0.4)
	root.add_child(disk)
	var glow := Atmosphere.point_light(Color(0.6, 0.2, 0.95), 0.0, 130.0)
	root.add_child(glow)
	# Telegraph (~0.55s): grow + brighten, no damage yet.
	var tele := create_tween()
	tele.set_parallel(true)
	tele.tween_property(disk, "color:a", 0.55, 0.55)
	tele.tween_property(disk, "scale", Vector2.ONE, 0.55)
	tele.tween_property(glow, "energy", 1.1, 0.55)
	# Arm a ticking DamageArea once the telegraph lands.
	var area := DamageArea.new()
	area.collision_layer = Collision.ENEMY_DMG
	area.collision_mask = Collision.PLAYER_HURT
	area.setup(Damage.new(1.0 * _difficulty, ["enemy", "void"], self), false, 0.5)
	var cs := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 70.0
	cs.shape = circ
	area.add_child(cs)
	area.monitoring = false
	root.add_child(area)
	get_tree().create_timer(0.55).timeout.connect(func() -> void:
		if is_instance_valid(area):
			area.monitoring = true
		Fx.play(_burst_fx(), pos, 200.0))
	get_tree().create_timer(3.4).timeout.connect(func() -> void:
		if is_instance_valid(root):
			var ft := root.create_tween()
			ft.set_parallel(true)
			ft.tween_property(disk, "color:a", 0.0, 0.5)
			ft.tween_property(glow, "energy", 0.0, 0.5))
	get_tree().create_timer(4.0).timeout.connect(func() -> void:
		if is_instance_valid(root):
			root.queue_free())

func _on_died() -> void:
	# FINAL BOSS fake-out: the first time his bar empties he FEIGNS death — the
	# watching gods rejoice — then he revives at full HP for the true phase 2.
	if data.id == "hell_cthulhu" and not _feigned and not data.phase2_abilities.is_empty():
		_feigned = true
		if health != null:
			health.invulnerable = true
		set_physics_process(false)
		if contact != null:
			contact.set_deferred("monitorable", false)
		if _eyeL != null:
			_eyeL.energy = 0.0
		if _eyeR != null:
			_eyeR.energy = 0.0
		_feign_y0 = position.y
		if _anim != null and _anim.sprite_frames != null and _anim.sprite_frames.has_animation("death"):
			_anim.play("death")
		var slump := create_tween()
		slump.tween_property(self, "position:y", position.y + 90.0, 1.0) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		Events.emit_signal("boss_fake_death", self)
		return
	RunManager.on_enemy_killed(data.gold)
	Events.emit_signal("entity_died", self)
	# Play the death animation before despawning, if there is one.
	if _anim != null and _anim.sprite_frames != null and _anim.sprite_frames.has_animation("death"):
		set_physics_process(false)
		if contact != null:
			contact.set_deferred("monitorable", false)
		_anim.play("death")
		if data.id == "hell_cthulhu":
			# The Old God collapses and sinks back beneath the rain.
			if _eyeL != null:
				_eyeL.energy = 0.0
				_eyeR.energy = 0.0
			var dt := create_tween()
			dt.set_parallel(true)
			dt.tween_property(self, "position", position + Vector2(0.0, 170.0), 1.8) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			dt.tween_property(_anim, "modulate:a", 0.0, 1.8)
			await dt.finished
		else:
			await _anim.animation_finished
	queue_free()

## Final boss: rise AGAIN for phase 2 after the feigned death and the gods' relief.
func revive_phase2() -> void:
	if health == null:
		return
	health.setup(data.max_health)   # refill the bar + clear the death flag
	health.invulnerable = false
	set_physics_process(true)
	if contact != null:
		contact.set_deferred("monitorable", true)
	var rise := create_tween()
	rise.tween_property(self, "position:y", _feign_y0, 1.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _anim != null and _anim.sprite_frames != null and _anim.sprite_frames.has_animation("idle"):
		_anim.play("idle")
	ignite_eyes()
	play_scream()
	_enter_phase2()

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
