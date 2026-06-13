class_name Damage
extends RefCounted
## Pure, headless-testable damage model. Combat code builds a DamageInfo and
## HealthComponent consumes it; the math lives here so it can be unit-tested
## without any rendering (DoD: damage calc must be testable).

var amount: float = 0.0
var source = null               # who dealt it (entity / null)
var tags: Array = []            # e.g. ["lightning","projectile"] for synergies
var is_crit: bool = false

func _init(p_amount: float = 0.0, p_tags: Array = [], p_source = null) -> void:
	amount = p_amount
	tags = p_tags
	source = p_source

## Compute final outgoing damage from a base value and a modifier dictionary.
## Deterministic when given a seeded RNG stream (or null = no crit roll).
## modifiers keys (all optional):
##   damage_add (float), damage_mult (float, default 1),
##   crit_chance (0..1), crit_mult (default 2.0)
## Returns { "amount": float, "is_crit": bool }.
static func compute(base: float, modifiers: Dictionary, rng: RandomNumberGenerator = null) -> Dictionary:
	var add: float = float(modifiers.get("damage_add", 0.0))
	var mult: float = float(modifiers.get("damage_mult", 1.0))
	var value: float = (base + add) * mult

	var crit := false
	var crit_chance: float = float(modifiers.get("crit_chance", 0.0))
	if crit_chance > 0.0 and rng != null:
		if rng.randf() < crit_chance:
			crit = true
			value *= float(modifiers.get("crit_mult", 2.0))

	return {"amount": maxf(0.0, value), "is_crit": crit}
