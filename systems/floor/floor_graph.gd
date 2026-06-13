class_name FloorGraph
extends RefCounted
## Result of floor generation: a connected graph of rooms on an integer grid.
## Connectivity is guaranteed by construction (see FloorGenerator), so every
## room is always reachable from the start (DoD: no unreachable rooms).
##
## A node is a Dictionary:
##   { "pos": Vector2i, "type": String, "template_id": String,
##     "neighbors": { "N": Vector2i, ... }, "cleared": bool }

const DIRS := {
	"N": Vector2i(0, -1),
	"S": Vector2i(0, 1),
	"E": Vector2i(1, 0),
	"W": Vector2i(-1, 0),
}
const OPPOSITE := {"N": "S", "S": "N", "E": "W", "W": "E"}

var nodes: Dictionary = {}      # Vector2i -> node dict
var start_pos: Vector2i = Vector2i.ZERO
var boss_pos: Vector2i = Vector2i.ZERO

func add_node(pos: Vector2i, type: String) -> Dictionary:
	var n := {"pos": pos, "type": type, "template_id": "", "neighbors": {}, "cleared": false}
	nodes[pos] = n
	return n

func has(pos: Vector2i) -> bool:
	return nodes.has(pos)

func get_node(pos: Vector2i) -> Dictionary:
	return nodes.get(pos, {})

func count() -> int:
	return nodes.size()

## Record a bidirectional connection (door) between two adjacent rooms.
func connect_rooms(a: Vector2i, b: Vector2i) -> void:
	for side in DIRS:
		if a + DIRS[side] == b:
			nodes[a]["neighbors"][side] = b
			nodes[b]["neighbors"][OPPOSITE[side]] = a
			return

## Count of occupied 4-neighbors of a cell (occupied or not in graph).
func occupied_neighbor_count(pos: Vector2i) -> int:
	var c := 0
	for side in DIRS:
		if nodes.has(pos + DIRS[side]):
			c += 1
	return c

## Rooms with exactly one connection (dead-ends), excluding the start room.
func dead_ends() -> Array:
	var out: Array = []
	for pos in nodes:
		if pos == start_pos:
			continue
		if nodes[pos]["neighbors"].size() == 1:
			out.append(pos)
	return out

## BFS distances (in rooms) from start. Returns Vector2i -> int.
func distances_from_start() -> Dictionary:
	var dist := {start_pos: 0}
	var queue: Array = [start_pos]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for side in nodes[cur]["neighbors"]:
			var nb: Vector2i = nodes[cur]["neighbors"][side]
			if not dist.has(nb):
				dist[nb] = dist[cur] + 1
				queue.append(nb)
	return dist

## True if every room is reachable from the start (sanity check / tests).
func all_reachable() -> bool:
	return distances_from_start().size() == nodes.size()
