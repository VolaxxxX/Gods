class_name BlessingChoice
extends CanvasLayer
## Modal divine-pact picker shown at altars (Hades-style boon choice). Pauses the
## run while open. Presentation only — it emits the chosen id and lets the run
## apply it via RunManager.

signal chosen(blessing_id: String)

var _options: Array = []  # Array[BlessingData]
var _title_key: String = "ui.choose_blessing"

func setup(options: Array, title_key: String = "ui.choose_blessing") -> void:
	_options = options
	_title_key = title_key

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep working while the tree is paused
	get_tree().paused = true

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	# Styled window panel (themed) holding the choices.
	var window := PanelContainer.new()
	window.set_anchors_preset(Control.PRESET_CENTER)
	window.position = Vector2(-300, -70 - 58 * _options.size())
	add_child(window)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(560, 0)
	box.add_theme_constant_override("separation", 14)
	window.add_child(box)

	var title := Label.new()
	title.text = Loc.t(_title_key)
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.title(title)
	box.add_child(title)

	for b in _options:
		box.add_child(_boon_card(b))

## A premium boon card: a click button behind, an ornate medallion + rich text on
## top (the medallion frames even a simple icon so it reads pro).
func _boon_card(b) -> Control:
	var card := Control.new()
	card.custom_minimum_size = Vector2(560, 104)

	var btn := Button.new()
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.pressed.connect(_on_pick.bind(b.id))
	card.add_child(btn)

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 16)
	row.offset_left = 12
	row.offset_right = -16
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE  # clicks fall through to the button
	card.add_child(row)

	var accent := Color(0.85, 0.72, 0.38)
	var dd = GameData.deities.get(b.deity_id, null)
	if dd != null:
		accent = dd.color

	# Lead with the deity's portrait (splash art) so the player sees WHICH god is
	# offering the boon. Falls back to the framed blessing icon if no portrait art.
	var face := Sprites.portrait(b.deity_id)
	if face != null:
		var frame := PanelContainer.new()
		frame.custom_minimum_size = Vector2(90, 90)
		frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.05, 0.05, 0.07)
		sb.set_corner_radius_all(10)
		sb.set_border_width_all(3)
		sb.border_color = accent
		sb.shadow_color = Color(accent.r, accent.g, accent.b, 0.35)
		sb.shadow_size = 6
		sb.set_content_margin_all(3)
		frame.add_theme_stylebox_override("panel", sb)
		var tex := TextureRect.new()
		tex.texture = face
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tex.custom_minimum_size = Vector2(82, 82)
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(tex)
		row.add_child(frame)
	else:
		var med := Medallion.new()
		med.custom_minimum_size = Vector2(76, 76)
		med.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		med.setup(Sprites.icon(b.id), accent, b.rarity)
		row.add_child(med)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)

	var name_lbl := Label.new()
	name_lbl.text = Loc.t(b.name_key)
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_color_override("font_color", accent.lightened(0.25))
	UITheme.title(name_lbl)
	col.add_child(name_lbl)

	var desc_lbl := Label.new()
	var desc := Loc.t(b.desc_key)
	if RunManager.is_rival_of_owned(b.deity_id):
		desc += "\n%s" % Loc.t("ui.rival_warning")
	desc_lbl.text = desc
	desc_lbl.add_theme_font_size_override("font_size", 16)
	desc_lbl.add_theme_color_override("font_color", Color(0.86, 0.84, 0.78))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.custom_minimum_size = Vector2(400, 0)
	col.add_child(desc_lbl)

	return card

func _on_pick(id: String) -> void:
	get_tree().paused = false
	chosen.emit(id)
	queue_free()
