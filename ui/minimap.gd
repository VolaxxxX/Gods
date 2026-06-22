class_name Minimap
extends Control
## A top-right minimap of the current floor: every room as a cell, doors as
## connectors, the current room highlighted, cleared rooms lit, specials colour-
## coded. Secret rooms stay hidden until found. Fed by the run scene each room.

const CELL := 14.0
const STEP := 20.0
const MARGIN := 18.0

# Room-type -> colour.
const TYPE_COL := {
	"start": Color(0.55, 0.7, 0.95),
	"combat": Color(0.62, 0.62, 0.68),
	"reward": Color(0.5, 0.85, 0.5),
	"shop": Color(0.95, 0.82, 0.4),
	"altar": Color(0.6, 0.85, 0.95),
	"challenge": Color(0.95, 0.6, 0.35),
	"cursed": Color(0.7, 0.45, 0.85),
	"miniboss": Color(0.9, 0.45, 0.4),
	"boss": Color(0.95, 0.3, 0.3),
	"secret": Color(0.8, 0.8, 0.85),
}

var _nodes: Dictionary = {}
var _current: Vector2i = Vector2i.ZERO
var _cleared: Dictionary = {}

func set_map(graph, current_pos: Vector2i, cleared: Dictionary) -> void:
	_nodes = graph.nodes if graph != null else {}
	_current = current_pos
	_cleared = cleared
	_layout()
	queue_redraw()

## Size + pin to the top-right of the screen from the grid bounds.
func _layout() -> void:
	if _nodes.is_empty():
		return
	var lo := Vector2i(9999, 9999)
	var hi := Vector2i(-9999, -9999)
	for pos: Vector2i in _nodes:
		lo.x = mini(lo.x, pos.x); lo.y = mini(lo.y, pos.y)
		hi.x = maxi(hi.x, pos.x); hi.y = maxi(hi.y, pos.y)
	var w: float = (hi.x - lo.x + 1) * STEP
	var h: float = (hi.y - lo.y + 1) * STEP
	size = Vector2(w, h)
	position = Vector2(1280.0 - w - MARGIN, 78.0)
	set_meta("lo", lo)

func _draw() -> void:
	if _nodes.is_empty() or not has_meta("lo"):
		return
	var lo: Vector2i = get_meta("lo")
	# Backing plate.
	draw_rect(Rect2(-8, -8, size.x + 16, size.y + 16), Color(0.04, 0.04, 0.06, 0.6))
	# Door connectors first (under the cells).
	for pos: Vector2i in _nodes:
		if _hidden(pos):
			continue
		var a := _cell_center(pos, lo)
		for side in _nodes[pos]["neighbors"].keys():
			var npos: Vector2i = _nodes[pos]["neighbors"][side]
			if _nodes.has(npos) and not _hidden(npos):
				draw_line(a, _cell_center(npos, lo), Color(0.5, 0.5, 0.55, 0.7), 2.0)
	# Cells.
	for pos: Vector2i in _nodes:
		if _hidden(pos):
			continue
		var gx: float = (pos.x - lo.x) * STEP
		var gy: float = (pos.y - lo.y) * STEP
		var r := Rect2(gx, gy, CELL, CELL)
		var t: String = _nodes[pos]["type"]
		var col: Color = TYPE_COL.get(t, Color(0.6, 0.6, 0.65))
		if not _cleared.has(pos) and pos != _current:
			col = col.darkened(0.45)  # known but not yet visited
		draw_rect(r, col)
		if t in ["boss", "miniboss", "shop", "altar", "secret"]:
			draw_rect(r, col.lightened(0.4), false, 1.5)  # marker ring for specials
		if pos == _current:
			draw_rect(Rect2(gx - 2, gy - 2, CELL + 4, CELL + 4), Color(1, 0.92, 0.6), false, 2.0)

func _cell_center(pos: Vector2i, lo: Vector2i) -> Vector2:
	return Vector2((pos.x - lo.x) * STEP + CELL * 0.5, (pos.y - lo.y) * STEP + CELL * 0.5)

## Secret rooms stay off the map until the player has found (entered) them.
func _hidden(pos: Vector2i) -> bool:
	return _nodes[pos]["type"] == "secret" and not _cleared.has(pos) and pos != _current
