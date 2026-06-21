class_name ProjectilePool
extends Node2D
## Object pool for projectiles. Reuses inactive instances instead of allocating,
## which matters on Web (GC pauses) and low-end Android. Owns the projectiles as
## children so they render in the run's world space.

@export var initial_size: int = 64

var _pool: Array[Projectile] = []

func _ready() -> void:
	for i in initial_size:
		_pool.append(_make())

func _make() -> Projectile:
	var p := Projectile.new()
	add_child(p)
	return p

## Fetch an inactive projectile, growing the pool if needed.
func acquire() -> Projectile:
	for p in _pool:
		if not p.active:
			return p
	var fresh := _make()
	_pool.append(fresh)
	return fresh

## Convenience: spawn a configured projectile in one call.
func spawn(pos: Vector2, velocity: Vector2, dmg: Damage, faction_player: bool,
		radius: float = 6.0, color: Color = Color(1, 1, 0.6), life: float = 2.0,
		pierce_through: bool = false, sprite_name: String = "") -> Projectile:
	var p := acquire()
	p.fire(pos, velocity, dmg, faction_player, radius, color, life, pierce_through, sprite_name)
	return p

func deactivate_all() -> void:
	for p in _pool:
		p._deactivate()
