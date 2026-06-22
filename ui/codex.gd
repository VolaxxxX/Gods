class_name Codex
extends CanvasLayer
## The "Book of the Dead": a browsable lore screen. Entries unlock as the player
## learns them in play (realms by entering them, lords by defeating them). Locked
## entries are listed but masked. Opened from the hub; presentation only.

const CAT_TITLE := {"realm": "Realms of the Dead", "lord": "Lords of the Dead"}

var _body_title: Label
var _body_text: RichTextLabel

func _ready() -> void:
	layer = 22
	process_mode = Node.PROCESS_MODE_ALWAYS

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var frame := PanelContainer.new()
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.custom_minimum_size = Vector2(1040, 600)
	frame.position = Vector2(-520, -300)
	add_child(frame)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	frame.add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	var title := Label.new()
	title.text = Loc.t("ui.codex")
	title.add_theme_font_size_override("font_size", 32)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.title(title)
	header.add_child(title)
	var close := Button.new()
	close.text = Loc.t("ui.close")
	close.custom_minimum_size = Vector2(140, 48)
	close.pressed.connect(queue_free)
	header.add_child(close)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 14)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)

	# Left: scrollable list of entries grouped by category.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(360, 500)
	cols.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	# Right: the selected entry's text.
	var detail := PanelContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_child(detail)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 12)
	detail.add_child(dv)
	_body_title = Label.new()
	_body_title.add_theme_font_size_override("font_size", 26)
	UITheme.title(_body_title)
	dv.add_child(_body_title)
	_body_text = RichTextLabel.new()
	_body_text.bbcode_enabled = false
	_body_text.fit_content = true
	_body_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_text.custom_minimum_size = Vector2(600, 0)
	dv.add_child(_body_text)

	var unlocked_total := 0
	var first: CodexData = null
	for cat in ["realm", "lord"]:
		var entries := _entries_for(cat)
		if entries.is_empty():
			continue
		var head := Label.new()
		head.text = CAT_TITLE.get(cat, cat)
		head.add_theme_font_size_override("font_size", 18)
		head.modulate = Color(0.8, 0.72, 0.45)
		list.add_child(head)
		for e in entries:
			var unlocked: bool = e.is_unlocked()
			if unlocked:
				unlocked_total += 1
				if first == null:
					first = e
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(340, 40)
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.text = e.title if unlocked else "🔒  " + Loc.t("ui.codex_locked")
			btn.disabled = not unlocked
			if unlocked:
				btn.pressed.connect(_show.bind(e))
			list.add_child(btn)

	var subtitle := Label.new()
	subtitle.modulate = Color(0.75, 0.75, 0.8)
	subtitle.text = Loc.t("ui.codex_progress", {"n": unlocked_total, "t": GameData.codex.size()})
	root.add_child(subtitle)

	if first != null:
		_show(first)
	else:
		_body_title.text = ""
		_body_text.text = Loc.t("ui.codex_empty")

## CodexData of a category, sorted by `order`.
func _entries_for(cat: String) -> Array:
	var out: Array = []
	for c in GameData.codex.values():
		if c.category == cat:
			out.append(c)
	out.sort_custom(func(a, b): return a.order < b.order)
	return out

func _show(e: CodexData) -> void:
	_body_title.text = e.title
	_body_text.text = "\n\n".join(e.body)
