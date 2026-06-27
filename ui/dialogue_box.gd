class_name DialogueBox
extends CanvasLayer
## Shows a speaker's lines one by one with an optional portrait. Two modes:
##   modal = true  → dims + pauses the game, tap/Enter to advance (hub story).
##   modal = false → a toast at the bottom, no pause, auto-advances (in-run boons).
##
## Presentation only, and ALIVE: the panel slides up, the portrait fades in and
## breathes, the text types itself out, and a blinking arrow invites the tap.
## All animation is driven by hand in _process so it keeps running while the tree
## is paused (modal beats pause the game). Frees itself when finished.

signal finished

const CHARS_PER_SEC := 42.0   # typewriter speed
const INTRO_DUR := 0.22       # panel slide / portrait fade-in
const TOAST_BASE := 1.6       # toast: minimum seconds a fully-typed line lingers
const TOAST_PER_CHAR := 0.045 # toast: extra linger per character (so long lines stay)
const BOB_AMPL := 4.0         # portrait idle breathing, pixels

const VOICE_STRIDE := 3       # play a voice blip every Nth revealed character

var _speaker := ""
var _speaker_id := ""
var _portrait: Texture2D
var _lines: Array = []
var _modal := false
var _voiced_upto := 0         # last character index we played a blip for

var _i := 0
var _text: Label
var _panel: PanelContainer
var _pic: TextureRect
var _arrow: Label

var _anim_t := 0.0            # global clock for bob + arrow blink
var _intro_t := 0.0          # 0→1 panel/portrait entrance
var _reveal := 0.0           # characters revealed so far (typewriter)
var _full_len := 0           # length of the current line
var _hold := 0.0             # seconds a fully-typed toast has lingered
var _base_top := -210.0
var _base_bottom := -30.0
var _pic_base_y := 0.0

func setup(speaker_name: String, portrait: Texture2D, lines: Array, modal: bool,
		speaker_id: String = "") -> void:
	_speaker = speaker_name
	_speaker_id = speaker_id
	_portrait = portrait
	_lines = lines
	_modal = modal

func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _lines.is_empty():
		_close()
		return
	if _modal:
		get_tree().paused = true
		var dim := ColorRect.new()
		dim.color = Color(0, 0, 0, 0.5)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dim)

	# In-run toasts are a slim, centered banner so they never cover the battlefield;
	# modal (hub/story) beats keep the full wide box.
	var inset := 40.0
	if not _modal:
		inset = 270.0
		_base_top = -118.0
		_base_bottom = -22.0

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_left = inset
	_panel.offset_right = -inset
	_panel.offset_top = _base_top
	_panel.offset_bottom = _base_bottom
	# Dedicated dialogue frame if provided, else the global themed panel.
	var frame := "res://assets/sprites/ui/dialogue.png"
	if ResourceLoader.exists(frame):
		# Crop to opaque bounds: PixelLab exports centre the art in a big
		# transparent square, so 9-slice must slice the actual frame, not padding.
		var tex: Texture2D = _crop(load(frame))
		var sb := StyleBoxTexture.new()
		sb.texture = tex
		var mw: float = tex.get_width() * 0.22
		var mh: float = tex.get_height() * 0.22
		sb.texture_margin_left = mw
		sb.texture_margin_right = mw
		sb.texture_margin_top = mh
		sb.texture_margin_bottom = mh
		sb.content_margin_left = mw
		sb.content_margin_right = mw
		sb.content_margin_top = mh
		sb.content_margin_bottom = mh
		_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_panel.add_child(row)

	if _portrait != null:
		# A plain Control wrapper reserves the layout slot; the picture floats
		# inside it so we can bob/rise it without the container snapping it back.
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(140, 140) if _modal else Vector2(74, 74)
		slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(slot)
		_pic = TextureRect.new()
		_pic.texture = _portrait
		_pic.set_anchors_preset(Control.PRESET_FULL_RECT)
		_pic.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot.add_child(_pic)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var nameplate := Label.new()
	nameplate.text = _speaker
	nameplate.add_theme_font_size_override("font_size", 26 if _modal else 20)
	# Dark bronze + a soft outline so the name reads on the light parchment panel
	# (pale gold washed out against it).
	nameplate.add_theme_color_override("font_color", Color(0.32, 0.18, 0.06))
	nameplate.add_theme_color_override("font_outline_color", Color(1, 0.94, 0.78, 0.9))
	nameplate.add_theme_constant_override("outline_size", 4)
	UITheme.title(nameplate)
	col.add_child(nameplate)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Dark ink on the parchment, readable regardless of the panel's shade.
	_text.add_theme_color_override("font_color", Color(0.16, 0.11, 0.07))
	_text.add_theme_color_override("font_outline_color", Color(1, 0.96, 0.85, 0.7))
	_text.add_theme_constant_override("outline_size", 3)
	col.add_child(_text)

	# A blinking "tap to continue" cue at the panel's right edge, modal only
	# (toasts auto-advance and need no prompt).
	if _modal:
		_arrow = Label.new()
		_arrow.text = "▼"
		_arrow.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		_arrow.size_flags_vertical = Control.SIZE_SHRINK_END
		_arrow.custom_minimum_size = Vector2(28, 0)
		_arrow.add_theme_font_size_override("font_size", 24)
		_arrow.add_theme_color_override("font_color", Color(0.32, 0.18, 0.06))
		_arrow.add_theme_color_override("font_outline_color", Color(1, 0.94, 0.78, 0.85))
		_arrow.add_theme_constant_override("outline_size", 3)
		_arrow.visible = false
		row.add_child(_arrow)

	_panel.modulate.a = 0.0
	_show_line()

