extends Control
## The hub: return point between runs. Choose a realm (pantheon) and seed, descend,
## resume an interrupted run, and spend karma on permanent reincarnation traits.

var _karma_label: Label
var _rows: Dictionary = {}        # upgrade id -> {name, level, buy, up}
var _biome_option: OptionButton
var _biome_ids: Array[String] = []
var _boss_test_option: OptionButton
var _boss_test_ids: Array[String] = []
var _char_option: OptionButton
var _char_ids: Array[String] = []
var _diff_buttons: Array = []
var _diff_index: int = 1
var _diff_ids: Array[String] = ["easy", "normal", "hard"]
var _outfit_buttons: Array = []
var _outfit_index: int = 0
var _outfit_hues: Array[float] = [0.0, 1.05, 2.09, 3.14, 4.19, 5.24]
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
	# Dark backdrop so the parchment panels read like a real menu screen.
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.07)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + s, 80)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	margin.add_child(v)

	var title := Label.new()
	title.text = Loc.t("hub.title")
	title.add_theme_font_size_override("font_size", 44)
	UITheme.title(title)
	v.add_child(title)

	# Info strip: karma · objective · souls guided.
	var info := HBoxContainer.new()
	info.add_theme_constant_override("separation", 28)
	v.add_child(info)
	_karma_label = Label.new()
	_karma_label.add_theme_font_size_override("font_size", 22)
	info.add_child(_karma_label)
	var objective := Label.new()
	objective.text = Loc.t("hub.objective", {"n": SaveManager.realms_cleared().size()})
	objective.modulate = Color(0.85, 0.8, 0.6)
	info.add_child(objective)
	var runs := Label.new()
	runs.text = Loc.t("hub.runs", {"n": int(SaveManager.meta.get("runs_completed", 0))})
	runs.modulate = Color(0.7, 0.7, 0.75)
	info.add_child(runs)
	var verdict_key: String = SaveManager.meta.get("last_verdict", "")
	if verdict_key != "":
		var verdict := Label.new()
		verdict.text = Loc.t("hub.last_verdict", {"v": Loc.t(verdict_key)})
		verdict.modulate = Color(0.7, 0.7, 0.75)
		info.add_child(verdict)

	# --- Panel 1: New Descent ---
	var dpanel := _card()
	v.add_child(dpanel)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 10)
	dpanel.add_child(dv)

	var descent_h := Label.new()
	descent_h.text = Loc.t("hub.new_descent")
	descent_h.add_theme_font_size_override("font_size", 26)
	descent_h.add_theme_color_override("font_color", Color(0.9, 0.76, 0.42))
	UITheme.title(descent_h)
	dv.add_child(descent_h)

	# Realm + seed selectors.
	var sel := HBoxContainer.new()
	sel.add_theme_constant_override("separation", 12)
	dv.add_child(sel)
	var realm_l := Label.new()
	realm_l.text = Loc.t("ui.realm")
	sel.add_child(realm_l)
	_biome_option = OptionButton.new()
	# The final realm (Cthulhu's) stays LOCKED until every OTHER realm is conquered.
	var _cleared := SaveManager.realms_cleared()
	var _others := 0
	var _others_done := 0
	for _b in GameData.biomes.values():
		if not _b.final:
			_others += 1
			if _b.id in _cleared:
				_others_done += 1
	var _final_unlocked := _others > 0 and _others_done >= _others
	for biome in GameData.biomes.values():
		_biome_ids.append(biome.id)
		if biome.final and not _final_unlocked:
			_biome_option.add_item(Loc.t("ui.realm_locked"))
			_biome_option.set_item_disabled(_biome_option.item_count - 1, true)
		else:
			_biome_option.add_item(Loc.t(biome.name_key))
	for _i in _biome_option.item_count:
		if not _biome_option.is_item_disabled(_i):
			_biome_option.select(_i)
			break
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
	_seed_edit.placeholder_text = "random"
	var ss := StyleBoxFlat.new()
	ss.bg_color = Color(0.05, 0.05, 0.08)
	ss.set_corner_radius_all(4)
	ss.set_border_width_all(1)
	ss.border_color = Color(0.5, 0.42, 0.24)
	ss.set_content_margin_all(6)
	_seed_edit.add_theme_stylebox_override("normal", ss)
	_seed_edit.add_theme_stylebox_override("focus", ss)
	sel.add_child(_seed_edit)

	# Character (starting kit) selector.
	var hero := HBoxContainer.new()
	hero.add_theme_constant_override("separation", 12)
	dv.add_child(hero)
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

	# Difficulty trial: Merciful / Ordeal / Damnation. Three big TOGGLE buttons
	# (reliable on touch, unlike a dropdown). Merciful greatly softens the swarm
	# (slower, weaker, fewer foes + a hardier hero) so newcomers survive.
	var diff := HBoxContainer.new()
	diff.add_theme_constant_override("separation", 10)
	dv.add_child(diff)
	var diff_l := Label.new()
	diff_l.text = Loc.t("ui.difficulty")
	diff.add_child(diff_l)
	_diff_buttons = []
	var diff_keys := ["ui.diff_easy", "ui.diff_normal", "ui.diff_hard"]
	for i in _diff_ids.size():
		var db := Button.new()
		db.toggle_mode = true
		db.text = Loc.t(diff_keys[i])
		db.custom_minimum_size = Vector2(178, 54)
		db.pressed.connect(_on_pick_difficulty.bind(i))
		diff.add_child(db)
		_diff_buttons.append(db)
	var saved_diff := String(SaveManager.meta.get("options", {}).get("difficulty", "normal"))
	_set_difficulty_index(maxi(0, _diff_ids.find(saved_diff)))

	# Robe colour: recolour the hero. Swatches (touch-friendly), saved between runs.
	var outfit := HBoxContainer.new()
	outfit.add_theme_constant_override("separation", 8)
	dv.add_child(outfit)
	var outfit_l := Label.new()
	outfit_l.text = Loc.t("ui.outfit")
	outfit.add_child(outfit_l)
	_outfit_buttons = []
	var saved_hue := float(SaveManager.meta.get("options", {}).get("player_hue", 0.0))
	for i in _outfit_hues.size():
		var ob := Button.new()
		ob.custom_minimum_size = Vector2(46, 46)
		var sb := StyleBoxFlat.new()
		sb.bg_color = _hue_rotate_color(Color(0.42, 0.6, 1.0), _outfit_hues[i])
		sb.set_corner_radius_all(6)
		sb.set_border_width_all(3)
		sb.border_color = Color(0, 0, 0, 0)
		ob.add_theme_stylebox_override("normal", sb)
		ob.add_theme_stylebox_override("hover", sb)
		ob.add_theme_stylebox_override("pressed", sb)
		ob.pressed.connect(_on_pick_outfit.bind(i))
		outfit.add_child(ob)
		_outfit_buttons.append(ob)
	var start_idx := 0
	for i in _outfit_hues.size():
		if is_equal_approx(_outfit_hues[i], saved_hue):
			start_idx = i
	_set_outfit_index(start_idx)

	# --- Hidden DEV: boss test — pick any boss and fight it directly in its arena. ---
	if RunManager.DEBUG_BOSS_TEST:
		var bt := HBoxContainer.new()
		bt.add_theme_constant_override("separation", 12)
		dv.add_child(bt)
		var bt_l := Label.new()
		bt_l.text = "Boss test"
		bt_l.modulate = Color(0.95, 0.5, 0.5)
		bt.add_child(bt_l)
		_boss_test_option = OptionButton.new()
		for ent in GameData.entities.values():
			if ent.role == "boss" or ent.role == "miniboss":
				_boss_test_ids.append(ent.id)
				_boss_test_option.add_item(Loc.t(ent.name_key))
		if _boss_test_option.item_count > 0:
			_boss_test_option.select(0)
		bt.add_child(_boss_test_option)
		bt.add_child(_make_button("⚔ TEST BOSS", _on_test_boss))

	# Action buttons.
	# HFlow so the buttons wrap to a new line on narrow (phone) screens instead
	# of pushing Options/Resume off the edge.
	var buttons := HFlowContainer.new()
	buttons.add_theme_constant_override("h_separation", 12)
	buttons.add_theme_constant_override("v_separation", 10)
	dv.add_child(buttons)
	buttons.add_child(_make_button(Loc.t("ui.play"), _on_play))
	buttons.add_child(_make_button(Loc.t("ui.daily"), _on_daily))
	buttons.add_child(_make_button(Loc.t("ui.codex_btn"), _on_codex))
	buttons.add_child(_make_button(Loc.t("ui.options"), _on_options))
	if SaveManager.has_run():
		buttons.add_child(_make_button(Loc.t("ui.resume"), _on_resume))

	# --- Panel 2: Reincarnation (permanent upgrades) ---
	var mpanel := _card()
	v.add_child(mpanel)
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 8)
	mpanel.add_child(mv)

	var header := Label.new()
	header.text = Loc.t("hub.reincarnation")
	header.add_theme_font_size_override("font_size", 26)
	header.add_theme_color_override("font_color", Color(0.9, 0.76, 0.42))
	UITheme.title(header)
	mv.add_child(header)

	for up in GameData.meta_upgrades.values():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		mv.add_child(row)
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

	_refresh()

