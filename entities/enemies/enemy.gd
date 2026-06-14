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
var _sprite: Sprite2D  # set if a texture exists for this entity id

func setup(p_data: EntityData, target: Node2D, pool: ProjectilePool = null) -> void:
	data = p_data
	_target = target
	_pool = pool
	_radius = data.radius
	_color = data.color

	# Optional sprite (auto-loaded by entity id); greybox circle otherwise.
	var tex := Sprites.entity(data.id)
	if tex != null:
		_sprite = Sprite2D.new()
		_sprite.texture = tex
		var dim: float = maxf(tex.get_width(), tex.get_height())
		if dim > 0.0:
			_sprite.scale = Vector2.ONE * (2.2 * _radius / dim)
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
	if ai != null:
		var dir := ai.desired_direction(global_position)
		velocity = movement.compute(velocity, dir, delta)
		move_and_slide()
	# Ranged entities fire at the player (the weapon throttles via fire_rate).
	if weapon != null and is_instance_valid(_target):
		var aim := _target.global_position - global_position
		weapon.attempt(global_position + aim.normalized() * (_radius + 8.0), aim)
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
	if _sprite != null:
		_sprite.modulate = Color(1.8, 1.8, 1.8) if _flash > 0.0 else Color.WHITE
	queue_redraw()

func _enter_phase2() -> void:
	_phase2_done = true
	for ab in data.phase2_abilities:
		_abilities.append(ab)
		_ability_cd.append(0.6)  # the new attacks come online almost at once
	_flash = 0.25
	_fire_pattern(16, TAU, 0.0, 200.0, 1.0)  # dramatic phase-change burst
	Juice.add_trauma(0.6)

func _execute_ability(ab: Dictionary) -> void:
	match ab.get("kind", ""):
		"nova":
			_fire_pattern(int(ab.get("count", 8)), TAU, 0.0,
				float(ab.get("speed", 200.0)), float(ab.get("damage", 1.0)))
		"spread":
			if is_instance_valid(_target):
				var base := (_target.global_position - global_position).angle()
				_fire_pattern(int(ab.get("count", 5)), deg_to_rad(float(ab.get("spread", 40.0))),
					base, float(ab.get("speed", 240.0)), float(ab.get("damage", 1.0)))
		"summon":
			_summon(String(ab.get("entity", "")), int(ab.get("count", 2)))

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
			8.0, Color(1, 0.5, 0.4), 3.0)

func _summon(entity_id: String, count: int) -> void:
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

func _on_died() -> void:
	RunManager.on_enemy_killed(data.gold)
	Events.emit_signal("entity_died", self)
	queue_free()

func _draw() -> void:
	if _sprite == null:  # greybox body only when there's no texture
		var c := Color(1, 1, 1) if _flash > 0.0 else _color
		draw_circle(Vector2.ZERO, _radius, c)
	# Health pip (thin bar) so damage is readable.
	if health != null and health.fraction() < 1.0:
		var w := _radius * 2.0 * health.fraction()
		draw_rect(Rect2(-_radius, -_radius - 8.0, w, 3.0), Color(0.2, 1.0, 0.3))
