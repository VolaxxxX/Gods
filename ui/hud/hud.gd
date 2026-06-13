class_name HUD
extends CanvasLayer
## Minimal greybox HUD: biome name + health. Presentation only — reads via the
## Events bus, never touches gameplay objects. All text via Loc keys.

var _biome_label: Label
var _health_label: Label

func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_biome_label = _make_label(root, Vector2(24, 20))
	_health_label = _make_label(root, Vector2(24, 52))

	Events.player_health_changed.connect(_on_health)
	_refresh_biome()
	_on_health(RunManager.player_health, RunManager.player_max_health)

func _make_label(parent: Control, pos: Vector2) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", 24)
	parent.add_child(l)
	return l

func _refresh_biome() -> void:
	var biome := GameData.get_biome(RunManager.biome_id)
	var name_key := biome.name_key if biome else "biome.unknown"
	_biome_label.text = Loc.t(name_key)

func _on_health(current: float, maximum: float) -> void:
	_health_label.text = Loc.t("hud.health", {"cur": int(ceil(current)), "max": int(maximum)})
