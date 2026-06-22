class_name RealmChoice
extends CanvasLayer
## Modal shown after a boss falls: choose which underworld to descend into next
## (non-linear branching). Pauses the run while open. Presentation only.

signal chosen(biome_id: String)

var _options: Array = []  # Array[BiomeData]

func setup(options: Array) -> void:
	_options = options

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-260, -40 - 44 * _options.size())
	box.custom_minimum_size = Vector2(520, 0)
	box.add_theme_constant_override("separation", 14)
	add_child(box)

	var title := Label.new()
	title.text = Loc.t("ui.choose_realm")
	title.add_theme_font_size_override("font_size", 30)
	UITheme.title(title)
	box.add_child(title)

	for b in _options:
		var btn := Button.new()
		btn.text = Loc.t(b.name_key)
		btn.custom_minimum_size = Vector2(520, 70)
		btn.pressed.connect(_on_pick.bind(b.id))
		box.add_child(btn)

func _on_pick(id: String) -> void:
	get_tree().paused = false
	chosen.emit(id)
	queue_free()
