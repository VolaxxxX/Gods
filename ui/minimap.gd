class_name Minimap
extends Control
## A clean top-right minimap of the current floor: framed panel, rounded room
## cells, doors as connectors, the current room pulsing gold, specials colour-
## coded AND letter-tagged so the map reads at a glance. Secret rooms stay hidden
## until found; un-entered rooms show only that they exist (no spoilers).

const CELL := 20.0
const STEP := 28.0
const PAD := 12.0
const MARGIN := 16.0

const TYPE_COL := {
	"start": Color(0.55, 0.70, 0.95),
	"combat": Color(0.60, 0.62, 0.70),
	"reward": Color(0.46, 0.82, 0.50),
	"shop": Color(0.96, 0.82, 0.40),
	"altar": Color(0.58, 0.86, 0.96),
	"challenge": Color(0.95, 0.58, 0.34),
	"cursed": Color(0.72, 0.46, 0.88),
	"miniboss": Color(0.92, 0.50, 0.42),
	"boss": Color(0.96, 0.32, 0.32),
	"secret": Color(0.82, 0.82, 0.88),
}
# A single-letter tag stamped on each SEEN special room, so colour-blind players
# (and everyone in a hurry) can tell rooms apart without memorising the palette.
const TYPE_LETTER := {
	"boss": "B", "miniboss": "m", "shop": "$", "reward": "+",
	"altar": "A", "challenge": "!", "cursed": "C", "start": "@",
}

var _nodes: Dictionary = {}
var _current: Vector2i = Vector2i.ZERO
var _cleared: Dictionary = {}
var _t := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_map(graph, current_pos: Vector2i, cleared: Dictionary) -> void:
	_nodes = graph.nodes if graph != null else {}
	_current = current_pos
	_cleared = cleared
	_layout()
	queue_redraw()

func _process(delta: float) -> void:
	if _nodes.is_empty():
		return
	_t += delta
	queue_redraw()  # gentle current-room pulse

func _layout() -> void:
	if _nodes.is_empty():
		return
	var lo := Vector2i(9999, 9999)
	var hi := Vector2i(-9999, -9999)
	for pos: Vector2i in _nodes:
		lo.x = mini(lo.x, pos.x); lo.y = mini(lo.y, pos.y)
		hi.x = maxi(hi.x, pos.x); hi.y = maxi(hi.y, pos.y)
	var w: float = (hi.x - lo.x + 1) * STEP - (STEP - CELL)
	var h: float = (hi.y - lo.y + 1) * STEP - (STEP - CELL)
	var title_h := 20.0
	size = Vector2(w + PAD * 2.0, h + PAD * 2.0 + title_h)
	position = Vector2(1280.0 - size.x - MARGIN, 74.0)
	set_meta("lo", lo)
	set_meta("title_h", title_h)

func _draw() -> void:
	if _nodes.is_empty() or not has_meta("lo"):
		return
	var lo: Vector2i = get_meta("lo")
	var title_h: float = get_meta("title_h")
	var font := ThemeDB.fallback_font
	# Framed panel (dark glass + a thin gold trim), rounded.
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(0.05, 0.05, 0.08, 0.86)
	plate.set_corner_radius_all(8)
	plate.set_border_width_all(2)
	plate.border_color = Color(0.55, 0.46, 0.24, 0.9)
	draw_style_box(plate, Rect2(Vector2.ZERO, size))
	# Title so the panel reads as "the map".
	draw_string(font, Vector2(PAD, 15.0), Loc.t("ui.map"),
		HORIZONTAL_ALIGNMENT_LEFT, size.x - PAD * 2.0, 13, Color(0.85, 0.78, 0.55))

	var o := Vector2(PAD, PAD + title_h)
	# Door connectors under the cells (thicker + brighter so links are obvious).
	for pos: Vector2i in _nodes:
		if _hidden(pos):
			continue
		var a := o + _cell_pos(pos, lo) + Vector2(CELL, CELL) * 0.5
		for side in _nodes[pos]["neighbors"].keys():
			var npos: Vector2i = _nodes[pos]["neighbors"][side]
			if _nodes.has(npos) and not _hidden(npos):
				draw_line(a, o + _cell_pos(npos, lo) + Vector2(CELL, CELL) * 0.5,
					Color(0.62, 0.56, 0.42, 0.75), 3.0)

	for pos: Vector2i in _nodes:
		if _hidden(pos):
			continue
		var p := o + _cell_pos(pos, lo)
		var t: String = _nodes[pos]["type"]
		var seen: bool = _cleared.has(pos) or pos == _current
		# Un-visited rooms show only that they EXIST (neutral grey) — their type is
		# hidden so the map never spoils what's next. Colour + letter reveal on entry.
		var col: Color = TYPE_COL.get(t, Color(0.6, 0.6, 0.65)) if seen else Color(0.26, 0.26, 0.32)
		# Cleared rooms dim slightly so the UNcleared ones (things left to do) pop.
		if seen and _cleared.has(pos) and pos != _current:
			col = col.darkened(0.28)
		var cell := StyleBoxFlat.new()
		cell.bg_color = col
		cell.set_corner_radius_all(4)
		draw_style_box(cell, Rect2(p, Vector2(CELL, CELL)))
		# Letter tag for seen specials.
		if seen and TYPE_LETTER.has(t):
			var letter: String = TYPE_LETTER[t]
			var lw := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			draw_string(font, p + Vector2((CELL - lw) * 0.5, CELL * 0.5 + 5.0),
				letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.06, 0.05, 0.08))
		if pos == _current:
			# The player's room: a filled gold dot + a pulsing gold frame = "you are here".
			var pulse: float = 0.55 + 0.45 * (0.5 + 0.5 * sin(_t * 4.0))
			draw_circle(p + Vector2(CELL, CELL) * 0.5, 3.4, Color(1.0, 0.92, 0.6, 0.95))
			var hl := StyleBoxFlat.new()
			hl.bg_color = Color(0, 0, 0, 0)
			hl.set_corner_radius_all(5)
			hl.set_border_width_all(2)
			hl.border_color = Color(1.0, 0.9, 0.55, pulse)
			draw_style_box(hl, Rect2(p - Vector2(2, 2), Vector2(CELL + 4, CELL + 4)))

func _cell_pos(pos: Vector2i, lo: Vector2i) -> Vector2:
	return Vector2((pos.x - lo.x) * STEP, (pos.y - lo.y) * STEP)

func _hidden(pos: Vector2i) -> bool:
	return _nodes[pos]["type"] == "secret" and not _cleared.has(pos) and pos != _current
