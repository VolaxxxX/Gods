class_name FloorGenerator
extends RefCounted
## Builds a floor by GROWING a connected tree of rooms on a grid, then assigning
## room types and hand-authored templates. THE ONLY procedural step in the game
## (CLAUDE.md §3.5): it picks and connects authored rooms; it never invents room
## interiors.
##
## `build_graph()` is pure and dependency-free (no autoloads) so it can be unit
## tested headless. `generate()` wraps it for runtime (seed from the global RNG,
## template binding via GameData, event emission).

const STREAM := "floor"

## Runtime entry point. Deterministic given the run seed (via the RNG autoload).
func generate(biome: BiomeData, room_count: int = -1) -> FloorGraph:
	var target: int = room_count if room_count > 0 else biome.room_count
	var floor_seed: int = RNG.stream(STREAM).randi()
	var g := build_graph(floor_seed, target)
	_assign_templates(g, biome)
	Events.emit_signal("floor_generated", 0)
	return g

## Pure graph builder: same seed + target -> identical graph. No globals.
func build_graph(seed_value: int, target: int) -> FloorGraph:
	target = max(target, 4)  # room for start + specials + boss
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	var g := FloorGraph.new()
	g.add_node(Vector2i.ZERO, "start")
	g.start_pos = Vector2i.ZERO
	var frontier: Array = [Vector2i.ZERO]

	var guard := 0
	while g.count() < target and guard < target * 200:
		guard += 1
		var from: Vector2i = frontier[rng.randi_range(0, frontier.size() - 1)]
		var sides: Array = FloorGraph.DIRS.keys()
		_shuffle(rng, sides)
		var placed := false
		for side in sides:
			var cand: Vector2i = from + FloorGraph.DIRS[side]
			if g.has(cand):
				continue
			if g.occupied_neighbor_count(cand) > 1:
				continue  # keep tree-like: only the parent touches the new cell
			g.add_node(cand, "combat")
			g.connect_rooms(from, cand)
			frontier.append(cand)
			placed = true
			break
		if not placed:
			frontier.erase(from)
			if frontier.is_empty():
				break

	_assign_special_rooms(g, rng)
	return g

func _assign_special_rooms(g: FloorGraph, rng: RandomNumberGenerator) -> void:
	var dead_ends := g.dead_ends()
	if dead_ends.is_empty():
		return
	var dist := g.distances_from_start()

	# Boss = farthest dead-end from the start.
	var boss: Vector2i = dead_ends[0]
	for pos in dead_ends:
		if int(dist.get(pos, 0)) > int(dist.get(boss, 0)):
			boss = pos
	g.get_node(boss)["type"] = "boss"
	g.boss_pos = boss

	# Other dead-ends become special rooms, deterministically. Miniboss is first
	# so it has priority among the dead-ends.
	var rest: Array = dead_ends.duplicate()
	rest.erase(boss)
	_shuffle(rng, rest)
	var specials := ["miniboss", "reward", "shop", "altar", "challenge", "cursed"]
	for i in rest.size():
		if i < specials.size():
			g.get_node(rest[i])["type"] = specials[i]

	# Guarantee exactly one miniboss per floor: if no dead-end became one,
	# promote a random combat room.
	_ensure_one(g, "miniboss", rng)

## Make sure at least one room has `type`, converting a combat room if needed.
func _ensure_one(g: FloorGraph, type: String, rng: RandomNumberGenerator) -> void:
	var combats: Array = []
	for pos in g.nodes:
		var t: String = g.nodes[pos]["type"]
		if t == type:
			return
		if t == "combat":
			combats.append(pos)
	if combats.is_empty():
		return
	_shuffle(rng, combats)
	g.get_node(combats[0])["type"] = type

func _assign_templates(g: FloorGraph, biome: BiomeData) -> void:
	for pos in g.nodes:
		var node: Dictionary = g.nodes[pos]
		var pool := GameData.rooms_for(biome.pantheon, node["type"])
		if pool.is_empty():
			node["template_id"] = ""  # robust fallback: room builds a default box
			continue
		var weights: Array = []
		for r in pool:
			weights.append(r.weight)
		var chosen: RoomTemplate = RNG.pick_weighted(STREAM, pool, weights)
		node["template_id"] = chosen.id if chosen else ""

## Deterministic Fisher-Yates using the provided RNG.
func _shuffle(rng: RandomNumberGenerator, array: Array) -> void:
	for i in range(array.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = array[i]
		array[i] = array[j]
		array[j] = tmp
