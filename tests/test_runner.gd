extends SceneTree
## Headless test entry point.
##   godot --headless --script res://tests/test_runner.gd
## Exits with code 0 if all pass, 1 otherwise (CI-friendly).

func _initialize() -> void:
	var suites := [
		preload("res://tests/test_rng.gd").new(),
		preload("res://tests/test_damage.gd").new(),
		preload("res://tests/test_floor_generator.gd").new(),
		preload("res://tests/test_stat_block.gd").new(),
		preload("res://tests/test_synergy.gd").new(),
		preload("res://tests/test_meta_upgrade.gd").new(),
		preload("res://tests/test_soul_judgment.gd").new(),
	]

	var total := 0
	var failed := 0
	for suite in suites:
		var r: Dictionary = suite.run()
		total += int(r["total"])
		failed += int(r["failed"])

	print("\n==== %d checks, %d failed ====" % [total, failed])
	quit(1 if failed > 0 else 0)
