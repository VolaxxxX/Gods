extends Node
## Centralized scene transitions with a black fade so cuts never feel abrupt.
## Keeps scene paths in one place. The fade overlay lives on this autoload (which
## persists across scene changes) at a very high canvas layer, and runs even when
## the tree is paused.

const BOOT := "res://scenes/boot/boot.tscn"
const HUB := "res://scenes/hub/hub.tscn"
const RUN := "res://scenes/run/run_scene.tscn"
const ENDING := "res://scenes/ending/ending.tscn"

const FADE_OUT := 0.22
const FADE_IN := 0.30

var _fade: ColorRect
var _busy := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cl := CanvasLayer.new()
	cl.layer = 200  # above everything (HUD, dialogue, pause)
	add_child(cl)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(_fade)

func goto_hub() -> void:
	_change(HUB)

func goto_ending() -> void:
	_change(ENDING)

func goto_run() -> void:
	_change(RUN)

func goto_boot() -> void:
	_change(BOOT)

func _change(path: String) -> void:
	if _busy:
		return
	_busy = true
	await _fade_to(1.0, FADE_OUT)
	# Reset transient input so a held touch doesn't bleed across scenes.
	GameInput.reset()
	get_tree().paused = false  # a scene may have paused (death screen / pause menu)
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("SceneRouter: failed to load %s (err %d)" % [path, err])
	# Let the new scene build a couple of frames before revealing it.
	await get_tree().process_frame
	await get_tree().process_frame
	await _fade_to(0.0, FADE_IN)
	_busy = false

func _fade_to(target_alpha: float, dur: float) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", target_alpha, dur)
	await tw.finished
