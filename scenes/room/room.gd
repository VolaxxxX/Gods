class_name Room
extends Node2D
## A single playable room. Builds walls/obstacles/doors from a hand-authored
## RoomTemplate (or a default box if none), spawns enemies from the biome pool,
## and unlocks its doors when cleared. Greybox visuals are code-drawn.
##
## The run scene owns the floor graph and tells each room which sides have
## neighbors (open_sides). Walking into a door emits `door_taken(side)`.

const TILE := RoomTemplate.TILE_SIZE
const WALL_THICK := 16.0
const DOOR_HALF := 48.0   # half-width of a door gap

signal cleared
signal door_taken(side: String)

var template: RoomTemplate
var biome: BiomeData
var open_sides: Array[String] = []   # sides that connect to a neighbor
var room_type: String = "combat"
var locked: bool = false

var _size: Vector2 = Vector2(13 * TILE, 9 * TILE)
var _alive_enemies: int = 0
var _gates: Array[StaticBody2D] = []
var _floor_color := Color(0.15, 0.15, 0.2)
var _wall_color := Color(0.35, 0.32, 0.28)
var _accent_color := Color(0.85, 0.7, 0.35)
var _pantheon := ""

func build(p_template: RoomTemplate, p_biome: BiomeData, p_open_sides: Array[String],
		p_type: String, target: Node2D, pool: ProjectilePool) -> void:
	template = p_template
	biome = p_biome
	open_sides = p_open_sides
	room_type = p_type
	if biome:
		_pantheon = biome.pantheon
		_floor_color = biome.palette_color("floor", _floor_color)
		_wall_color = biome.palette_color("wall", _wall_color)
		_accent_color = biome.palette_color("accent", _accent_color)

	if template != null:
		_size = template.pixel_size()
	else:
		_size = Vector2(13 * TILE, 9 * TILE)

	_build_walls()
	_build_obstacles()
	_build_doors()

	# Room-type contents.
	if room_type == "reward" or room_type == "shop":
		_spawn_pickups(room_type == "shop")
	elif room_type == "challenge":
		_spawn_sacrifice()
	elif room_type == "cursed":
		_spawn_pickups(false)  # a free reward — but you must fight for it

	# Fight rooms lock until cleared; safe rooms are open immediately.
	var has_combat: bool = room_type in ["combat", "boss", "miniboss", "cursed"]
	if has_combat:
		_spawn_enemies(target, pool)
	if _alive_enemies > 0:
		_lock()
	else:
		emit_signal("cleared")

	queue_redraw()

func player_spawn_point() -> Vector2:
	if template != null:
		return template.player_spawn()
	return _size * 0.5

## Position just inside the given door (used when arriving from a neighbor).
## Pushed well past the door trigger area so arriving doesn't instantly re-trigger
## a transition.
func entry_point_for(side: String) -> Vector2:
	var c := _size * 0.5
	var inset := WALL_THICK + DOOR_HALF + 48.0
	match side:
		"N": return Vector2(c.x, inset)
		"S": return Vector2(c.x, _size.y - inset)
		"W": return Vector2(inset, c.y)
		"E": return Vector2(_size.x - inset, c.y)
	return c

