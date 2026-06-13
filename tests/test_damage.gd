extends "res://tests/test_case.gd"
## Damage model math (pure, no rendering).

const DamageScript = preload("res://systems/damage/damage.gd")

func run() -> Dictionary:
	print("[Damage]")

	var r = DamageScript.compute(10.0, {"damage_add": 5.0, "damage_mult": 2.0})
	check(is_equal_approx(r["amount"], 30.0), "(10 + 5) * 2 = 30")
	check(r["is_crit"] == false, "no crit roll without an RNG")

	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var rc = DamageScript.compute(10.0, {"crit_chance": 1.0, "crit_mult": 3.0}, rng)
	check(rc["is_crit"] == true, "crit_chance 1.0 always crits")
	check(is_equal_approx(rc["amount"], 30.0), "crit multiplies: 10 * 3 = 30")

	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 1
	var rn = DamageScript.compute(10.0, {"crit_chance": 0.0, "crit_mult": 3.0}, rng2)
	check(rn["is_crit"] == false, "crit_chance 0.0 never crits")

	var rz = DamageScript.compute(5.0, {"damage_mult": 0.0})
	check(rz["amount"] == 0.0, "damage clamps to >= 0")

	return result()
