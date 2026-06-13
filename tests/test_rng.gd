extends "res://tests/test_case.gd"
## RNG determinism & stream independence.

const RNGScript = preload("res://core/rng/rng.gd")

func run() -> Dictionary:
	print("[RNG]")
	var r = RNGScript.new()

	# Same seed -> same sequence.
	r.seed_from_int(42)
	var a := []
	for i in 5:
		a.append(r.stream("loot").randi())
	r.seed_from_int(42)
	var b := []
	for i in 5:
		b.append(r.stream("loot").randi())
	check(a == b, "same seed reproduces the same sequence")

	# Streams are independent: consuming one must not desync another.
	r.seed_from_int(7)
	var first := r.stream("layout").randi()
	r.seed_from_int(7)
	var _other = r.stream("audio").randi()  # consume a different stream first
	var first_again := r.stream("layout").randi()
	check(first == first_again, "named streams are independent")

	# String seeding is deterministic.
	r.seed_from_string("hello")
	var s1 := r.get_seed()
	r.seed_from_string("hello")
	check(s1 == r.get_seed(), "string seed is deterministic")

	return result()
