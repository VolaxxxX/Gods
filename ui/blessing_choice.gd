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
	window.position = Vector2(-260, -70 - 45 * _options.size())
	add_child(window)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(480, 0)
	box.add_theme_constant_override("separation", 12)
	window.add_child(box)

	var title := Label.new()
	title.text = Loc.t(_title_key)
	title.add_theme_font_size_override("font_size", 28)
	UITheme.title(title)
	box.add_child(title)

	for b in _options:
		var btn := Button.new()
		var label := "%s — %s" % [Loc.t(b.name_key), Loc.t(b.desc_key)]
		# Warn when this boon would anger a rival deity already followed (curse).
		if RunManager.is_rival_of_owned(b.deity_id):
			label += "\n%s" % Loc.t("ui.rival_warning")
		btn.text = label
		btn.custom_minimum_size = Vector2(460, 72)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var ic := Sprites.icon(b.id)  # boon icon if one exists
		if ic != null:
			btn.icon = ic
			btn.expand_icon = true
		btn.pressed.connect(_on_pick.bind(b.id))
		box.add_child(btn)

func _on_pick(id: String) -> void:
	get_tree().paused = false
	chosen.emit(id)
	queue_free()
