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

# On-hit effects from blessings/synergies (e.g. chain lightning). Set by the
# player when stats are recomputed.
var on_hit_effects: Array = []

# Multi-shot / piercing (set per playable class). 1 shot, no spread by default.
var projectile_count: int = 1
var spread_deg: float = 0.0
var pierce: bool = false

var pool: ProjectilePool
var _cooldown: float = 0.0

func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta

func can_fire() -> bool:
	return _cooldown <= 0.0 and pool != null

## Fire toward `direction` from `origin`. Fires `projectile_count` shots across
## `spread_deg`. Returns true if it fired.
func attempt(origin: Vector2, direction: Vector2) -> bool:
	if not can_fire() or direction.length() < 0.01:
		return false
	_cooldown = 1.0 / maxf(0.01, fire_rate)
	var rng := RNG.stream("combat")
	var base_ang := direction.angle()
	var count: int = maxi(1, projectile_count)
	for k in count:
		var t := 0.0 if count == 1 else (float(k) / (count - 1) - 0.5)
		var ang := base_ang + deg_to_rad(spread_deg) * t
		var rolled := Damage.compute(base_damage, {
			"crit_chance": crit_chance, "crit_mult": crit_mult,
		}, rng)
		var dmg := Damage.new(rolled["amount"], damage_tags.duplicate(), get_parent())
		dmg.is_crit = rolled["is_crit"]
		var vel := Vector2.from_angle(ang) * projectile_speed
		var p := pool.spawn(origin, vel, dmg, faction_player, projectile_radius,
			projectile_color, projectile_life, pierce)
		if faction_player and not on_hit_effects.is_empty():
			p.on_hit_extra = _on_projectile_hit
	return true

## Applies on-hit blessing/synergy effects when a player projectile lands.
func _on_projectile_hit(pos: Vector2, hurtbox) -> void:
	var struck = hurtbox.get_parent() if hurtbox != null else null
	for fx in on_hit_effects:
		if fx.get("effect", "") == "chain_lightning":
			_chain_lightning(pos, struck, float(fx.get("value", 3.0)))

func _chain_lightning(from: Vector2, exclude, amount: float) -> void:
	var best = null  # untyped for dynamic .health access (Enemy)
	var best_d := INF
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == exclude or not is_instance_valid(e):
			continue
		var d: float = from.distance_squared_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	if best != null and best_d <= 220.0 * 220.0 and best.health != null:
		best.health.take(amount)
