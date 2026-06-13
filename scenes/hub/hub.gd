extends Control
## The hub: return point between runs. Greybox for now — just launches a run.
## Meta-progression (reincarnation/karma) UI lands here in Phase 2.

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var title := Label.new()
	title.text = Loc.t("hub.title")
	title.add_theme_font_size_override("font_size", 40)
	title.position = Vector2(40, 40)
	add_child(title)

	var play := Button.new()
	play.text = Loc.t("ui.play")
	play.position = Vector2(40, 140)
	play.size = Vector2(260, 72)
	play.pressed.connect(_on_play)
	add_child(play)

	var daily := Button.new()
	daily.text = Loc.t("ui.daily")
	daily.position = Vector2(40, 230)
	daily.size = Vector2(260, 72)
	daily.pressed.connect(_on_daily)
	add_child(daily)

	# Show last run result if any.
	var runs := int(SaveManager.meta.get("runs_completed", 0))
	var stat := Label.new()
	stat.text = Loc.t("hub.runs", {"n": runs})
	stat.position = Vector2(40, 330)
	add_child(stat)

func _on_play() -> void:
	RunManager.start_run(randi(), "greece")
	SceneRouter.goto_run()

func _on_daily() -> void:
	# Deterministic daily seed from the date (local). Reproducible per day.
	var today := Time.get_date_string_from_system()
	RNG.seed_from_string("daily-" + today)
	RunManager.start_run(RNG.get_seed(), "greece")
	SceneRouter.goto_run()
