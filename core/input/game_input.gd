extends Node
## Abstract twin-stick input layer. The single source of truth for player intent,
## fed by BOTH on-screen touch controls (Web + Android) AND keyboard/mouse
## (desktop testing). Gameplay reads these properties; it never reads raw input.
##
## This is the seam that lets the same gameplay run identically in a mobile
## browser and a native build, with no native API dependency.

# Normalized intent, updated every frame. Magnitude in [0, 1].
var move_vector: Vector2 = Vector2.ZERO
var aim_vector: Vector2 = Vector2.ZERO   # direction the player wants to shoot
var fire_held: bool = false

# Options (persisted via SaveManager later). Crucial for mobile comfort.
var auto_aim: bool = true
var auto_fire: bool = false

# Touch controls write here; cleared/overridden by keyboard when keys are used.
var _touch_move: Vector2 = Vector2.ZERO
var _touch_aim: Vector2 = Vector2.ZERO
var _touch_fire: bool = false

func _ready() -> void:
	_ensure_actions()

## Register keyboard movement actions in code (robust across Godot versions and
## avoids hand-serialized InputEvents in project.godot).
func _ensure_actions() -> void:
	var bindings := {
		"move_up": KEY_W, "move_down": KEY_S,
		"move_left": KEY_A, "move_right": KEY_D,
	}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = bindings[action]
		InputMap.action_add_event(action, ev)

func _process(_delta: float) -> void:
	# Keyboard movement (desktop). Falls back to touch when no keys pressed.
	var kb := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	move_vector = kb if kb.length() > 0.01 else _touch_move
	if move_vector.length() > 1.0:
		move_vector = move_vector.normalized()

	# Aim: touch right stick wins; else mouse aim relative to viewport center
	# is handled by the player (which knows its screen position). Here we just
	# expose the touch aim and fire state.
	aim_vector = _touch_aim
	fire_held = _touch_fire or aim_vector.length() > 0.1

# --- Called by touch UI ---
func set_touch_move(v: Vector2) -> void:
	_touch_move = v

func set_touch_aim(v: Vector2) -> void:
	_touch_aim = v

func set_touch_fire(held: bool) -> void:
	_touch_fire = held

func reset() -> void:
	_touch_move = Vector2.ZERO
	_touch_aim = Vector2.ZERO
	_touch_fire = false

# --- Options (persisted in SaveManager.meta.options) ---
## Loaded once after autoloads are up (called from the boot scene).
func load_options() -> void:
	var o: Dictionary = SaveManager.meta.get("options", {})
	auto_aim = bool(o.get("auto_aim", true))
	auto_fire = bool(o.get("auto_fire", false))

func set_auto_aim(value: bool) -> void:
	auto_aim = value
	_save_options()

func set_auto_fire(value: bool) -> void:
	auto_fire = value
	_save_options()

func _save_options() -> void:
	if not SaveManager.meta.has("options"):
		SaveManager.meta["options"] = {}
	SaveManager.meta["options"]["auto_aim"] = auto_aim
	SaveManager.meta["options"]["auto_fire"] = auto_fire
	SaveManager.save_meta()