## A clean, opaque dark "card" panel with a gold border — crisper for large hub
## sections than stretching the small textured panel (which goes murky).
func _card() -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.09, 0.13, 0.98)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.55, 0.45, 0.24)
	sb.set_content_margin_all(18)
	pc.add_theme_stylebox_override("panel", sb)
	return pc

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

func _selected_difficulty() -> String:
	return _diff_ids[_diff_index] if _diff_index >= 0 and _diff_index < _diff_ids.size() else "normal"

func _on_pick_difficulty(i: int) -> void:
	_set_difficulty_index(i)

func _set_difficulty_index(i: int) -> void:
	_diff_index = clampi(i, 0, _diff_ids.size() - 1)
	for j in _diff_buttons.size():
		_diff_buttons[j].button_pressed = (j == _diff_index)

func _on_pick_outfit(i: int) -> void:
	_set_outfit_index(i)
	if not SaveManager.meta.has("options"):
		SaveManager.meta["options"] = {}
	SaveManager.meta["options"]["player_hue"] = _outfit_hues[_outfit_index]
	SaveManager.save_meta()

## Highlight the chosen swatch with a gold border, others borderless.
func _set_outfit_index(i: int) -> void:
	_outfit_index = clampi(i, 0, _outfit_hues.size() - 1)
	for j in _outfit_buttons.size():
		var sb: StyleBoxFlat = _outfit_buttons[j].get_theme_stylebox("normal")
		sb.border_color = Color(1.0, 0.9, 0.55) if j == _outfit_index else Color(0, 0, 0, 0)
	queue_redraw()

