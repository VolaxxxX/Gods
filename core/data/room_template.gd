class_name RoomTemplate
extends RefCounted
## A hand-authored room layout. The floor generator only PICKS and CONNECTS
## these; their interior is never procedural (see CLAUDE.md §3.5).
##
## `grid` is an array of equal-length strings, one per row. Legend:
##   '#' wall          '.' floor (walkable)       ' ' floor (alias)
##   'P' player spawn   'E' enemy spawn point      'O' obstacle (solid block)
##   'X' altar/feature anchor
## Doors are punched at the middle of each allowed side at build time.

const TILE_SIZE := 64  # px per cell (greybox)

var id: String = ""
var type: String = "combat"    # start|combat|reward|shop|altar|challenge|boss
var pantheon: String = ""
var grid: Array = []           # Array[String]
var doors: Array[String] = []  # allowed sides: "N","S","E","W"
var weight: float = 1.0        # selection weight within its type

var width: int = 0             # in cells
var height: int = 0

func cell(x: int, y: int) -> String:
	if y < 0 or y >= grid.size():
		return "#"
	var row: String = grid[y]
	if x < 0 or x >= row.length():
		return "#"
	return row[x]

func is_wall(x: int, y: int) -> bool:
	var c := cell(x, y)
	return c == "#" or c == "O"

## World-space size of the room.
func pixel_size() -> Vector2:
	return Vector2(width * TILE_SIZE, height * TILE_SIZE)

func enemy_spawns() -> Array[Vector2]:
	return _markers("E")

func player_spawn() -> Vector2:
	var p := _markers("P")
	return p[0] if not p.is_empty() else pixel_size() * 0.5

func feature_anchors() -> Array[Vector2]:
	return _markers("X")

func _markers(symbol: String) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for y in grid.size():
		var row: String = grid[y]
		for x in row.length():
			if row[x] == symbol:
				out.append(Vector2(x + 0.5, y + 0.5) * TILE_SIZE)
	return out

static func from_dict(d: Dictionary) -> RoomTemplate:
	var r := RoomTemplate.new()
	r.id = d.get("id", "")
	r.type = d.get("type", "combat")
	r.pantheon = d.get("pantheon", "")
	r.grid = d.get("grid", [])
	r.doors = DataUtil.to_string_array(d.get("doors", ["N", "S", "E", "W"]))
	r.weight = float(d.get("weight", 1.0))
	r.height = r.grid.size()
	r.width = 0
	for row in r.grid:
		r.width = max(r.width, String(row).length())
	return r
