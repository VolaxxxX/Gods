class_name TouchControls
extends Control
## Floating twin-stick touch controls that feed GameInput. Works with real touch
## (Web + Android) and with mouse (desktop testing) via a synthetic touch index.
## Left screen half = move stick, right half = aim+fire stick. Multi-touch aware.
##
## Presentation only: it never reads game state, only writes player intent.

const STICK_RADIUS := 90.0      # px to reach full tilt
const MOUSE_INDEX := -1

var _move_index: int = -99
var _move_origin: Vector2
var _move_pos: Vector2
var _aim_index: int = -99
var _aim_origin: Vector2
var _aim_pos: Vector2

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # don't steal from HUD buttons

func _unhandled_input(event: InputEvent) -> void:
	# Real touch only. On desktop the mouse aims/fires (handled by the player)
	# and the keyboard moves — the mouse must NOT spawn a floating joystick,
	# which felt like an obstacle ("rond infranchissable").
	if event is InputEventScreenTouch:
		_handle_touch(event.index, event.position, event.pressed)
	elif event is InputEventScreenDrag:
		_handle_drag(event.index, event.position)

func _handle_touch(index: int, pos: Vector2, pressed: bool) -> void:
	if pressed:
		var is_left := pos.x < size.x * 0.5
		if is_left and _move_index == -99:
			_move_index = index
			_move_origin = pos
			_move_pos = pos
		elif not is_left and _aim_index == -99:
			_aim_index = index
			_aim_origin = pos
			_aim_pos = pos
	else:
		if index == _move_index:
			_move_index = -99
			GameInput.set_touch_move(Vector2.ZERO)
		elif index == _aim_index:
			_aim_index = -99
			GameInput.set_touch_aim(Vector2.ZERO)
			GameInput.set_touch_fire(false)
	_apply()
	queue_redraw()

func _handle_drag(index: int, pos: Vector2) -> void:
	if index == _move_index:
		_move_pos = pos
	elif index == _aim_index:
		_aim_pos = pos
	_apply()
	queue_redraw()

func _apply() -> void:
	if _move_index != -99:
		GameInput.set_touch_move(_vector(_move_origin, _move_pos))
	if _aim_index != -99:
		var v := _vector(_aim_origin, _aim_pos)
		GameInput.set_touch_aim(v)
		GameInput.set_touch_fire(v.length() > 0.15)

func _vector(origin: Vector2, pos: Vector2) -> Vector2:
	return ((pos - origin) / STICK_RADIUS).limit_length(1.0)

func _draw() -> void:
	if _move_index != -99:
		_draw_stick(_move_origin, _move_pos, Color(0.5, 0.8, 1.0, 0.5))
	if _aim_index != -99:
		_draw_stick(_aim_origin, _aim_pos, Color(1.0, 0.7, 0.4, 0.5))

func _draw_stick(origin: Vector2, pos: Vector2, color: Color) -> void:
	draw_arc(origin, STICK_RADIUS, 0, TAU, 32, color, 3.0)
	var knob := origin + (pos - origin).limit_length(STICK_RADIUS)
	draw_circle(knob, 26.0, color)
