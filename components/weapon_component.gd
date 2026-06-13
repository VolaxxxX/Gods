class_name WeaponComponent
extends Node
## Fires pooled projectiles at a cadence. Stats are mutable so items/blessings
## can modify them (Phase 2). Faction decides who the projectiles hurt.

@export var fire_rate: float = 4.0       # shots per second
@export var projectile_speed: float = 420.0
@export var base_damage: float = 2.0
@export var projectile_radius: float = 6.0
@export var projectile_color: Color = Color(1, 1, 0.6)
@export var projectile_life: float = 1.2
@export var faction_player: bool = true

# Synergy hooks (read by the damage model / Phase 2).
var damage_tags: Array[String] = ["projectile"]
var crit_chance: float = 0.0
var crit_mult: float = 2.0

var pool: ProjectilePool
var _cooldown: float = 0.0

func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta

func can_fire() -> bool:
	return _cooldown <= 0.0 and pool != null

## Fire one shot toward `direction` from `origin`. Returns true if it fired.
func attempt(origin: Vector2, direction: Vector2) -> bool:
	if not can_fire() or direction.length() < 0.01:
		return false
	_cooldown = 1.0 / maxf(0.01, fire_rate)
	var rng := RNG.stream("combat")
	var rolled := Damage.compute(base_damage, {
		"crit_chance": crit_chance, "crit_mult": crit_mult,
	}, rng)
	var dmg := Damage.new(rolled["amount"], damage_tags.duplicate(), get_parent())
	dmg.is_crit = rolled["is_crit"]
	var vel := direction.normalized() * projectile_speed
	pool.spawn(origin, vel, dmg, faction_player, projectile_radius, projectile_color, projectile_life)
	return true
