extends "res://tests/test_case.gd"
## Meta-upgrade cost curve and modifier-key mapping.

const MetaUpgradeC = preload("res://core/data/meta_upgrade_data.gd")

func run() -> Dictionary:
	print("[MetaUpgrade]")
	var m = MetaUpgradeC.from_dict({
		"id": "v", "stat": "max_health", "mode": "add",
		"per_level": 1.0, "max_level": 3, "base_cost": 10, "cost_growth": 2.0,
	})
	check(m.cost_for_level(0) == 10, "first level costs the base")
	check(m.cost_for_level(1) == 20, "cost grows: 10 * 2^1")
	check(m.cost_for_level(2) == 40, "cost grows: 10 * 2^2")
	check(m.modifier_key() == "max_health_add", "additive mode -> _add key")

	var m2 = MetaUpgradeC.from_dict({"id": "x", "stat": "move_speed", "mode": "mult"})
	check(m2.modifier_key() == "move_speed_mult", "multiplicative mode -> _mult key")

	return result()
