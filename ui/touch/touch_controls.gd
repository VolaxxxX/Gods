class_name TouchControls
extends Control
## Floating twin-stick touch controls that feed GameInput. Works with real touch
## (Web + Android) and with mouse (desktop testing) via a synthetic touch index.
## Left screen half = move stick, right half = aim+fire stick. Multi-touch aware.
##
## IMPORTANT: all geometry uses the live VIEWPORT size (_vp), never Control.size —
## under a CanvasLayer the Control's `size` can stay 0 on real mobile, which made
## the left/right split collapse (everything read as the right/fire half, so
## movement never fired and the dash button drew off-screen).

const STICK_RADIUS := 90.0      # px to reach full tilt
const DASH_R := 74.0            # dash button radius (big = easy thumb target)

var _move_index: int = -99
var _move_origin: Vector2
var _move_pos: Vector2
var _aim_index: int = -99
var _aim_origin: Vector2
var _aim_pos: Vector2

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # don't steal from HUD buttons
	_fit()
	var vp := get_viewport()
	if vp != null and not vp.size_changed.is_connected(_fit):
		vp.size_changed.connect(_fit)

func _fit() -> void:
	size = get_viewport_rect().size  # keep the Control covering the whole screen
	queue_redraw()

func _vp() -> Vector2:
	return get_viewport_rect().size

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event.index, event.position, event.pressed)
	elif event is InputEventScreenDrag:
		_handle_drag(event.index, event.position)

## Dash button: right side, a thumb-reach above the fire-stick rest (near the aim
## joystick but clear of the very bottom corner so it never steals fire taps).
func _dash_center() -> Vector2:
	var s := _vp()
	return Vector2(s.x - 130.0, s.y - 320.0)

func _move_rest() -> Vector2:
	var s := _vp()
	return Vector2(150.0, s.y - 150.0)

func _handle_touch(index: int, pos: Vector2, pressed: bool) -> void:
	var s := _vp()
	if pressed:
		# Dash button takes priority over starting an aim stick.
		if pos.distance_to(_dash_center()) <= DASH_R:
			GameInput.request_dash()
			queue_redraw()
			return
		var is_left := pos.x < s.x * 0.5
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
	var s := _vp()
	# Always-visible dash button (right, above the fire thumb).
	var dc := _dash_center()
	draw_circle(dc, DASH_R, Color(0.85, 0.72, 0.38, 0.22))
	draw_arc(dc, DASH_R, 0, TAU, 28, Color(0.95, 0.82, 0.5, 0.9), 3.5)
	draw_string(ThemeDB.fallback_font, dc + Vector2(-DASH_R, 7), "DASH",
		HORIZONTAL_ALIGNMENT_CENTER, DASH_R * 2.0, 20, Color(0.98, 0.9, 0.62, 0.95))
	# Always-on MOVE hint (lower-left) so you know where to drag to walk.
	if _move_index == -99:
		var mr := _move_rest()
		draw_arc(mr, STICK_RADIUS * 0.7, 0, TAU, 32, Color(0.5, 0.8, 1.0, 0.22), 3.0)
		draw_circle(mr, 22.0, Color(0.5, 0.8, 1.0, 0.14))
		draw_string(ThemeDB.fallback_font, mr + Vector2(-STICK_RADIUS, STICK_RADIUS * 0.7 + 24.0),
			"MOVE", HORIZONTAL_ALIGNMENT_CENTER, STICK_RADIUS * 2.0, 16, Color(0.7, 0.85, 1.0, 0.6))
	# Faint hint of the FIRE zone (right) so the split is discoverable.
	if _aim_index == -99:
		var fr := Vector2(s.x - 150.0, s.y - 150.0)
		draw_arc(fr, STICK_RADIUS * 0.55, 0, TAU, 28, Color(1.0, 0.7, 0.4, 0.16), 3.0)
		draw_string(ThemeDB.fallback_font, fr + Vector2(-STICK_RADIUS, STICK_RADIUS * 0.55 + 24.0),
			"FIRE", HORIZONTAL_ALIGNMENT_CENTER, STICK_RADIUS * 2.0, 16, Color(1.0, 0.75, 0.5, 0.5))
	if _move_index != -99:
		_draw_stick(_move_origin, _move_pos, Color(0.5, 0.8, 1.0, 0.55))
	if _aim_index != -99:
		_draw_stick(_aim_origin, _aim_pos, Color(1.0, 0.7, 0.4, 0.55))

func _draw_stick(origin: Vector2, pos: Vector2, color: Color) -> void:
	draw_arc(origin, STICK_RADIUS, 0, TAU, 32, color, 3.0)
	var knob := origin + (pos - origin).limit_length(STICK_RADIUS)
	draw_circle(knob, 26.0, color)