## Crop a texture to its opaque bounds (mirrors UITheme._cropped) so the
## dialogue frame's 9-slice lands on the ornament, not the transparent padding.
func _crop(tex: Texture2D) -> Texture2D:
	var img := tex.get_image()
	if img == null:
		return tex
	var r := img.get_used_rect()
	if r.size.x <= 0 or r.size.y <= 0:
		return tex
	if r.position == Vector2i.ZERO and r.size == Vector2i(tex.get_width(), tex.get_height()):
		return tex
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(r)
	return at

func _show_line() -> void:
	_text.text = Loc.t(String(_lines[_i]))
	_full_len = _text.text.length()
	_reveal = 0.0
	_hold = 0.0
	_voiced_upto = 0
	_text.visible_characters = 0
	if _arrow != null:
		_arrow.visible = false

func _fully_revealed() -> bool:
	return _reveal >= float(_full_len)

func _advance() -> void:
	_i += 1
	if _i >= _lines.size():
		_close()
	else:
		_show_line()

func _process(delta: float) -> void:
	_anim_t += delta

	# Panel entrance: slide up from below + fade in.
	if _intro_t < 1.0:
		_intro_t = minf(1.0, _intro_t + delta / INTRO_DUR)
		var e := _ease_out(_intro_t)
		var drop := (1.0 - e) * 70.0
		_panel.offset_top = _base_top + drop
		_panel.offset_bottom = _base_bottom + drop
		_panel.modulate.a = e

	var talking := _intro_t > 0.4 and not _fully_revealed()

	# Portrait breathing + entrance rise (only once the panel has arrived). While
	# the line is still typing the bob is quicker and deeper, so the speaker looks
	# animated/"talking"; it settles to a slow idle breath once done.
	if _pic != null:
		var rise := (1.0 - _ease_out(_intro_t)) * 18.0
		var rate := 7.0 if talking else 2.2
		var ampl := (BOB_AMPL + 1.5) if talking else BOB_AMPL
		var bob := sin(_anim_t * rate) * ampl * _intro_t
		_pic.position.y = _pic_base_y - rise + bob
		_pic.modulate.a = _intro_t

	# Typewriter reveal, gated until the panel is mostly in.
	if talking:
		_reveal = minf(float(_full_len), _reveal + CHARS_PER_SEC * delta)
		_text.visible_characters = int(_reveal)
		# A voice blip every few characters, skipping whitespace, so the speaker
		# "talks" as the line types out.
		var shown := int(_reveal)
		while _voiced_upto < shown:
			_voiced_upto += 1
			if _voiced_upto % VOICE_STRIDE == 0 and _voiced_upto <= _full_len:
				var ch := _text.text.substr(_voiced_upto - 1, 1)
				if ch.strip_edges() != "":
					Audio.play_voice(_speaker_id)

	if _fully_revealed():
		_text.visible_characters = -1
		if _modal:
			# Blink the advance cue once the line is fully typed.
			if _arrow != null:
				_arrow.visible = fmod(_anim_t, 0.9) < 0.55
		else:
			# Toast: linger a beat scaled to the line's length, then auto-advance.
			_hold += delta
			if _hold >= TOAST_BASE + _full_len * TOAST_PER_CHAR:
				_advance()

func _ease_out(t: float) -> float:
	return 1.0 - pow(1.0 - clampf(t, 0.0, 1.0), 3.0)

## Use _input (fires BEFORE the GUI) so a tap ANYWHERE — including directly on
## the dialogue panel, which would otherwise swallow it — advances/skips the line.
func _input(event: InputEvent) -> void:
	if not _modal:
		return
	var pressed: bool = event.is_action_pressed("ui_accept") \
		or (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed)
	if not pressed:
		return
	# First tap finishes the typewriter; the next advances the line.
	if not _fully_revealed():
		_reveal = float(_full_len)
		_text.visible_characters = -1
	else:
		_advance()
	get_viewport().set_input_as_handled()

func _close() -> void:
	if _modal:
		get_tree().paused = false
	finished.emit()
	queue_free()
