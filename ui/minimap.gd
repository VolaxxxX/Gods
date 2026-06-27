class_name Minimap
extends Control
## A clean top-right minimap of the current floor: framed panel, rounded room
## cells, doors as connectors, the current room pulsing gold, specials colour-
## coded with a bright pip. Secret rooms stay hidden until found.

const CELL := 16.0
const STEP := 23.0
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
# Specials get a bright centre pip so they stand out at a glance.
const PIP := {"boss": true, "miniboss": true, "shop": true, "altar": true,
	"reward": true, "challenge": true, "cursed": true, "secret": true}

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
	size = Vector2(w + PAD * 2.0, h + PAD * 2.0)
	position = Vector2(1280.0 - size.x - MARGIN, 74.0)
	set_meta("lo", lo)

func _draw() -> void:
	if _nodes.is_empty() or not has_meta("lo"):
		return
	var lo: Vector2i = get_meta("lo")
	# Framed panel (dark glass + a thin gold trim), rounded.
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(0.05, 0.05, 0.08, 0.82)
	plate.set_corner_radius_all(8)
	plate.set_border_width_all(2)
	plate.border_color = Color(0.55, 0.46, 0.24, 0.85)
	draw_style_box(plate, Rect2(Vector2.ZERO, size))

	var o := Vector2(PAD, PAD)
	# Door connectors under the cells.
	for pos: Vector2i in _nodes:
		if _hidden(pos):
			continue
		var a := o + _cell_pos(pos, lo) + Vector2(CELL, CELL) * 0.5
		for side in _nodes[pos]["neighbors"].keys():
			var npos: Vector2i = _nodes[pos]["neighbors"][side]
			if _nodes.has(npos) and not _hidden(npos):
				draw_line(a, o + _cell_pos(npos, lo) + Vector2(CELL, CELL) * 0.5,
					Color(0.55, 0.50, 0.40, 0.6), 2.0)

	for pos: Vector2i in _nodes:
		if _hidden(pos):
			continue
		var p := o + _cell_pos(pos, lo)
		var t: String = _nodes[pos]["type"]
		var col: Color = TYPE_COL.get(t, Color(0.6, 0.6, 0.65))
		var seen: bool = _cleared.has(pos) or pos == _current
		if not seen:
			col = col.darkened(0.5)  # known but not yet entered
		var cell := StyleBoxFlat.new()
		cell.bg_color = col
		cell.set_corner_radius_all(4)
		draw_style_box(cell, Rect2(p, Vector2(CELL, CELL)))
		if seen and PIP.has(t):
			draw_circle(p + Vector2(CELL, CELL) * 0.5, 3.0, col.lightened(0.55))
		if pos == _current:
			var pulse: float = 0.55 + 0.45 * (0.5 + 0.5 * sin(_t * 4.0))
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
