extends Control
## Boot/splash. Also serves as the Web audio-unlock gate: browsers block audio
## until a user gesture, so we require one tap before entering the game.

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

	var title := Label.new()
	title.text = Loc.t("game.title")
	title.add_theme_font_size_override("font_size", 96)
	title.add_theme_color_override("font_color", Color(0.9, 0.78, 0.42))
	title.set_anchors_preset(Control.PRESET_CENTER)
	title.position = Vector2(-300, -120)
	title.size = Vector2(600, 110)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.title(title)
	add_child(title)

	var tagline := Label.new()
	tagline.text = Loc.t("game.tagline")
	tagline.add_theme_font_size_override("font_size", 22)
	tagline.modulate = Color(0.75, 0.75, 0.82)
	tagline.set_anchors_preset(Control.PRESET_CENTER)
	tagline.position = Vector2(-300, -16)
	tagline.size = Vector2(600, 30)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(tagline)

	var btn := Button.new()
	btn.text = Loc.t("ui.tap_to_start")
	btn.set_anchors_preset(Control.PRESET_CENTER)
	btn.position = Vector2(-140, 60)
	btn.size = Vector2(280, 64)
	btn.pressed.connect(_on_start)
	add_child(btn)

func _on_start() -> void:
	_unlock_audio()
	SceneRouter.goto_hub()

func _unlock_audio() -> void:
	# Touching the audio system within a user gesture satisfies the Web autoplay
	# policy. Safe no-op on native platforms.
	AudioServer.set_bus_mute(0, false)
