extends Control
## The true ending: a quiet, code-drawn cinematic. The soul crosses the river of
## the dead one last time — but this crossing leads up, into the light it fled.
## Rising gradient + a growing doorway of light + drifting motes + the closing
## narration in Cinzel. Tap to advance; the last tap returns to the hub.
## No art assets required (fully procedural), so it always looks intentional.

var _lines: Array = []
var _i := 0
var _t := 0.0          # total elapsed
var _line_t := 0.0     # time on the current line
var _light := 0.0      # 0..1 rising-light progress (eases toward target)
var _finished := false  # past the last line -> waiting for the return tap
var _label: Label
var _hint: Label
var _soul: Node2D
var _warm := Color(0.95, 0.78, 0.42)   # realm-tinted mid colour of the rising light
var _bright := Color(1.0, 0.98, 0.92)  # realm-tinted light the soul ascends into

# The light each realm's soul rises into has its own colour identity.
const REALM_LIGHT := {
	"greece": {"warm": Color(0.86, 0.80, 0.55), "bright": Color(1.0, 1.0, 0.97), "mote": Color(1.0, 0.92, 0.70)},
	"bali":   {"warm": Color(0.52, 0.74, 0.48), "bright": Color(0.96, 1.0, 0.94), "mote": Color(0.80, 1.0, 0.70)},
	"egypt":  {"warm": Color(0.93, 0.74, 0.36), "bright": Color(1.0, 0.98, 0.90), "mote": Color(1.0, 0.90, 0.58)},
	"norse":  {"warm": Color(0.56, 0.74, 0.95), "bright": Color(0.96, 0.99, 1.0), "mote": Color(0.82, 0.92, 1.0)},
	"japan":  {"warm": Color(0.88, 0.50, 0.52), "bright": Color(1.0, 0.96, 0.95), "mote": Color(1.0, 0.80, 0.82)},
	"aztec":  {"warm": Color(0.84, 0.62, 0.34), "bright": Color(1.0, 0.97, 0.87), "mote": Color(1.0, 0.85, 0.54)},
}

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	Audio.play_music("hub")  # the calm threshold theme

	# The ending is themed by the realm the cycle was broken in. The grand finale
	# (all six conquered, ever) keeps its own closing words; a single-run victory
	# gets that realm's epilogue. Both are tinted to the realm's light.
	var realm: String = RunManager.biome_id
	var light: Dictionary = REALM_LIGHT.get(realm, REALM_LIGHT["greece"])
	_warm = light["warm"]
	_bright = light["bright"]
	var grand: bool = SaveManager.has_flag("all_six")
	var key: String = "narr_ending" if grand else "ending_" + realm
	var dd = GameData.dialogues.get(key, null)
	if dd == null:
		dd = GameData.dialogues.get("narr_ending", null)
	_lines = (dd.lines.duplicate() if dd != null else ["The cycle turns on."])
	if grand:
		SaveManager.mark_line_seen("narr_ending")  # consumed here; don't repeat at the hub

	# Rising golden motes.
	var motes := CPUParticles2D.new()
	motes.amount = 70
	motes.lifetime = 7.0
	motes.preprocess = 7.0
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(660, 30)
	motes.position = Vector2(640, 760)
	motes.gravity = Vector2(0, -34)
	motes.initial_velocity_min = 8.0
	motes.initial_velocity_max = 26.0
	motes.scale_amount_min = 1.5
	motes.scale_amount_max = 3.5
	var mote: Color = REALM_LIGHT.get(RunManager.biome_id, REALM_LIGHT["greece"])["mote"]
	mote.a = 0.85
	motes.color = mote
	add_child(motes)

	# The soul: the player sprite if present, else a soft greybox orb (drawn).
	var tex := Sprites.player(RunManager.character_id)
	if tex != null:
		var s := Sprite2D.new()
		s.texture = tex
		var cs := Sprites.content_size(tex)
		if cs > 0.0:
			s.scale = Vector2.ONE * (64.0 / cs)
		_soul = s
		add_child(_soul)

	var vp := get_viewport_rect().size
	_label = Label.new()
	# Absolute, full-width centered strip in the upper third (no anchor presets,
	# so autowrap gets the real width and the text truly centers).
	_label.position = Vector2(60, 130)
	_label.custom_minimum_size = Vector2(vp.x - 120, 0)
	_label.size = Vector2(vp.x - 120, 200)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 30)
	UITheme.title(_label)
	add_child(_label)

	_hint = Label.new()
	_hint.position = Vector2(60, vp.y - 72)
	_hint.custom_minimum_size = Vector2(vp.x - 120, 0)
	_hint.size = Vector2(vp.x - 120, 40)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.modulate = Color(0.85, 0.82, 0.7, 0.0)
	_hint.text = Loc.t("ui.tap_continue")
	add_child(_hint)

	_show_line()

