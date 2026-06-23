class_name DeathScreen
extends CanvasLayer
## The death beat: the screen darkens, a Cinzel epitaph fades up with the run's
## tally, and a tap returns the soul to the shore (the hub). Pauses the game so
## the fallen run freezes behind it. Presentation only.

signal continued

var _t := 0.0
var _prompt: Label
var _veil: ColorRect
var _card: Control

func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true

	_veil = ColorRect.new()
	_veil.color = Color(0.02, 0.02, 0.04, 0.0)
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)

	_card = VBoxContainer.new()
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.alignment = BoxContainer.ALIGNMENT_CENTER
	_card.add_theme_constant_override("separation", 18)
	_card.modulate.a = 0.0
	add_child(_card)

	var title := Label.new()
	title.text = Loc.t("death.title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 76)
	title.add_theme_color_override("font_color", Color(0.74, 0.16, 0.16))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	title.add_theme_constant_override("outline_size", 8)
	UITheme.title(title)
	_card.add_child(title)

	var epitaph := Label.new()
	epitaph.text = Loc.t("death.epitaph")
	epitaph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	epitaph.add_theme_font_size_override("font_size", 22)
	epitaph.add_theme_color_override("font_color", Color(0.82, 0.80, 0.74))
	epitaph.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	epitaph.add_theme_constant_override("outline_size", 4)
	_card.add_child(epitaph)

	var stats := Label.new()
	stats.text = _summary()
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size", 18)
	stats.add_theme_color_override("font_color", Color(0.85, 0.72, 0.38))
	stats.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	stats.add_theme_constant_override("outline_size", 4)
	_card.add_child(stats)

	_prompt = Label.new()
	_prompt.text = Loc.t("death.continue")
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 18)
	_prompt.add_theme_color_override("font_color", Color(0.78, 0.78, 0.82))
	_card.add_child(_prompt)

	Audio.play_sfx("death", 0.7)

func _summary() -> String:
	var realm := ""
	var b = GameData.get_biome(RunManager.biome_id)
	if b != null:
		realm = Loc.t(b.name_key)
	var rooms: int = RunManager.rooms_cleared_count
	return "%s — %s\n%s: %d" % [Loc.t("death.fell_in"), realm, Loc.t("death.rooms"), rooms]

func _process(delta: float) -> void:
	_t += delta
	# Veil + card fade up over the first ~0.6s.
	var f: float = clampf(_t / 0.6, 0.0, 1.0)
	_veil.color.a = f * 0.82
	_card.modulate.a = f
	# Blink the prompt once the card has settled.
	if _prompt != null:
		_prompt.modulate.a = 0.35 + 0.65 * (0.5 + 0.5 * sin(_t * 3.0)) if _t > 0.6 else 0.0

func _unhandled_input(event: InputEvent) -> void:
	if _t < 0.5:
		return  # ignore the input that may have overlapped death
	var pressed: bool = event.is_action_pressed("ui_accept") \
		or (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed)
	if pressed:
		get_viewport().set_input_as_handled()
		_close()

func _close() -> void:
	get_tree().paused = false
	continued.emit()
	queue_free()
