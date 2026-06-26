class_name HUD
extends CanvasLayer
## Greybox+themed HUD: realm name, a graphical health bar, gold, and a realm
## banner. Presentation only — reads via the Events bus. Styled by the global
## UITheme; a coin icon appears if assets/sprites/ui/coin.png exists.
## (No mana bar: the game has no mana resource.)

const COIN := "res://assets/sprites/ui/coin.png"

var _biome_label: Label
var _hp_bar: ProgressBar
var _hp_text: Label
var _gold_label: Label
var _banner: Label
var _banner_t: float = 0.0
var _boss_box: VBoxContainer
var _boss_plate: Control
var _boss_name: Label
var _boss_bar: ProgressBar
var _boss: Node      # the tracked boss/miniboss (its HealthComponent drives the bar)
var _boss_target: float = 1.0   # target fill; the bar eases toward it (juice)
var player: Node                # set by the run scene, for the dash indicator
var _dash_bar: ProgressBar
var _vignette: Control
var _items_row: HFlowContainer
var _t: float = 0.0
var _hp_frac: float = 1.0
var _danger: float = 0.0        # eased low-HP vignette intensity

func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_biome_label = Label.new()
	_biome_label.position = Vector2(24, 16)
	_biome_label.add_theme_font_size_override("font_size", 24)
	_biome_label.add_theme_color_override("font_color", Color(0.95, 0.84, 0.5))
	_outline(_biome_label, 5)
	UITheme.title(_biome_label)
	root.add_child(_biome_label)

	# Graphical health bar (320x26) with the value drawn on top.
	_hp_bar = ProgressBar.new()
	_hp_bar.position = Vector2(24, 50)
	_hp_bar.custom_minimum_size = Vector2(320, 26)
	_hp_bar.size = Vector2(320, 26)
	_hp_bar.show_percentage = false
	_hp_bar.min_value = 0.0
	root.add_child(_hp_bar)
	_hp_text = Label.new()
	_hp_text.size = Vector2(320, 26)
	_hp_text.position = Vector2(24, 50)
	_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hp_text.add_theme_font_size_override("font_size", 16)
	_outline(_hp_text, 4)
	root.add_child(_hp_text)

	# Gold (optional coin icon + amount).
	var gold_row := HBoxContainer.new()
	gold_row.position = Vector2(24, 86)
	root.add_child(gold_row)
	if ResourceLoader.exists(COIN):
		var coin := TextureRect.new()
		coin.texture = load(COIN)
		coin.custom_minimum_size = Vector2(24, 24)
		coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		gold_row.add_child(coin)
	_gold_label = Label.new()
	_gold_label.add_theme_font_size_override("font_size", 22)
	_gold_label.add_theme_color_override("font_color", Color(0.96, 0.88, 0.6))
	_outline(_gold_label, 4)
	gold_row.add_child(_gold_label)

	# Dash indicator: a slim bar that fills as the dash comes off cooldown (gold
	# when ready). Sits just under the gold row.
	_dash_bar = ProgressBar.new()
	_dash_bar.position = Vector2(24, 120)
	_dash_bar.custom_minimum_size = Vector2(120, 8)
	_dash_bar.size = Vector2(120, 8)
	_dash_bar.show_percentage = false
	_dash_bar.min_value = 0.0
	_dash_bar.max_value = 1.0
	_dash_bar.value = 1.0
	var dfill := StyleBoxFlat.new()
	dfill.bg_color = Color(0.55, 0.85, 0.95)
	dfill.set_corner_radius_all(3)
	_dash_bar.add_theme_stylebox_override("fill", dfill)
	root.add_child(_dash_bar)
	var dash_l := Label.new()
	dash_l.position = Vector2(150, 112)
	dash_l.text = Loc.t("hud.dash")
	dash_l.add_theme_font_size_override("font_size", 14)
	dash_l.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))
	_outline(dash_l, 3)
	root.add_child(dash_l)

	# Owned build at a glance: a wrapping row of boon icons + item chips.
	_items_row = HFlowContainer.new()
	_items_row.position = Vector2(24, 140)
	_items_row.custom_minimum_size = Vector2(320, 0)
	_items_row.add_theme_constant_override("h_separation", 4)
	_items_row.add_theme_constant_override("v_separation", 4)
	root.add_child(_items_row)

	# Low-HP danger vignette (red, pulses) — drawn at the screen edges.
	_vignette = Control.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.draw.connect(_draw_vignette)
	root.add_child(_vignette)

	# Big centered realm banner, shown briefly on entering a zone.
	_banner = Label.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.position = Vector2(-400, 90)
	_banner.size = Vector2(800, 60)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 46)
	_banner.add_theme_color_override("font_color", Color(0.97, 0.9, 0.7))
	_outline(_banner, 6)
	_banner.modulate.a = 0.0
	UITheme.title(_banner)
	root.add_child(_banner)

	# Boss health bar — a wide crimson bar with the boss name on a dark plate,
	# pinned to the top centre, shown only while a boss/miniboss lives.
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(0.04, 0.04, 0.06, 0.72)
	plate.set_corner_radius_all(6)
	plate.set_content_margin_all(8)
	var plate_wrap := PanelContainer.new()
	plate_wrap.set_anchors_preset(Control.PRESET_CENTER_TOP)
	plate_wrap.position = Vector2(-318, 10)
	plate_wrap.add_theme_stylebox_override("panel", plate)
	plate_wrap.visible = false
	root.add_child(plate_wrap)
	_boss_box = VBoxContainer.new()
	_boss_box.custom_minimum_size = Vector2(620, 0)
	_boss_box.add_theme_constant_override("separation", 4)
	plate_wrap.add_child(_boss_box)
	_boss_plate = plate_wrap
	_boss_name = Label.new()
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name.add_theme_font_size_override("font_size", 26)
	_boss_name.add_theme_color_override("font_color", Color(1.0, 0.78, 0.5))
	_outline(_boss_name, 5)
	UITheme.title(_boss_name)
	_boss_box.add_child(_boss_name)
	_boss_bar = ProgressBar.new()
	_boss_bar.custom_minimum_size = Vector2(600, 18)
	_boss_bar.show_percentage = false
	_boss_bar.min_value = 0.0
	_boss_bar.max_value = 1.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.75, 0.16, 0.18)
	fill.set_corner_radius_all(3)
	_boss_bar.add_theme_stylebox_override("fill", fill)
	_boss_box.add_child(_boss_bar)

	Events.boss_spawned.connect(_on_boss_spawned)
	Events.boss_despawned.connect(_on_boss_despawned)
	Events.player_health_changed.connect(_on_health)
	Events.gold_changed.connect(_on_gold)
	Events.biome_changed.connect(func(_id): _refresh_biome(); _show_banner())
	Events.item_picked_up.connect(func(_id): _refresh_build())
	Events.blessing_chosen.connect(func(_id): _refresh_build())
	_refresh_biome()
	_show_banner()
	_on_health(RunManager.player_health, RunManager.player_max_health)
	_on_gold(RunManager.gold)
	_refresh_build()

