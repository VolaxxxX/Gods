class_name DoorChoice
extends CanvasLayer
## Hades-style branching: after a palier (mini-)boss falls, the player picks one
## of TWO doors to the next floor of the SAME realm. Each door previews its reward
## (icon + name + description). Pauses the run while open. Presentation only — it
## emits the chosen door kind; the run applies the reward and descends.

signal chosen(kind: String)

# kind -> [name_key, desc_key, fallback glyph]. Icons come from assets/sprites/ui/
# door_<kind>.png if present, else the glyph is drawn as text.
const DOORS := {
	"treasure": ["ui.door_treasure", "ui.door_treasure_desc", "❖"],
	"boon": ["ui.door_boon", "ui.door_boon_desc", "✦"],
	"vigor": ["ui.door_vigor", "ui.door_vigor_desc", "✚"],
}
const DOOR_ACCENT := {
	"treasure": Color(0.90, 0.76, 0.36),  # gold
	"boon": Color(0.74, 0.55, 0.92),      # divine violet
	"vigor": Color(0.86, 0.40, 0.42),     # life crimson
}

var _kinds: Array = []

func setup(kinds: Array) -> void:
	_kinds = kinds

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_CENTER)
	root.position = Vector2(-330, -170)
	root.custom_minimum_size = Vector2(660, 0)
	root.add_theme_constant_override("separation", 18)
	add_child(root)

	var title := Label.new()
	title.text = Loc.t("ui.choose_door")
	title.add_theme_font_size_override("font_size", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.title(title)
	root.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(row)

	for kind in _kinds:
		row.add_child(_make_door(String(kind)))

## One door = a tall button with an icon/glyph, a name and a short reward preview.
func _make_door(kind: String) -> Button:
	var meta: Array = DOORS.get(kind, ["ui.door_boon", "ui.door_boon_desc", "?"])
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(300, 300)
	# Centered card content: icon (or glyph) on top, name, then the reward preview.
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 10)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vb)

	# An ornate medallion frames the door's icon (or a greybox gem if absent).
	var accent: Color = DOOR_ACCENT.get(kind, Color(0.85, 0.72, 0.38))
	var med := Medallion.new()
	med.custom_minimum_size = Vector2(132, 132)
	med.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	med.mouse_filter = Control.MOUSE_FILTER_IGNORE
	med.setup(Sprites.icon("door_" + kind), accent, "rare")
	vb.add_child(med)

	var name_l := Label.new()
	name_l.text = Loc.t(meta[0])
	name_l.add_theme_font_size_override("font_size", 24)
	name_l.add_theme_color_override("font_color", Color(0.9, 0.76, 0.42))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.title(name_l)
	vb.add_child(name_l)

	var desc := Label.new()
	desc.text = Loc.t(meta[1])
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.custom_minimum_size = Vector2(252, 0)
	desc.modulate = Color(0.85, 0.85, 0.9)
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(desc)

	btn.pressed.connect(_on_pick.bind(kind))
	return btn

func _on_pick(kind: String) -> void:
	get_tree().paused = false
	chosen.emit(kind)
	queue_free()
