extends "res://tests/test_case.gd"
## StatBlock aggregation math.

const StatBlockC = preload("res://systems/progression/stat_block.gd")

func run() -> Dictionary:
	print("[StatBlock]")
	var sb = StatBlockC.new({"damage": 2.0, "speed": 100.0})
	check(is_equal_approx(sb.value("damage"), 2.0), "base value")

	sb.add_modifiers({"damage_add": 3.0})
	check(is_equal_approx(sb.value("damage"), 5.0), "additive: 2 + 3 = 5")

	sb.add_modifiers({"damage_mult": 2.0})
	check(is_equal_approx(sb.value("damage"), 10.0), "(2 + 3) * 2 = 10")

	sb.add_modifiers({"speed_mult": 1.5})
	check(is_equal_approx(sb.value("speed"), 150.0), "independent stat: speed * 1.5")
	check(is_equal_approx(sb.value("unknown"), 0.0), "unknown stat resolves to 0")

	# Add order must not matter: (base + all adds) * all mults.
	var sb2 = StatBlockC.new({"x": 10.0})
	sb2.add_modifiers({"x_mult": 2.0})
	sb2.add_modifiers({"x_add": 5.0})
	check(is_equal_approx(sb2.value("x"), 30.0), "(10 + 5) * 2 = 30 regardless of order")

	return result()