func _process(delta: float) -> void:
	_t += delta
	if _banner_t > 0.0:
		_banner_t -= delta
		_banner.modulate.a = clampf(_banner_t, 0.0, 1.0)
	# Dash indicator: fill = readiness; gold + brighter the instant it's ready.
	if is_instance_valid(player):
		var df: float = player.dash_ready_fraction()
		_dash_bar.value = df
		_dash_bar.modulate = Color(1, 0.85, 0.4) if df >= 1.0 else Color(0.7, 0.7, 0.75)
	# Low-HP danger vignette: ease intensity in/out and pulse.
	var target := clampf((0.34 - _hp_frac) / 0.34, 0.0, 1.0) if _hp_frac < 0.34 else 0.0
	_danger = lerpf(_danger, target, clampf(delta * 4.0, 0.0, 1.0))
	if _vignette != null:
		_vignette.queue_redraw()
	# Track the boss's health each frame; the bar eases toward it and the plate
	# fades in (juice). Its bar lives on the boss's own HealthComponent.
	if _boss_plate.visible:
		if is_instance_valid(_boss) and _boss.health != null:
			_boss_target = _boss.health.fraction()
		else:
			_boss_plate.visible = false
		_boss_bar.value = lerpf(_boss_bar.value, _boss_target, clampf(delta * 8.0, 0.0, 1.0))
		_boss_plate.modulate.a = minf(1.0, _boss_plate.modulate.a + delta * 4.0)

