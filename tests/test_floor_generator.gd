extends "res://tests/test_case.gd"
## Floor generation: reachability, determinism, and special-room quotas.
## Tests the pure build_graph() so no autoloads/rendering are required.

const FloorGen = preload("res://systems/floor/floor_generator.gd")

func run() -> Dictionary:
	print("[FloorGenerator]")
	var gen = FloorGen.new()

	var g1 = gen.build_graph(12345, 10)
	check(g1.count() >= 4, "produces at least 4 rooms")
	check(g1.all_reachable(), "every room is reachable from the start (no orphans)")
	check(g1.get_node(g1.start_pos)["type"] == "start", "start room is typed 'start'")

	# Determinism: same seed -> identical layout & types.
	var g2 = gen.build_graph(12345, 10)
	check(g1.count() == g2.count(), "same seed -> same room count")
	check(_identical(g1, g2), "same seed -> identical positions and types")

	# Exactly one boss, and it's a dead-end.
	var boss_count := 0
	var boss_pos = null
	for pos in g1.nodes:
		if g1.nodes[pos]["type"] == "boss":
			boss_count += 1
			boss_pos = pos
	check(boss_count == 1, "exactly one boss room")
	check(boss_pos != null and g1.nodes[boss_pos]["neighbors"].size() == 1,
		"boss room is a dead-end")

	return result()

func _identical(a, b) -> bool:
	if a.nodes.size() != b.nodes.size():
		return false
	for pos in a.nodes:
		if not b.nodes.has(pos):
			return false
		if a.nodes[pos]["type"] != b.nodes[pos]["type"]:
			return false
	return true
