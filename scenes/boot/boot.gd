extends Control
## Boot/splash. Also serves as the Web audio-unlock gate: browsers block audio
## until a user gesture, so we require one tap before entering the game.

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var title := Label.new()
	title.text = Loc.t("game.title")
	title.add_theme_font_size_override("font_size", 64)
	title.set_anchors_preset(Control.PRESET_CENTER)
	title.position = Vector2(-200, -80)
	title.size = Vector2(400, 80)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var btn := Button.new()
	btn.text = Loc.t("ui.tap_to_start")
	btn.set_anchors_preset(Control.PRESET_CENTER)
	btn.position = Vector2(-140, 30)
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
