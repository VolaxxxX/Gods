class_name TouchControls
extends Control
## Robust FIXED dual-joystick touch controls (Web + Android). Two anchored pads —
## MOVE bottom-left, AIM/FIRE bottom-right — plus a DASH button. Each finger is
## assigned to a pad by WHERE IT STARTS (its own zone), not by an X-split of the
## screen, so it works with single touches and is immune to content-scaling /
## multitouch-index quirks that previously broke movement on real phones.
## Presentation only: it writes player intent to GameInput, never reads game state.

const STICK_RADIUS := 82.0     # px to reach full tilt
const ZONE_RADIUS := 170.0     # how close to a pad a touch must start to grab it
const DASH_R := 76.0

var _move_id: int = -99
var _aim_id: int = -99
var _move_vec: Vector2 = Vector2.ZERO
var _aim_vec: Vector2 = Vector2.ZERO

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fit()
	var vp := get_viewport()
	if vp != null and not vp.size_changed.is_connected(_fit):
		vp.size_changed.connect(_fit)

func _fit() -> void:
	size = get_viewport_rect().size
	queue_redraw()

func _vp() -> Vector2:
	return get_viewport_rect().size

func _move_center() -> Vector2:
	var s := _vp()
	return Vector2(170.0, s.y - 170.0)

func _aim_center() -> Vector2:
	var s := _vp()
	return Vector2(s.x - 170.0, s.y - 170.0)

func _dash_center() -> Vector2:
	var s := _vp()
	return Vector2(s.x - 170.0, s.y - 360.0)

# Handle touch in _input so nothing else can swallow it first.
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event.index, event.position, event.pressed)
	elif event is InputEventScreenDrag:
		_on_drag(event.index, event.position)

func _on_touch(id: int, pos: Vector2, pressed: bool) -> void:
	if pressed:
		if pos.distance_to(_dash_center()) <= DASH_R:
			GameInput.request_dash()
			queue_redraw()
			return
		var near_move := pos.distance_to(_move_center()) <= ZONE_RADIUS
		var near_aim := pos.distance_to(_aim_center()) <= ZONE_RADIUS
		# Fallback: a press that misses both pads is assigned by screen half, so
		# movement still engages even if the thumb starts away from the pad.
		if not near_move and not near_aim:
			if pos.x < _vp().x * 0.5:
				near_move = true
			else:
				near_aim = true
		if _move_id == -99 and near_move:
			_move_id = id
			_set_move(pos)
		elif _aim_id == -99 and near_aim:
			_aim_id = id
			_set_aim(pos)
	else:
		if id == _move_id:
			_move_id = -99
			_move_vec = Vector2.ZERO
			GameInput.set_touch_move(Vector2.ZERO)
		elif id == _aim_id:
			_aim_id = -99
			_aim_vec = Vector2.ZERO
			GameInput.set_touch_aim(Vector2.ZERO)
			GameInput.set_touch_fire(false)
	queue_redraw()

func _on_drag(id: int, pos: Vector2) -> void:
	if id == _move_id:
		_set_move(pos)
	elif id == _aim_id:
		_set_aim(pos)
	# Fallback: an unmatched drag while exactly one pad is active updates it (some
	# mobile browsers renumber touch ids mid-gesture).
	elif _move_id != -99 and _aim_id == -99:
		_set_move(pos)
	elif _aim_id != -99 and _move_id == -99:
		_set_aim(pos)
	queue_redraw()

func _set_move(pos: Vector2) -> void:
	_move_vec = ((pos - _move_center()) / STICK_RADIUS).limit_length(1.0)
	GameInput.set_touch_move(_move_vec)

func _set_aim(pos: Vector2) -> void:
	_aim_vec = ((pos - _aim_center()) / STICK_RADIUS).limit_length(1.0)
	GameInput.set_touch_aim(_aim_vec)
	GameInput.set_touch_fire(_aim_vec.length() > 0.15)

func _draw() -> void:
	_draw_pad(_move_center(), _move_vec, Color(0.5, 0.8, 1.0), "MOVE")
	_draw_pad(_aim_center(), _aim_vec, Color(1.0, 0.7, 0.4), "FIRE")
	# Dash button.
	var dc := _dash_center()
	draw_circle(dc, DASH_R, Color(0.85, 0.72, 0.38, 0.22))
	draw_arc(dc, DASH_R, 0.0, TAU, 28, Color(0.95, 0.82, 0.5, 0.95), 4.0)
	draw_string(ThemeDB.fallback_font, dc + Vector2(-DASH_R, 7.0), "DASH",
		HORIZONTAL_ALIGNMENT_CENTER, DASH_R * 2.0, 20, Color(0.98, 0.9, 0.62, 0.98))

func _draw_pad(center: Vector2, vec: Vector2, col: Color, label: String) -> void:
	var base := Color(col.r, col.g, col.b, 0.16)
	var line := Color(col.r, col.g, col.b, 0.6)
	draw_circle(center, STICK_RADIUS + 22.0, base)
	draw_arc(center, STICK_RADIUS + 22.0, 0.0, TAU, 40, line, 3.0)
	# knob
	var knob := center + vec * STICK_RADIUS
	draw_circle(knob, 30.0, Color(col.r, col.g, col.b, 0.55))
	draw_string(ThemeDB.fallback_font, center + Vector2(-STICK_RADIUS, STICK_RADIUS + 46.0),
		label, HORIZONTAL_ALIGNMENT_CENTER, STICK_RADIUS * 2.0, 16, Color(col.r, col.g, col.b, 0.7))
