class_name HurtboxComponent
extends Area2D
## Receives damage on behalf of an entity. Each physics frame it scans the
## DamageAreas it overlaps and pulls their payload, with a per-source cooldown.
## This cleanly handles both one-shot projectiles (cooldown 0 -> they despawn on
## hit, so they never overlap again) and ticking contact damage (cooldown > 0).
##
## Faction is enforced by collision layers/masks set on the owner, so player
## damage only reaches enemies and vice versa (no friendly fire).

@export var health: HealthComponent

var _cooldowns: Dictionary = {}  # area instance_id -> seconds until it can hit again

func _ready() -> void:
	monitoring = true
	monitorable = true

func _physics_process(delta: float) -> void:
	if health == null or health.is_dead():
		return

	# Tick down cooldowns.
	for id in _cooldowns.keys():
		_cooldowns[id] -= delta
		if _cooldowns[id] <= 0.0:
			_cooldowns.erase(id)

	for area in get_overlapping_areas():
		if not (area is DamageArea):
			continue
		# A despawned (pooled, inactive) projectile must not deal damage.
		if area is Projectile and not area.active:
			continue
		var id := area.get_instance_id()
		if _cooldowns.has(id):
			continue
		health.apply(area.damage)
		area.report_hit(self)
		_cooldowns[id] = area.retrigger_interval