# --- Construction ---
func _add_wall(rect: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = Collision.WORLD
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = rect.size
	shape.shape = rs
	shape.position = rect.position + rect.size * 0.5
	body.add_child(shape)
	add_child(body)
	return body

func _build_walls() -> void:
	var w := _size.x
	var h := _size.y
	var cx := w * 0.5
	var cy := h * 0.5
	# Each side: full wall, or two segments leaving a centered door gap.
	for side in ["N", "S", "E", "W"]:
		var has_door: bool = side in open_sides
		match side:
			"N":
				if has_door:
					_add_wall(Rect2(0, 0, cx - DOOR_HALF, WALL_THICK))
					_add_wall(Rect2(cx + DOOR_HALF, 0, w - (cx + DOOR_HALF), WALL_THICK))
				else:
					_add_wall(Rect2(0, 0, w, WALL_THICK))
			"S":
				if has_door:
					_add_wall(Rect2(0, h - WALL_THICK, cx - DOOR_HALF, WALL_THICK))
					_add_wall(Rect2(cx + DOOR_HALF, h - WALL_THICK, w - (cx + DOOR_HALF), WALL_THICK))
				else:
					_add_wall(Rect2(0, h - WALL_THICK, w, WALL_THICK))
			"W":
				if has_door:
					_add_wall(Rect2(0, 0, WALL_THICK, cy - DOOR_HALF))
					_add_wall(Rect2(0, cy + DOOR_HALF, WALL_THICK, h - (cy + DOOR_HALF)))
				else:
					_add_wall(Rect2(0, 0, WALL_THICK, h))
			"E":
				if has_door:
					_add_wall(Rect2(w - WALL_THICK, 0, WALL_THICK, cy - DOOR_HALF))
					_add_wall(Rect2(w - WALL_THICK, cy + DOOR_HALF, WALL_THICK, h - (cy + DOOR_HALF)))
				else:
					_add_wall(Rect2(w - WALL_THICK, 0, WALL_THICK, h))

func _build_obstacles() -> void:
	if template == null:
		return
	for y in template.grid.size():
		var row: String = template.grid[y]
		for x in row.length():
			if row[x] == "O":
				_add_wall(Rect2(x * TILE, y * TILE, TILE, TILE))

func _build_doors() -> void:
	for side in open_sides:
		var door := Area2D.new()
		door.collision_layer = 0
		door.collision_mask = Collision.PLAYER_BODY
		var shape := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = Vector2(DOOR_HALF * 2.0, DOOR_HALF * 2.0)
		shape.shape = rs
		door.add_child(shape)
		door.position = _door_position(side)
		door.body_entered.connect(_on_door_entered.bind(side))
		add_child(door)

func _door_position(side: String) -> Vector2:
	var c := _size * 0.5
	match side:
		"N": return Vector2(c.x, WALL_THICK)
		"S": return Vector2(c.x, _size.y - WALL_THICK)
		"W": return Vector2(WALL_THICK, c.y)
		"E": return Vector2(_size.x - WALL_THICK, c.y)
	return c

func _on_door_entered(_body: Node, side: String) -> void:
	if not locked:
		emit_signal("door_taken", side)

func _spawn_enemies(target: Node2D, pool: ProjectilePool) -> void:
	if biome == null:
		return
	var spawns: Array[Vector2] = []
	if template != null:
		spawns = template.enemy_spawns()
	# Decide how many enemies; use template markers if present, else biome range.
	var count: int
	if not spawns.is_empty():
		count = spawns.size()
	else:
		count = RNG.stream("spawn").randi_range(
			biome.enemies_per_room_min, biome.enemies_per_room_max)

	var pool_ids: Array = biome.enemy_pool
	if room_type == "boss":
		# Palier boss on earlier floors, the true boss on the final floor.
		var bid := RunManager.current_boss_id()
		if bid != "":
			pool_ids = [bid]
		count = 1
	elif room_type == "miniboss":
		if biome.miniboss_id != "":
			pool_ids = [biome.miniboss_id]
		count = 1
	elif room_type == "cursed":
		count += 1  # a curse: an extra foe guards the free loot

	for i in count:
		var id = RNG.pick("spawn", pool_ids)  # untyped: pick() may return null
		if id == null:
			continue
		var ed := GameData.get_entity(id)
		if ed == null:
			continue
		var e := Enemy.new()
		e.setup(ed, target, pool)
		if i < spawns.size():
			e.position = spawns[i]
		else:
			e.position = _random_floor_point()
		add_child(e)
		_alive_enemies += 1
		e.tree_exited.connect(_on_enemy_gone)

## Spawn an extra wave into an already-cleared room and re-lock the doors (used
## by a god's "wrath" encounter). Clearing it emits `cleared` again.
func spawn_wave(target: Node2D, pool: ProjectilePool, ids: Array, n: int) -> void:
	for i in n:
		var id = RNG.pick("encounter", ids)
		if id == null:
			continue
		var ed := GameData.get_entity(id)
		if ed == null:
			continue
		var e := Enemy.new()
		e.setup(ed, target, pool)
		e.position = _random_floor_point()
		add_child(e)
		_alive_enemies += 1
		e.tree_exited.connect(_on_enemy_gone)
	if _alive_enemies > 0:
		_lock()

func _random_floor_point() -> Vector2:
	var margin := WALL_THICK + 48.0
	var rng := RNG.stream("spawn")
	return Vector2(
		rng.randf_range(margin, _size.x - margin),
		rng.randf_range(margin, _size.y - margin))

func _spawn_pickups(priced: bool) -> void:
	if biome == null:
		return
	var pool := GameData.items_for(biome.pantheon)
	if pool.is_empty():
		return
	var anchors: Array[Vector2] = []
	if template != null:
		anchors = template.feature_anchors()
	if anchors.is_empty():
		anchors.append(_size * 0.5)
	for i in anchors.size():
		var item: ItemData = RNG.pick("loot", pool)
		if item == null:
			continue
		var p := Pickup.new()
		p.setup(item, _price_for(item) if priced else 0)
		p.position = anchors[i]
		add_child(p)

func _spawn_sacrifice() -> void:
	var anchors: Array[Vector2] = []
	if template != null:
		anchors = template.feature_anchors()
	var altar := SacrificeAltar.new()
	altar.position = anchors[0] if not anchors.is_empty() else _size * 0.5
	add_child(altar)

func _price_for(item: ItemData) -> int:
	match item.rarity:
		"cursed": return 5
		"common": return 8
		"rare": return 16
		"relic": return 28
		_: return 10

func _on_enemy_gone() -> void:
	_alive_enemies -= 1
	if _alive_enemies <= 0:
		_unlock()
		emit_signal("cleared")

# --- Locking ---
func _lock() -> void:
	locked = true
	for side in open_sides:
		_gates.append(_add_gate(side))
	queue_redraw()

func _unlock() -> void:
	locked = false
	for g in _gates:
		if is_instance_valid(g):
			g.queue_free()
	_gates.clear()
	queue_redraw()

func _add_gate(side: String) -> StaticBody2D:
	var pos := _door_position(side)
	var rect: Rect2
	if side == "N" or side == "S":
		rect = Rect2(pos.x - DOOR_HALF, pos.y - WALL_THICK * 0.5, DOOR_HALF * 2.0, WALL_THICK)
	else:
		rect = Rect2(pos.x - WALL_THICK * 0.5, pos.y - DOOR_HALF, WALL_THICK, DOOR_HALF * 2.0)
	return _add_wall(rect)

# --- Rendering (textures if present, else greybox) ---
func _draw() -> void:
	var w := _size.x
	var h := _size.y
	# Floor: a bespoke realm tile as-is, else a generic tile tinted by palette,
	# else solid colour. (One generic tileset thus serves all six realms.)
	var floor_tex := Sprites.tile(_pantheon, "floor")
	var floor_generic := floor_tex == null
	if floor_generic:
		floor_tex = Sprites.tile_generic("floor")
	if floor_tex != null:
		draw_texture_rect(floor_tex, Rect2(Vector2.ZERO, _size), true,
			_floor_color if floor_generic else Color.WHITE)
	else:
		draw_rect(Rect2(Vector2.ZERO, _size), _floor_color, true)
		draw_rect(Rect2(WALL_THICK, WALL_THICK, w - 2 * WALL_THICK, h - 2 * WALL_THICK),
			Color(_accent_color.r, _accent_color.g, _accent_color.b, 0.10), false, 3.0)
	# Walls.
	var wall_tex := Sprites.tile(_pantheon, "wall")
	var wall_generic := wall_tex == null
	if wall_generic:
		wall_tex = Sprites.tile_generic("wall")
	for r in [Rect2(0, 0, w, WALL_THICK), Rect2(0, h - WALL_THICK, w, WALL_THICK),
			Rect2(0, 0, WALL_THICK, h), Rect2(w - WALL_THICK, 0, WALL_THICK, h)]:
		if wall_tex != null:
			draw_texture_rect(wall_tex, r, true, _wall_color if wall_generic else Color.WHITE)
		else:
			draw_rect(r, _wall_color)
	# Obstacles.
	var obs_tex := Sprites.tile(_pantheon, "obstacle")
	var obs_generic := obs_tex == null
	if obs_generic:
		obs_tex = Sprites.tile_generic("obstacle")
	if template != null:
		for y in template.grid.size():
			var row: String = template.grid[y]
			for x in row.length():
				if row[x] == "O":
					var cell := Rect2(x * TILE, y * TILE, TILE, TILE)
					if obs_tex != null:
						draw_texture_rect(obs_tex, cell, true,
							_accent_color if obs_generic else Color.WHITE)
					else:
						draw_rect(cell, _accent_color)
	# Doors as accent marks.
	var door_col := _accent_color if not locked else Color(0.5, 0.4, 0.4)
	for side in open_sides:
		var p := _door_position(side)
		draw_circle(p, 10.0, door_col)
