extends "res://tests/test_case.gd"
## Synergy resolution: tag- and item-based activation, aggregation, no false-fires.

const SynergyEngineC = preload("res://systems/progression/synergy_engine.gd")
const SynergyDataC = preload("res://core/data/synergy_data.gd")
const ItemDataC = preload("res://core/data/item_data.gd")

func _item(id: String, tags: Array) -> ItemData:
	return ItemDataC.from_dict({"id": id, "tags": tags})

func run() -> Dictionary:
	print("[SynergyEngine]")
	var items := {
		"a": _item("a", ["crit"]),
		"b": _item("b", ["damage"]),
	}
	var synergies := [
		SynergyDataC.from_dict({"id": "exec", "requires_tags": ["crit", "damage"], "grants": {"crit_mult_add": 1.0}}),
		SynergyDataC.from_dict({"id": "pair", "requires_items": ["a", "b"], "grants": {"x_add": 1}}),
		SynergyDataC.from_dict({"id": "empty"}),
	]

	var r1 = SynergyEngineC.resolve(["a"], items, synergies)
	check(not ("exec" in r1["active"]), "one crit item does not trigger crit+damage")

	var r2 = SynergyEngineC.resolve(["a", "b"], items, synergies)
	check("exec" in r2["active"], "crit+damage tags trigger Executioner")
	check("pair" in r2["active"], "required items trigger their synergy")
	check(not ("empty" in r2["active"]), "degenerate empty synergy never triggers")
	check(r2["modifiers"].size() == 2, "active synergies contribute their modifiers")

	return result()
