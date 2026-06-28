extends Control
## Boot/splash. Also serves as the Web audio-unlock gate: browsers block audio
## until a user gesture, so we require one tap before entering the game.

# Shown on the title screen so you can confirm which build you're running (bump
# it when shipping). If the APK doesn't show this, it's an OLD build — rebuild.
const BUILD_TAG := "build 0.9.7 — god icon + tougher 2-phase bosses + new rooms/heal shrine"

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Apply saved control options now that all autoloads are initialized.
	# (UI theme + font are applied globally by the UITheme autoload.)
	GameInput.load_options()

	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.07)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var vp := get_viewport_rect().size
	var cx := vp.x * 0.5
	var cy := vp.y * 0.5

	var title := Label.new()
	title.text = Loc.t("game.title")
	title.add_theme_font_size_override("font_size", 96)
	title.add_theme_color_override("font_color", Color(0.9, 0.78, 0.42))
	title.position = Vector2(cx - 400, cy - 170)
	title.size = Vector2(800, 110)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.title(title)
	add_child(title)

	var tagline := Label.new()
	tagline.text = Loc.t("game.tagline")
	tagline.add_theme_font_size_override("font_size", 22)
	tagline.modulate = Color(0.75, 0.75, 0.82)
	tagline.position = Vector2(cx - 400, cy - 36)
	tagline.size = Vector2(800, 30)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(tagline)

	var btn := Button.new()
	btn.text = Loc.t("ui.tap_to_start")
	btn.position = Vector2(cx - 140, cy + 50)
	btn.size = Vector2(280, 64)
	btn.pressed.connect(_on_start)
	add_child(btn)

	# Sound/options right on the first screen.
	var opt := Button.new()
	opt.text = Loc.t("ui.options")
	opt.position = Vector2(cx - 140, cy + 126)
	opt.size = Vector2(280, 56)
	opt.pressed.connect(_on_options)
	add_child(opt)

	var ver := Label.new()
	ver.text = BUILD_TAG
	ver.add_theme_font_size_override("font_size", 13)
	ver.modulate = Color(0.55, 0.55, 0.62)
	ver.position = Vector2(cx - 400, vp.y - 28)
	ver.size = Vector2(800, 20)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(ver)

func _on_options() -> void:
	_unlock_audio()  # so volume changes are audible immediately
	add_child(SettingsPanel.new())

func _on_start() -> void:
	_unlock_audio()
	SceneRouter.goto_hub()

func _unlock_audio() -> void:
	# Touching the audio system within a user gesture satisfies the Web autoplay
	# policy. Safe no-op on native platforms.
	AudioServer.set_bus_mute(0, false)
