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
