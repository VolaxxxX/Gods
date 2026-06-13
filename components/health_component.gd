class_name HealthComponent
extends Node
## Health & death for any entity. Composition: attach to player/enemy and wire
## a HurtboxComponent to it. No rendering, no input — pure state + signals.

signal damaged(amount: float, current: float, maximum: float)
signal healed(amount: float, current: float, maximum: float)
signal died

@export var max_health: float = 10.0
var health: float = 0.0
var invulnerable: bool = false
var _dead: bool = false
## Optional hook: takes incoming amount, returns possibly-modified amount
## (e.g. blessings that deflect/reduce damage). Set by the owning entity.
var damage_filter: Callable = Callable()

func _ready() -> void:
	if health <= 0.0:
		health = max_health

func setup(p_max: float, p_current: float = -1.0) -> void:
	max_health = p_max
	health = p_current if p_current >= 0.0 else p_max
	_dead = false

func apply(damage: Damage) -> void:
	if _dead or invulnerable or damage == null:
		return
	take(damage.amount)

func take(amount: float) -> void:
	if _dead or invulnerable or amount <= 0.0:
		return
	if damage_filter.is_valid():
		amount = float(damage_filter.call(amount))
		if amount <= 0.0:
			return
	health = maxf(0.0, health - amount)
	damaged.emit(amount, health, max_health)
	if health <= 0.0:
		_dead = true
		died.emit()

## Deliberate, unavoidable cost (sacrifices/offerings). Bypasses invulnerability
## and the damage filter — the player chose to pay this.
func spend(amount: float) -> void:
	if _dead or amount <= 0.0:
		return
	health = maxf(0.0, health - amount)
	damaged.emit(amount, health, max_health)
	if health <= 0.0:
		_dead = true
		died.emit()

func heal(amount: float) -> void:
	if _dead or amount <= 0.0:
		return
	health = minf(max_health, health + amount)
	healed.emit(amount, health, max_health)

func is_dead() -> bool:
	return _dead

func fraction() -> float:
	return health / max_health if max_health > 0.0 else 0.0
