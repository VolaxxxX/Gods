extends Control
## The hub: return point between runs. Hosts reincarnation — spend karma earned
## from past runs on permanent traits (meta-progression). Greybox UI.

var _karma_label: Label
var _rows: Dictionary = {}  # upgrade id -> {name, level, buy, up}

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	Events.karma_changed.connect(func(_k): _refresh())

func _build() -> void:
	var v := VBoxContainer.new()
	v.position = Vector2(40, 32)
	v.custom_minimum_size = Vector2(680, 0)
	v.add_theme_constant_override("separation", 10)
	add_child(v)

	var title := Label.new()
	title.text = Loc.t("hub.title")
	title.add_theme_font_size_override("font_size", 40)
	v.add_child(title)

	_karma_label = Label.new()
	_karma_label.add_theme_font_size_override("font_size", 22)
	v.add_child(_karma_label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	v.add_child(buttons)
	var play := Button.new()
	play.text = Loc.t("ui.play")
	play.custom_minimum_size = Vector2(220, 64)
	play.pressed.connect(_on_play)
	buttons.add_child(play)
	var daily := Button.new()
	daily.text = Loc.t("ui.daily")
	daily.custom_minimum_size = Vector2(220, 64)
	daily.pressed.connect(_on_daily)
	buttons.add_child(daily)

	var header := Label.new()
	header.text = Loc.t("hub.reincarnation")
	header.add_theme_font_size_override("font_size", 26)
	v.add_child(header)

	for up in GameData.meta_upgrades.values():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		v.add_child(row)

		var name_l := Label.new()
		name_l.custom_minimum_size = Vector2(220, 0)
		name_l.tooltip_text = Loc.t(up.desc_key)
		row.add_child(name_l)

		var level_l := Label.new()
		level_l.custom_minimum_size = Vector2(120, 0)
		row.add_child(level_l)

		var buy := Button.new()
		buy.custom_minimum_size = Vector2(180, 48)
		buy.pressed.connect(_on_buy.bind(up.id))
		row.add_child(buy)

		_rows[up.id] = {"name": name_l, "level": level_l, "buy": buy, "up": up}

	var runs := Label.new()
	runs.text = Loc.t("hub.runs", {"n": int(SaveManager.meta.get("runs_completed", 0))})
	v.add_child(runs)

	_refresh()

func _refresh() -> void:
	_karma_label.text = Loc.t("hub.karma", {"n": SaveManager.get_karma()})
	for id in _rows:
		var r: Dictionary = _rows[id]
		var up = r["up"]
		var level := SaveManager.upgrade_level(id)
		r["name"].text = Loc.t(up.name_key)
		if level >= up.max_level:
			r["level"].text = Loc.t("meta.level_max")
			r["buy"].text = "—"
			r["buy"].disabled = true
		else:
			var cost := up.cost_for_level(level)
			r["level"].text = Loc.t("meta.level", {"lvl": level, "max": up.max_level})
			r["buy"].text = Loc.t("meta.buy", {"c": cost})
			r["buy"].disabled = SaveManager.get_karma() < cost

func _on_buy(id: String) -> void:
	var up = GameData.meta_upgrades.get(id, null)
	if up == null:
		return
	var level := SaveManager.upgrade_level(id)
	if level >= up.max_level:
		return
	var cost := up.cost_for_level(level)
	if SaveManager.get_karma() < cost:
		return
	SaveManager.add_karma(-cost)
	SaveManager.set_upgrade_level(id, level + 1)
	SaveManager.save_meta()
	_refresh()

func _on_play() -> void:
	RunManager.start_run(randi(), "greece")
	SceneRouter.goto_run()

func _on_daily() -> void:
	var today := Time.get_date_string_from_system()
	RNG.seed_from_string("daily-" + today)
	RunManager.start_run(RNG.get_seed(), "greece")
	SceneRouter.goto_run()
