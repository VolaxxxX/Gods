extends Node
## Centralized scene transitions. Keeps scene paths in one place and gives us a
## single seam to add fades/loading later without touching callers.

const BOOT := "res://scenes/boot/boot.tscn"
const HUB := "res://scenes/hub/hub.tscn"
const RUN := "res://scenes/run/run_scene.tscn"
const ENDING := "res://scenes/ending/ending.tscn"

func goto_hub() -> void:
	_change(HUB)

func goto_ending() -> void:
	_change(ENDING)

func goto_run() -> void:
	_change(RUN)

func goto_boot() -> void:
	_change(BOOT)

func _change(path: String) -> void:
	# Reset transient input so a held touch doesn't bleed across scenes.
	GameInput.reset()
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("SceneRouter: failed to load %s (err %d)" % [path, err])
