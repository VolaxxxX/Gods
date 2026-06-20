extends Control
## The hub: return point between runs. Choose a realm (pantheon) and seed, descend,
## resume an interrupted run, and spend karma on permanent reincarnation traits.

var _karma_label: Label
var _rows: Dictionary = {}        # upgrade id -> {name, level, buy, up}
var _biome_option: OptionButton
var _biome_ids: Array[String] = []
var _char_option: OptionButton
var _char_ids: Array[String] = []
var _hero_desc: Label
var _realm_teaser: Label
var _seed_edit: LineEdit

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	Events.karma_changed.connect(func(_k): _refresh())
	# Story / death / victory / ambient line (evolves with progress).
	Dialogue.on_enter_hub()

func _build() -> void:
	var v := VBoxContainer.new()
	v.position = Vector2(40, 28)
	v.custom_minimum_size = Vector2(700, 0)
	v.add_theme_constant_override("separation", 10)
	add_child(v)

	var title := Label.new()
	title.text = Loc.t("hub.title")
	title.add_theme_font_size_override("font_size", 40)
	v.add_child(title)

	_karma_label = Label.new()
	_karma_label.add_theme_font_size_override("font_size", 22)
	v.add_child(_karma_label)

	var objective := Label.new()
	objective.text = Loc.t("hub.objective", {"n": SaveManager.realms_cleared().size()})
	objective.modulate = Color(0.85, 0.8, 0.6)
	v.add_child(objective)

	var descent_h := Label.new()
	descent_h.text = Loc.t("hub.new_descent")
	descent_h.add_theme_font_size_override("font_size", 26)
	v.add_child(descent_h)

	# Realm + seed selectors.
	var sel := HBoxContainer.new()
	sel.add_theme_constant_override("separation", 12)
	v.add_child(sel)
	var realm_l := Label.new()
	realm_l.text = Loc.t("ui.realm")
	sel.add_child(realm_l)
	_biome_option = OptionButton.new()
	for biome in GameData.biomes.values():
		_biome_ids.append(biome.id)
		_biome_option.add_item(Loc.t(biome.name_key))
	if _biome_option.item_count > 0:
		_biome_option.select(0)
	_biome_option.item_selected.connect(func(_i): _refresh_realm_teaser())
	sel.add_child(_biome_option)
	_realm_teaser = Label.new()
	_realm_teaser.modulate = Color(0.8, 0.8, 0.85)
	sel.add_child(_realm_teaser)
	_refresh_realm_teaser()
	var seed_l := Label.new()
	seed_l.text = Loc.t("ui.seed")
	sel.add_child(seed_l)
	_seed_edit = LineEdit.new()
	_seed_edit.custom_minimum_size = Vector2(180, 0)
	sel.add_child(_seed_edit)

	# Character (starting kit) selector.
	var hero := HBoxContainer.new()
	hero.add_theme_constant_override("separation", 12)
	v.add_child(hero)
	var hero_l := Label.new()
	hero_l.text = Loc.t("ui.character")
	hero.add_child(hero_l)
	_char_option = OptionButton.new()
	for ch in GameData.characters.values():
		_char_ids.append(ch.id)
		_char_option.add_item(Loc.t(ch.name_key))
	if _char_option.item_count > 0:
		_char_option.select(0)
	_char_option.item_selected.connect(func(_i): _refresh_hero_desc())
	hero.add_child(_char_option)
	_hero_desc = Label.new()
	hero.add_child(_hero_desc)
	_refresh_hero_desc()

	# Action buttons.
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	v.add_child(buttons)
	buttons.add_child(_make_button(Loc.t("ui.play"), _on_play))
	buttons.add_child(_make_button(Loc.t("ui.daily"), _on_daily))
	if SaveManager.has_run():
		buttons.add_child(_make_button(Loc.t("ui.resume"), _on_resume))

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
		buy.custom_minimum_size = Vector2(200, 44)
		buy.pressed.connect(_on_buy.bind(up.id))
		row.add_child(buy)
		_rows[up.id] = {"name": name_l, "level": level_l, "buy": buy, "up": up}

	var runs := Label.new()
	runs.text = Loc.t("hub.runs", {"n": int(SaveManager.meta.get("runs_completed", 0))})
	v.add_child(runs)

	var verdict_key: String = SaveManager.meta.get("last_verdict", "")
	if verdict_key != "":
		var verdict := Label.new()
		verdict.text = Loc.t("hub.last_verdict", {"v": Loc.t(verdict_key)})
		v.add_child(verdict)

	_refresh()

func _make_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(200, 60)
	b.pressed.connect(cb)
	return b

func _refresh() -> void:
	_karma_label.text = Loc.t("hub.karma", {"n": SaveManager.get_karma()})
	for id in _rows:
		var r: Dictionary = _rows[id]
		var up: MetaUpgradeData = r["up"]
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
	var up: MetaUpgradeData = GameData.meta_upgrades.get(id, null)
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

func _selected_biome() -> String:
	var idx := _biome_option.selected
	if idx >= 0 and idx < _biome_ids.size():
		return _biome_ids[idx]
	return "greece"

func _selected_character() -> String:
	var idx := _char_option.selected
	if idx >= 0 and idx < _char_ids.size():
		return _char_ids[idx]
	return "char_wanderer"

func _refresh_hero_desc() -> void:
	var id := _selected_character()
	var ch = GameData.characters.get(id, null)
	_hero_desc.text = Loc.t(ch.desc_key) if ch != null else ""

func _refresh_realm_teaser() -> void:
	var biome := GameData.get_biome(_selected_biome())
	if biome == null:
		_realm_teaser.text = ""
		return
	var boss := GameData.get_entity(biome.boss_id)
	var boss_name := Loc.t(boss.name_key) if boss != null else "?"
	_realm_teaser.text = Loc.t("hub.realm_guarded", {"boss": boss_name})

func _selected_seed() -> int:
	var t := _seed_edit.text.strip_edges()
	if t == "":
		return randi()
	if t.is_valid_int():
		return int(t)
	return int(hash(t))

func _on_play() -> void:
	RunManager.start_run(_selected_seed(), _selected_biome(), _selected_character())
	SceneRouter.goto_run()

func _on_daily() -> void:
	RNG.seed_from_string("daily-" + Time.get_date_string_from_system())
	RunManager.start_run(RNG.get_seed(), _selected_biome(), _selected_character())
	SceneRouter.goto_run()

func _on_resume() -> void:
	var snap := SaveManager.load_run()
	if snap.is_empty():
		return
	RunManager.from_snapshot(snap)
	SceneRouter.goto_run()
