class_name PauseMenu
extends CanvasLayer
## On-screen pause button + options overlay. Mobile-first: exposes auto-aim and
## auto-fire toggles (crucial on touch) and an Abandon option. Works while the
## tree is paused (process_mode ALWAYS). Esc also toggles it on desktop.

var _panel: Control

func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS

	var pause_btn := Button.new()
	pause_btn.text = "II"
	pause_btn.anchor_left = 1.0
	pause_btn.anchor_right = 1.0
	pause_btn.offset_left = -88
	pause_btn.offset_top = 18
	pause_btn.offset_right = -20
	pause_btn.offset_bottom = 66
	pause_btn.pressed.connect(_toggle)
	add_child(pause_btn)

	_build_panel()
	_panel.visible = false

func _build_panel() -> void:
	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(dim)

	# Centered card so the options sit on a defined panel (consistent with the hub).
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(center)
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.09, 0.13, 0.98)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.55, 0.45, 0.24)
	sb.set_content_margin_all(22)
	card.add_theme_stylebox_override("panel", sb)
	center.add_child(card)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(360, 0)
	box.add_theme_constant_override("separation", 16)
	card.add_child(box)

	var title := Label.new()
	title.text = Loc.t("ui.paused")
	title.add_theme_font_size_override("font_size", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.title(title)
	box.add_child(title)

	var aim := CheckButton.new()
	aim.text = Loc.t("ui.auto_aim")
	aim.custom_minimum_size = Vector2(360, 56)
	aim.set_pressed_no_signal(GameInput.auto_aim)
	aim.toggled.connect(func(v): GameInput.set_auto_aim(v))
	box.add_child(aim)

	var fire := CheckButton.new()
	fire.text = Loc.t("ui.auto_fire")
	fire.custom_minimum_size = Vector2(360, 56)
	fire.set_pressed_no_signal(GameInput.auto_fire)
	fire.toggled.connect(func(v): GameInput.set_auto_fire(v))
	box.add_child(fire)

	box.add_child(_volume_row(Loc.t("ui.music"), Audio.music_volume(),
		func(v): Audio.set_music_volume(v)))
	box.add_child(_volume_row(Loc.t("ui.sfx"), Audio.sfx_volume(),
		func(v): Audio.set_sfx_volume(v)))

	var resume := Button.new()
	resume.text = Loc.t("ui.resume")
	resume.custom_minimum_size = Vector2(360, 60)
	resume.pressed.connect(_toggle)
	box.add_child(resume)

	var abandon := Button.new()
	abandon.text = Loc.t("ui.abandon")
	abandon.custom_minimum_size = Vector2(360, 60)
	abandon.pressed.connect(_abandon)
	box.add_child(abandon)

## A labelled volume slider row.
func _volume_row(label: String, value: float, on_change: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(120, 0)
	row.add_child(l)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(220, 40)
	slider.value_changed.connect(on_change)
	row.add_child(slider)
	return row

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle()

func _toggle() -> void:
	var paused := not get_tree().paused
	get_tree().paused = paused
	_panel.visible = paused

func _abandon() -> void:
	get_tree().paused = false
	RunManager.end_run(false)
	SceneRouter.goto_hub()
