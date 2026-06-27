class_name SettingsPanel
extends CanvasLayer
## Standalone Options overlay (Music + Sound volume, auto-aim, auto-fire) usable
## from the hub's Options button. Touch-friendly sliders. Frees itself on close.

func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.09, 0.13, 0.98)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.55, 0.45, 0.24)
	sb.set_content_margin_all(24)
	card.add_theme_stylebox_override("panel", sb)
	center.add_child(card)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(420, 0)
	box.add_theme_constant_override("separation", 18)
	card.add_child(box)

	var title := Label.new()
	title.text = Loc.t("ui.options")
	title.add_theme_font_size_override("font_size", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.title(title)
	box.add_child(title)

	box.add_child(_volume_row(Loc.t("ui.music"), Audio.music_volume(),
		func(v): Audio.set_music_volume(v)))
	box.add_child(_volume_row(Loc.t("ui.sfx"), Audio.sfx_volume(),
		func(v): Audio.set_sfx_volume(v)))

	var aim := CheckButton.new()
	aim.text = Loc.t("ui.auto_aim")
	aim.custom_minimum_size = Vector2(420, 56)
	aim.set_pressed_no_signal(GameInput.auto_aim)
	aim.toggled.connect(func(v): GameInput.set_auto_aim(v))
	box.add_child(aim)

	var fire := CheckButton.new()
	fire.text = Loc.t("ui.auto_fire")
	fire.custom_minimum_size = Vector2(420, 56)
	fire.set_pressed_no_signal(GameInput.auto_fire)
	fire.toggled.connect(func(v): GameInput.set_auto_fire(v))
	box.add_child(fire)

	var close := Button.new()
	close.text = Loc.t("ui.close")
	close.custom_minimum_size = Vector2(420, 60)
	close.pressed.connect(queue_free)
	box.add_child(close)

## A labelled, touch-friendly volume slider row with a live percentage.
func _volume_row(label: String, value: float, on_change: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(120, 0)
	l.add_theme_font_size_override("font_size", 22)
	row.add_child(l)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(230, 52)  # tall = easy to drag on touch
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var pct := Label.new()
	pct.text = "%d%%" % int(round(value * 100.0))
	pct.custom_minimum_size = Vector2(54, 0)
	pct.add_theme_font_size_override("font_size", 20)
	row.add_child(pct)
	slider.value_changed.connect(func(v):
		pct.text = "%d%%" % int(round(v * 100.0))
		on_change.call(v))
	return row
