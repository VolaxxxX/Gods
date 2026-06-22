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

func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_biome_label = Label.new()
	_biome_label.position = Vector2(24, 16)
	_biome_label.add_theme_font_size_override("font_size", 24)
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
	gold_row.add_child(_gold_label)

	# Big centered realm banner, shown briefly on entering a zone.
	_banner = Label.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.position = Vector2(-400, 90)
	_banner.size = Vector2(800, 60)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 46)
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
	_boss_name.add_theme_font_size_override("font_size", 24)
	_boss_name.add_theme_color_override("font_color", Color(0.92, 0.5, 0.42))
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
	_refresh_biome()
	_show_banner()
	_on_health(RunManager.player_health, RunManager.player_max_health)
	_on_gold(RunManager.gold)

func _process(delta: float) -> void:
	if _banner_t > 0.0:
		_banner_t -= delta
		_banner.modulate.a = clampf(_banner_t, 0.0, 1.0)
	# Track the boss's health each frame (its bar lives on its own HealthComponent).
	if _boss_plate.visible:
		if is_instance_valid(_boss) and _boss.health != null:
			_boss_bar.value = _boss.health.fraction()
		else:
			_boss_plate.visible = false

func _on_boss_spawned(entity, name_key: String) -> void:
	_boss = entity
	_boss_name.text = Loc.t(name_key)
	_boss_bar.value = 1.0
	_boss_plate.visible = true

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

func _on_gold(total: int) -> void:
	_gold_label.text = Loc.t("hud.gold", {"n": total})
