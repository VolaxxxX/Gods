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

var _radius: float = 12.0
var _color: Color = Color(0.85, 0.3, 0.3)
var _flash: float = 0.0

func setup(p_data: EntityData, target: Node2D) -> void:
	data = p_data
	_radius = data.radius
	_color = data.color

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

func _ready() -> void:
	add_to_group("enemies")

func _physics_process(delta: float) -> void:
	if ai != null:
		var dir := ai.desired_direction(global_position)
		velocity = movement.compute(velocity, dir, delta)
		move_and_slide()
	# Contact damage now ticks via the hurtbox cooldown (retrigger_interval).
	if _flash > 0.0:
		_flash -= delta
	queue_redraw()

func _on_died() -> void:
	Events.emit_signal("entity_died", self)
	queue_free()

func _draw() -> void:
	var c := Color(1, 1, 1) if _flash > 0.0 else _color
	draw_circle(Vector2.ZERO, _radius, c)
	# Health pip (thin arc) so damage is readable in greybox.
	if health != null and health.fraction() < 1.0:
		var w := _radius * 2.0 * health.fraction()
		draw_rect(Rect2(-_radius, -_radius - 8.0, w, 3.0), Color(0.2, 1.0, 0.3))
