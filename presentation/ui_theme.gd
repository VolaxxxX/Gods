extends Node
## Builds the game-wide UI Theme and applies it to the root window, so every
## Button / Panel / PanelContainer / ProgressBar is styled at once. Uses 9-slice
## textures from assets/sprites/ui/ when present, else clean StyleBoxFlat
## fallbacks (so the UI already looks good before any art). Also sets the UI font.

const UI := "res://assets/sprites/ui/"
const FONT_TTF := "res://assets/fonts/ui.ttf"
const FONT_OTF := "res://assets/fonts/ui.otf"

# Gold / bronze accent used across the UI.
const ACCENT := Color(0.85, 0.72, 0.38)
const INK := Color(0.95, 0.92, 0.85)

func _ready() -> void:
	get_tree().root.theme = _build()

func _build() -> Theme:
	var t := Theme.new()
	var f := _font()
	if f != null:
		t.default_font = f
	t.default_font_size = 20

	var panel := _box("panel", 24, Color(0.10, 0.10, 0.14, 0.94))
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)

	t.set_stylebox("normal", "Button", _box("button", 16, Color(0.16, 0.16, 0.22, 0.96)))
	t.set_stylebox("hover", "Button", _box("button_hover", 16, Color(0.22, 0.22, 0.30, 0.98)))
	t.set_stylebox("pressed", "Button", _box("button_pressed", 16, Color(0.12, 0.12, 0.16, 1.0)))
	t.set_stylebox("disabled", "Button", _box("button", 16, Color(0.12, 0.12, 0.14, 0.6)))
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", Color(1, 1, 1))
	t.set_color("font_disabled_color", "Button", Color(0.5, 0.5, 0.55))

	t.set_stylebox("background", "ProgressBar", _bar("bar_bg", Color(0.06, 0.06, 0.09, 0.95)))
	t.set_stylebox("fill", "ProgressBar", _bar("bar_fill", Color(0.78, 0.20, 0.22, 1.0)))
	t.set_color("font_color", "Label", INK)
	return t

func _font() -> FontFile:
	for p in [FONT_TTF, FONT_OTF]:
		if ResourceLoader.exists(p):
			return load(p)
	return null

## 9-slice texture box if assets/sprites/ui/<name>.png exists, else a rounded flat box.
func _box(name: String, margin: float, flat_color: Color) -> StyleBox:
	var path := UI + name + ".png"
	if ResourceLoader.exists(path):
		var sb := StyleBoxTexture.new()
		sb.texture = load(path)
		sb.texture_margin_left = margin
		sb.texture_margin_right = margin
		sb.texture_margin_top = margin
		sb.texture_margin_bottom = margin
		sb.content_margin_left = margin
		sb.content_margin_right = margin
		sb.content_margin_top = margin * 0.6
		sb.content_margin_bottom = margin * 0.6
		return sb
	var f := StyleBoxFlat.new()
	f.bg_color = flat_color
	f.set_corner_radius_all(10)
	f.set_border_width_all(2)
	f.border_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.5)
	f.set_content_margin_all(14)
	return f

func _bar(name: String, flat_color: Color) -> StyleBox:
	var path := UI + name + ".png"
	if ResourceLoader.exists(path):
		var sb := StyleBoxTexture.new()
		sb.texture = load(path)
		sb.texture_margin_left = 6
		sb.texture_margin_right = 6
		sb.texture_margin_top = 6
		sb.texture_margin_bottom = 6
		return sb
	var f := StyleBoxFlat.new()
	f.bg_color = flat_color
	f.set_corner_radius_all(6)
	return f