func _on_boss_spawned(entity, name_key: String) -> void:
	_boss = entity
	_boss_name.text = Loc.t(name_key)
	_boss_target = 1.0
	_boss_bar.value = 1.0
	_boss_plate.modulate.a = 0.0   # fade in
	_boss_plate.visible = true
	_banner_t = 0.0                # don't let the realm banner overlap the boss bar

func _on_boss_despawned() -> void:
	_boss = null
	_boss_plate.visible = false

func _show_banner() -> void:
	_banner.text = _biome_label.text
	_banner_t = 2.5

func _refresh_biome() -> void:
	var biome := GameData.get_biome(RunManager.biome_id)
	var name_key := biome.name_key if biome else "biome.unknown"
	_biome_label.text = Loc.t(name_key)

func _on_health(current: float, maximum: float) -> void:
	_hp_bar.max_value = maxf(1.0, maximum)
	_hp_bar.value = current
	_hp_text.text = Loc.t("hud.health", {"cur": int(ceil(current)), "max": int(maximum)})
	_hp_frac = current / maxf(1.0, maximum)

## Red danger vignette at the screen edges; intensifies + pulses as HP drops low.
func _draw_vignette() -> void:
	if _danger <= 0.02:
		return
	var vp := _vignette.get_viewport_rect().size
	var pulse := 0.6 + 0.4 * sin(_t * 6.5)
	var a := _danger * pulse
	for i in 7:
		var inset := i * 16.0
		var alpha := a * (1.0 - float(i) / 7.0) * 0.5
		_vignette.draw_rect(Rect2(inset, inset, vp.x - 2 * inset, vp.y - 2 * inset),
			Color(0.75, 0.06, 0.06, alpha), false, 16.0)

func _on_gold(total: int) -> void:
	_gold_label.text = Loc.t("hud.gold", {"n": total})

## Rebuild the owned-build row: a boon icon per blessing, a coloured chip per
## relic (relics have no art yet). Tooltips name each one.
func _refresh_build() -> void:
	if _items_row == null:
		return
	for c in _items_row.get_children():
		c.queue_free()
	for bid in RunManager.chosen_blessings:
		var b = GameData.blessings.get(bid, null)
		var accent := Color(0.85, 0.72, 0.38)
		if b != null:
			var dd = GameData.deities.get(b.deity_id, null)
			if dd != null:
				accent = dd.color
		var med := Medallion.new()
		med.custom_minimum_size = Vector2(34, 34)
		med.setup(Sprites.icon(bid), accent, b.rarity if b != null else "common")
		if b != null:
			med.tooltip_text = Loc.t(b.name_key)
		_items_row.add_child(med)
	for iid in RunManager.owned_items:
		var it = GameData.items.get(iid, null)
		var gem := Medallion.new()
		gem.custom_minimum_size = Vector2(30, 30)
		gem.setup(Sprites.icon(iid), it.color if it != null else Color(0.7, 0.7, 0.75), "common")
		if it != null:
			gem.tooltip_text = Loc.t(it.name_key)
		_items_row.add_child(gem)

## Give a label a dark outline so light text stays readable on any floor.
func _outline(label: Label, size: int) -> void:
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", size)