func _show_line() -> void:
	_line_t = 0.0
	_label.text = Loc.t(String(_lines[_i])) if _i < _lines.size() else ""

func _process(delta: float) -> void:
	_t += delta
	_line_t += delta
	# Light rises as the narration advances (eased), reaching full at the end.
	var target: float = float(_i + 1) / float(max(1, _lines.size()))
	if _finished:
		target = 1.0
	_light = lerpf(_light, target, clampf(delta * 1.5, 0.0, 1.0))
	# Text fades in and shifts from light (on the dark start) to dark (on the bright
	# end) so it stays readable against the rising light.
	var a := clampf(_line_t / 0.8, 0.0, 1.0)
	var tc := lerpf(0.98, 0.14, _light)
	_label.modulate = Color(tc, tc, tc, a)
	var hint_a := 0.6 + 0.4 * sin(_t * 2.2)
	var ht := lerpf(0.85, 0.30, _light)
	_hint.modulate = Color(ht, ht, ht, clampf((_line_t - 1.2) * 2.0, 0.0, 1.0) * hint_a)
	# The soul drifts upward toward the light and brightens as it ascends.
	if _soul != null:
		var vp := get_viewport_rect().size
		var prog: float = clampf(0.15 + _light * 0.7, 0.0, 1.0)
		_soul.position = Vector2(vp.x * 0.5, lerpf(vp.y * 0.82, vp.y * 0.30, prog))
		var b := 0.45 + 0.55 * _light
		_soul.modulate = Color(b, b, b * 0.96 + 0.04, 1.0)
	queue_redraw()

func _draw() -> void:
	var vp := get_viewport_rect().size
	# Vertical gradient: deep underworld dark at the bottom -> warm gold -> bright
	# light at the top. The light "floods down" as _light rises.
	var bands := 40
	for i in bands:
		var f := float(i) / float(bands - 1)        # 0 top .. 1 bottom
		var lift: float = clampf(_light * 1.2 - (1.0 - f) * 0.2, 0.0, 1.0)
		var dark := Color(0.05, 0.05, 0.09)
		var top_col := _warm.lerp(_bright, _light)
		var col := dark.lerp(top_col, clampf((1.0 - f) + lift, 0.0, 1.0))
		draw_rect(Rect2(0, f * vp.y, vp.x, vp.y / bands + 1.0), col)
	# A growing doorway of light at the top centre.
	var lt := Atmosphere.light_texture()
	var r := 140.0 + 360.0 * _light
	var col2 := Color(1.0, 0.96, 0.85, 0.35 + 0.5 * _light)
	draw_texture_rect(lt, Rect2(vp.x * 0.5 - r, -r * 0.5, r * 2.0, r * 2.0), false, col2)
	# The river near the bottom: shimmering horizontal reflections.
	var ry := vp.y * 0.80
	for k in 7:
		var yy := ry + k * 10.0
		var a := 0.10 + 0.06 * sin(_t * 1.5 + k * 0.9)
		draw_rect(Rect2(0, yy, vp.x, 2.0), Color(0.7, 0.8, 1.0, a * (1.0 - _light * 0.7)))

func _unhandled_input(event: InputEvent) -> void:
	var advance: bool = event.is_action_pressed("ui_accept") \
		or (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed)
	if not advance:
		return
	get_viewport().set_input_as_handled()
	if _line_t < 0.4:
		return  # debounce / let the line breathe
	if _i < _lines.size() - 1:
		_i += 1
		_show_line()
	elif not _finished:
		_finished = true
		_label.text = Loc.t("ending.title")
	else:
		SceneRouter.goto_hub()
