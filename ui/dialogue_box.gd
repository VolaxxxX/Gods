class_name DialogueBox
extends CanvasLayer
## Shows a speaker's lines one by one with an optional portrait. Two modes:
##   modal = true  → dims + pauses the game, tap/Enter to advance (hub story).
##   modal = false → a toast at the bottom, no pause, auto-advances (in-run boons).
## Presentation only. Frees itself when finished.

signal finished

const TOAST_SECONDS := 3.5

var _speaker := ""
var _portrait: Texture2D
var _lines: Array = []
var _modal := false

var _i := 0
var _t := 0.0
var _text: Label

func setup(speaker_name: String, portrait: Texture2D, lines: Array, modal: bool) -> void:
	_speaker = speaker_name
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

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 40
	panel.offset_right = -40
	panel.offset_top = -210
	panel.offset_bottom = -30
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
		panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)

	if _portrait != null:
		var pic := TextureRect.new()
		pic.texture = _portrait
		pic.custom_minimum_size = Vector2(140, 140)
		pic.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(pic)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var nameplate := Label.new()
	nameplate.text = _speaker
	nameplate.add_theme_font_size_override("font_size", 26)
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
	_t = 0.0
	_text.text = Loc.t(String(_lines[_i]))

func _advance() -> void:
	_i += 1
	if _i >= _lines.size():
		_close()
	else:
		_show_line()

func _process(delta: float) -> void:
	if not _modal:  # toast auto-advances
		_t += delta
		if _t >= TOAST_SECONDS:
			_advance()

func _unhandled_input(event: InputEvent) -> void:
	if not _modal:
		return
	if event.is_action_pressed("ui_accept") or event is InputEventScreenTouch and event.pressed \
			or (event is InputEventMouseButton and event.pressed):
		_advance()
		get_viewport().set_input_as_handled()

func _close() -> void:
	if _modal:
		get_tree().paused = false
	finished.emit()
	queue_free()
