class_name Codex
extends CanvasLayer
## The "Book of the Dead": a browsable lore screen. Realms/lords/gods unlock as
## the player learns them; the BESTIARY unlocks creature by creature — a beast
## appears (with its sprite + mythological history) only once you have actually
## met it in play. Undiscovered beasts are not shown at all. Presentation only.

const CAT_TITLE := {
	"realm": "Realms of the Dead", "lord": "Lords of the Dead",
	"deity": "Gods of the Realms", "beast": "Beasts of the Realms",
}
# Order beasts read in: by realm, then plain foes -> miniboss -> boss.
const PANTHEON_ORDER := ["greece", "bali", "egypt", "norse", "japan", "aztec", "hell"]
const ROLE_ORDER := {"enemy": 0, "miniboss": 1, "boss": 2}

var _body_title: Label
var _body_text: RichTextLabel
var _beast_img: TextureRect

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

	# Right: the selected entry's image (beasts) + text.
	var detail := PanelContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_child(detail)
	var dscroll := ScrollContainer.new()
	dscroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_child(dscroll)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 12)
	dv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dscroll.add_child(dv)
	_body_title = Label.new()
	_body_title.add_theme_font_size_override("font_size", 26)
	UITheme.title(_body_title)
	dv.add_child(_body_title)
	_beast_img = TextureRect.new()
	_beast_img.visible = false
	_beast_img.custom_minimum_size = Vector2(0, 240)
	_beast_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_beast_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_beast_img.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	dv.add_child(_beast_img)
	_body_text = RichTextLabel.new()
	_body_text.bbcode_enabled = false
	_body_text.fit_content = true
	_body_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_text.custom_minimum_size = Vector2(600, 0)
	dv.add_child(_body_text)

	var unlocked_total := 0
	var first_shown := false
	# Lore categories (realms / lords / gods) from the codex data.
	for cat in ["realm", "lord", "deity"]:
		var entries := _entries_for(cat)
		if entries.is_empty():
			continue
		_add_header(list, CAT_TITLE.get(cat, cat))
		for e in entries:
			var unlocked: bool = e.is_unlocked()
			if unlocked:
				unlocked_total += 1
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(340, 40)
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.text = e.title if unlocked else "🔒  " + Loc.t("ui.codex_locked")
			btn.disabled = not unlocked
			if unlocked:
				btn.pressed.connect(_show.bind(e))
				if not first_shown:
					first_shown = true
					_show(e)
			list.add_child(btn)

	# Bestiary: only creatures the player has actually encountered are listed.
	var beasts := _seen_beasts()
	var beast_total := _beast_total()
	if not beasts.is_empty():
		_add_header(list, CAT_TITLE["beast"] + "  (" + str(beasts.size()) + "/" + str(beast_total) + ")")
		for id in beasts:
			var ed = GameData.get_entity(id)
			if ed == null:
				continue
			var bbtn := Button.new()
			bbtn.custom_minimum_size = Vector2(340, 40)
			bbtn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			bbtn.text = Loc.t(ed.name_key)
			bbtn.pressed.connect(_show_beast.bind(id))
			list.add_child(bbtn)
			if not first_shown:
				first_shown = true
				_show_beast(id)

	var subtitle := Label.new()
	subtitle.modulate = Color(0.75, 0.75, 0.8)
	var beast_line := "   ·   " + Loc.t("ui.bestiary_progress", {"n": beasts.size(), "t": beast_total})
	subtitle.text = Loc.t("ui.codex_progress", {"n": unlocked_total, "t": GameData.codex.size()}) + beast_line
	root.add_child(subtitle)

	if not first_shown:
		_body_title.text = ""
		_body_text.text = Loc.t("ui.codex_empty")

func _add_header(list: VBoxContainer, text: String) -> void:
	var head := Label.new()
	head.text = text
	head.add_theme_font_size_override("font_size", 18)
	head.modulate = Color(0.8, 0.72, 0.45)
	list.add_child(head)

## CodexData of a category, sorted by `order`.
func _entries_for(cat: String) -> Array:
	var out: Array = []
	for c in GameData.codex.values():
		if c.category == cat:
			out.append(c)
	out.sort_custom(func(a, b): return a.order < b.order)
	return out

## All fightable creatures (enemy/miniboss/boss), sorted realm then role.
func _all_beasts() -> Array:
	var out: Array = []
	for ed in GameData.entities.values():
		if String(ed.role) in ["enemy", "miniboss", "boss"]:
			out.append(ed)
	out.sort_custom(func(a, b):
		var pa := PANTHEON_ORDER.find(String(a.pantheon))
		var pb := PANTHEON_ORDER.find(String(b.pantheon))
		if pa != pb:
			return pa < pb
		return int(ROLE_ORDER.get(String(a.role), 0)) < int(ROLE_ORDER.get(String(b.role), 0)))
	return out

func _beast_total() -> int:
	return _all_beasts().size()

## Ids of beasts the player has met (flag "seen_<id>" set on first encounter).
func _seen_beasts() -> Array:
	var out: Array = []
	for ed in _all_beasts():
		if SaveManager.has_flag("seen_" + ed.id):
			out.append(ed.id)
	return out

func _show(e: CodexData) -> void:
	_beast_img.visible = false
	_beast_img.texture = null
	_body_title.text = e.title
	_body_text.text = "\n\n".join(e.body)

func _show_beast(id: String) -> void:
	var ed = GameData.get_entity(id)
	if ed == null:
		return
	_body_title.text = Loc.t(ed.name_key)
	var tex := Sprites.entity(id)
	if tex == null:
		tex = Sprites.entity_generic()
	_beast_img.texture = tex
	_beast_img.visible = tex != null
	var lore := Loc.t("bestiary." + id + ".lore")
	# If a specific lore string is missing, fall back gracefully.
	if lore == "bestiary." + id + ".lore":
		lore = Loc.t(ed.name_key)
	_body_text.text = lore