## Rotate a colour around the grey axis (matches the in-game outfit shader) so the
## swatch previews the actual robe colour.
func _hue_rotate_color(c: Color, a: float) -> Color:
	var k := Vector3(0.57735, 0.57735, 0.57735)
	var v := Vector3(c.r, c.g, c.b)
	var ca := cos(a)
	var rot := v * ca + k.cross(v) * sin(a) + k * k.dot(v) * (1.0 - ca)
	return Color(clampf(rot.x, 0.0, 1.0), clampf(rot.y, 0.0, 1.0), clampf(rot.z, 0.0, 1.0), 1.0)

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
	RunManager.start_run(_selected_seed(), _selected_biome(), _selected_character(), _selected_difficulty())
	SceneRouter.goto_run()

func _on_daily() -> void:
	RNG.seed_from_string("daily-" + Time.get_date_string_from_system())
	RunManager.start_run(RNG.get_seed(), _selected_biome(), _selected_character(), _selected_difficulty())
	SceneRouter.goto_run()

func _on_codex() -> void:
	add_child(Codex.new())

func _on_options() -> void:
	add_child(SettingsPanel.new())

func _on_resume() -> void:
	var snap := SaveManager.load_run()
	if snap.is_empty():
		return
	RunManager.from_snapshot(snap)
	SceneRouter.goto_run()

## Hidden DEV: launch a one-room arena against the chosen boss.
func _on_test_boss() -> void:
	if _boss_test_option == null:
		return
	var idx := _boss_test_option.selected
	if idx < 0 or idx >= _boss_test_ids.size():
		return
	var bid := _boss_test_ids[idx]
	var bbiome := RunManager.biome_for_boss(bid)
	RunManager.start_run(_selected_seed(), bbiome, _selected_character())
	RunManager.debug_boss_test = bid
	SceneRouter.goto_run()
