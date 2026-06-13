class_name StatBlock
extends RefCounted
## Aggregates a base stat set with any number of additive/multiplicative
## modifiers (from items, blessings, synergies). Pure & headless-testable.
##
## Convention per stat "X": modifiers contribute "X_add" (summed) and "X_mult"
## (multiplied). Final value = (base_X + sum_adds) * product_of_mults.
## Adding a new stat needs no code change here — just use its name in data.

var base: Dictionary = {}
var _mods: Array = []  # Array[Dictionary]

func _init(p_base: Dictionary = {}) -> void:
	base = p_base.duplicate()

func add_modifiers(mods: Dictionary) -> void:
	if mods != null and not mods.is_empty():
		_mods.append(mods)

func clear() -> void:
	_mods.clear()

## Final computed value for a stat.
func value(stat: String) -> float:
	var v := float(base.get(stat, 0.0))
	var add := 0.0
	var mult := 1.0
	for m in _mods:
		add += float(m.get(stat + "_add", 0.0))
		mult *= float(m.get(stat + "_mult", 1.0))
	return (v + add) * mult

## Snapshot of every base stat after modifiers (useful for applying to entities).
func resolve() -> Dictionary:
	var out := {}
	for stat in base:
		out[stat] = value(stat)
	return out
