extends Node
## Headless test entry as a SCENE (not --script), so the project's autoloads
## boot BEFORE the test scripts compile. floor_generator.gd references the RNG /
## Events / GameData autoloads in its runtime path, so it only compiles once those
## global identifiers are registered — which a normal scene boot guarantees.
##   godot --headless res://tests/test_main.tscn
## Exits 0 if all pass, 1 otherwise (CI-friendly).

func _ready() -> void:
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
	get_tree().quit(1 if failed > 0 else 0)
