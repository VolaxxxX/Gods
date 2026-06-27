class_name Room
extends Node2D
## A single playable room. Builds walls/obstacles/doors from a hand-authored
## RoomTemplate (or a default box if none), spawns enemies from the biome pool,
## and unlocks its doors when cleared. Greybox visuals are code-drawn.
##
## The run scene owns the floor graph and tells each room which sides have
## neighbors (open_sides). Walking into a door emits `door_taken(side)`.

const TILE := RoomTemplate.TILE_SIZE
const WALL_THICK := 28.0
const DOOR_HALF := 48.0   # half-width of a door gap

signal cleared
signal door_taken(side: String)

var template: RoomTemplate
var biome: BiomeData
var open_sides: Array[String] = []   # sides that connect to a neighbor
var secret_sides: Array[String] = [] # open sides whose neighbour is a secret room
var room_type: String = "combat"
var locked: bool = false

var _size: Vector2 = Vector2(13 * TILE, 9 * TILE)
var _alive_enemies: int = 0
var _gates: Array[StaticBody2D] = []
var _prop_marks: Array = []   # [foot_pos: Vector2, radius: float] for prop shadows
var _floor_color := Color(0.15, 0.15, 0.2)
var _wall_color := Color(0.35, 0.32, 0.28)
var _accent_color := Color(0.85, 0.7, 0.35)
var _pantheon := ""
var _floor_layer: TileMapLayer       # real tiled floor (variants); null = greybox
var _use_tilemap_floor := false

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

	_build_floor_tilemap()  # real TileMapLayer floor w/ variants (else greybox _draw)
	_build_walls()
	_build_obstacles()
	_build_doors()
	_scatter_props()
	# Drifting ambient particles (ember/dust/snow/petal) set the realm's mood.
	if biome != null:
		var pf := Atmosphere.ambient_particles(biome.ambient_particle, _size)
		if pf != null:
			add_child(pf)

	# Room-type contents.
	if room_type == "reward" or room_type == "shop" or room_type == "secret":
		_spawn_pickups(room_type == "shop")  # secret rooms = free loot for finding them
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

## World-space size of this room (for camera clamping).
func room_size() -> Vector2:
	return _size

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

## Build a real TileMapLayer floor from the realm's floor variants
## (<r>_floor / _floor_b / _floor_c, or their _alt on the post-mini-boss floor),
## placed with weighted random per cell to kill repetition. If no art exists the
## function bails and _draw() falls back to the greybox/single-tile floor.
func _build_floor_tilemap() -> void:
	var v2: bool = RunManager.floor_in_biome > 1
	# Base tile (the corrupted _alt on floor 2 if it exists, else the plain floor).
	var base: Texture2D = null
	if v2:
		base = Sprites.tile(_pantheon, "floor_alt")
	if base == null:
		base = Sprites.tile(_pantheon, "floor")
	if base == null:
		return  # no floor art -> greybox fallback in _draw()
	var variants: Array = [base]
	# Accent variants — used SPARINGLY (occasional wear, not a rash). On floor 2 we
	# only accept an accent that has its own _alt so it matches the corrupted base
	# (no plain-tile-on-ornate mismatch); otherwise that floor stays the uniform alt.
	for k in ["floor_b", "floor_c"]:
		var t: Texture2D = null
		if v2:
			t = Sprites.tile(_pantheon, k + "_alt")  # usually absent -> skip on floor 2
		else:
			t = Sprites.tile(_pantheon, k)
		if t != null:
			variants.append(t)

	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	var src_ids: Array[int] = []
	for tex in variants:
		var src := TileSetAtlasSource.new()
		src.texture = tex
		src.texture_region_size = Vector2i(tex.get_width(), tex.get_height())
		src.create_tile(Vector2i.ZERO)
		src_ids.append(ts.add_source(src))

	_floor_layer = TileMapLayer.new()
	_floor_layer.tile_set = ts
	_floor_layer.z_index = -2  # under the walls/vignette drawn by _draw()
	# Calm the busy base motif: slightly desaturate + dim the floor so the strong
	# per-tile borders recede and the (full-colour) entities/projectiles pop.
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\n" \
		+ "void fragment() {\n" \
		+ "\tvec4 c = texture(TEXTURE, UV);\n" \
		+ "\tfloat g = dot(c.rgb, vec3(0.299, 0.587, 0.114));\n" \
		+ "\tc.rgb = mix(vec3(g), c.rgb, 0.64);\n" \
		+ "\tc.rgb = pow(c.rgb, vec3(1.22)) * 0.64;\n" \
		+ "\tCOLOR = c;\n}"
	var mat := ShaderMaterial.new()
	mat.shader = sh
	_floor_layer.material = mat
	add_child(_floor_layer)

	var cols := int(ceil(_size.x / TILE))
	var rows := int(ceil(_size.y / TILE))
	for cy in rows:
		for cx in cols:
			var hsh := ((cx * 73856093) ^ (cy * 19349663)) & 255
			var vi := 0  # base ~90%; accents are rare, tasteful wear (~6% / ~4%)
			if src_ids.size() >= 3:
				vi = 1 if (hsh >= 230 and hsh < 245) else (2 if hsh >= 245 else 0)
			elif src_ids.size() == 2:
				vi = 1 if hsh >= 236 else 0
			_floor_layer.set_cell(Vector2i(cx, cy), src_ids[vi], Vector2i.ZERO)
	_use_tilemap_floor = true

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
			if _is_solid_cell(row, x, y):
				_add_wall(Rect2(x * TILE, y * TILE, TILE, TILE))

## A full-cell solid block: an 'O' obstacle, or an INTERIOR '#' (carved room
## shape — non-rectangular rooms). The outer border is built by _build_walls.
func _is_solid_cell(row: String, x: int, y: int) -> bool:
	var c := row[x]
	if c == "O":
		# Never let an obstacle seal a door mouth (would trap/soft-lock the player).
		var center := Vector2(x + 0.5, y + 0.5) * TILE
		return not _near_open_door(center, DOOR_HALF + TILE * 0.6)
	return c == "#" and x > 0 and x < row.length() - 1 and y > 0 and y < template.grid.size() - 1

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
		# Deferred: this fires inside the physics query flush (Area2D body_entered).
		# The handler rebuilds the room — creating Area2Ds whose monitoring state
		# can't be set mid-flush — so hand it off to idle time.
		emit_signal.call_deferred("door_taken", side)

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
	# Cap simultaneous mobs by room size so small rooms never get swarmed (keeps
	# space to dodge). Bosses/minibosses are exempt (always 1).
	if room_type in ["combat", "cursed"]:
		var cells := (_size.x / TILE) * (_size.y / TILE)
		var cap := 4 if cells < 130.0 else (6 if cells < 200.0 else 8)
		count = mini(count, cap)

	for i in count:
		var id = RNG.pick("spawn", pool_ids)  # untyped: pick() may return null
		if id == null:
			continue
		var ed := GameData.get_entity(id)
		if ed == null:
			continue
		var e := Enemy.new()
		e.setup(ed, target, pool, biome.difficulty if biome != null else 1.0)
		var pos: Vector2 = spawns[i] if i < spawns.size() else _random_floor_point()
		if _solid_at_px(pos):  # never spawn trapped in a wall/obstacle
			pos = _random_floor_point()
		e.position = pos
		add_child(e)
		_alive_enemies += 1
		e.tree_exited.connect(_on_enemy_gone)
		# Bosses/minibosses drive the on-screen boss health bar.
		if room_type in ["boss", "miniboss"]:
			Events.emit_signal("boss_spawned", e, ed.name_key)
			e.tree_exited.connect(func(): Events.emit_signal("boss_despawned"))

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
		e.setup(ed, target, pool, biome.difficulty if biome != null else 1.0)
		e.position = _random_floor_point()
		add_child(e)
		_alive_enemies += 1
		e.tree_exited.connect(_on_enemy_gone)
	if _alive_enemies > 0:
		_lock()

func _random_floor_point() -> Vector2:
	var margin := WALL_THICK + 48.0
	var rng := RNG.stream("spawn")
	# Retry so a spawn never lands inside an obstacle or a door mouth.
	for _i in 16:
		var p := Vector2(rng.randf_range(margin, _size.x - margin),
			rng.randf_range(margin, _size.y - margin))
		if not _solid_at_px(p) and not _near_open_door(p, DOOR_HALF + 24.0):
			return p
	# Guaranteed fallback: scan the grid for ANY open floor cell so an enemy can
	# NEVER spawn trapped in a wall (which would leave the room un-clearable).
	var y := margin
	while y < _size.y - margin:
		var x := margin
		while x < _size.x - margin:
			var pp := Vector2(x, y)
			if not _solid_at_px(pp):
				return pp
			x += TILE
		y += TILE
	return _size * 0.5

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

## Scatter a FEW relevant decorative props (hugging walls/corners). Capped per
## room so maps stay readable — quality over quantity.
## Inert until the biome lists props AND the prop PNGs exist.
func _scatter_props() -> void:
	_prop_marks.clear()
	if biome == null or biome.props.is_empty():
		return
	# Keep it sparse: a few in small rooms, a few more in large arenas.
	var cells := (_size.x / TILE) * (_size.y / TILE)
	var cap := 5 if cells < 150.0 else (7 if cells < 220.0 else 9)

	# Candidate spots: authored 'D' anchors if present (designed/symmetric), else a
	# tidy ring of spots flush to the walls.
	var spots: Array[Vector2] = []
	if template != null:
		spots = template.decor_anchors()
	if spots.is_empty():
		var ins := WALL_THICK + 16.0
		var step := 150.0
		var lx := ins + 40.0
		while lx < _size.x - ins - 30.0:
			spots.append(Vector2(lx, ins + 30.0))
			spots.append(Vector2(lx, _size.y - ins))
			lx += step
		var ly := ins + 70.0
		while ly < _size.y - ins - 40.0:
			spots.append(Vector2(ins + 16.0, ly))
			spots.append(Vector2(_size.x - ins - 16.0, ly))
			ly += step

	# Keep only valid spots, then prefer the ones nearest a corner (the most
	# "pertinent" prop spots — big columns/braziers frame the room), up to the cap.
	var valid: Array[Vector2] = []
	for pos in spots:
		if _prop_ok(pos):
			valid.append(pos)
	valid.sort_custom(func(a, b): return _corner_dist(a) < _corner_dist(b))

	var n: int = mini(cap, valid.size())
	for i in n:
		# Re-check vs already-placed props (a prop just placed updates _prop_marks).
		if not _prop_ok(valid[i]):
			continue
		var big: bool = _corner_dist(valid[i]) < TILE * 1.2  # corner pieces read larger
		_place_prop(biome.props[i % biome.props.size()], valid[i], TILE * (1.2 if big else 1.05))

## Distance from a point to the nearest interior room corner.
func _corner_dist(pos: Vector2) -> float:
	var m := WALL_THICK
	var corners := [Vector2(m, m), Vector2(_size.x - m, m),
		Vector2(m, _size.y - m), Vector2(_size.x - m, _size.y - m)]
	var best := 1e20
	for c in corners:
		best = minf(best, pos.distance_to(c))
	return best

## Instantiate one decorative prop: foot-anchored, scaled, with a shadow mark.
func _place_prop(id: String, pos: Vector2, target: float) -> void:
	var tex := Sprites.prop(id)
	if tex == null:
		return
	var s := Sprite2D.new()
	s.texture = tex
	var dim: float = maxf(tex.get_width(), tex.get_height())
	if dim > 0.0:
		s.scale = Vector2.ONE * (target / dim)
	# Anchor by the bottom of the OPAQUE box (not the padded frame) so props sit on
	# the floor instead of hovering above their transparent padding.
	s.offset = Vector2(0, -Sprites.content_bottom(tex))
	s.position = pos
	add_child(s)
	_prop_marks.append([pos, target * 0.40])
	# Braziers / torches / lanterns cast a warm flickering glow.
	if Atmosphere.is_light_prop(id):
		var l := Atmosphere.point_light(Color(1.0, 0.7, 0.35), 0.9, 170.0)
		l.position = pos + Vector2(0, -target * 0.25)
		add_child(l)

## True if a point sits in front of an OPEN door (so we don't decorate/block it).
func _near_open_door(pos: Vector2, radius: float = DOOR_HALF + 40.0) -> bool:
	for side in open_sides:
		if pos.distance_to(_door_position(side)) < radius:
			return true
	return false

## Is this world point inside a solid obstacle/carved-wall cell?
func _solid_at_px(pos: Vector2) -> bool:
	if template == null:
		return false
	var cx := int(pos.x / TILE)
	var cy := int(pos.y / TILE)
	if cy < 0 or cy >= template.grid.size():
		return false
	var row: String = template.grid[cy]
	if cx < 0 or cx >= row.length():
		return false
	return _is_solid_cell(row, cx, cy)

## Too close to an enemy or the player spawn (props must never cover a spawn).
func _near_spawn(pos: Vector2) -> bool:
	if template == null:
		return false
	for s in template.enemy_spawns():
		if pos.distance_to(s) < TILE * 0.85:
			return true
	return pos.distance_to(template.player_spawn()) < TILE * 0.85

## A prop may sit here: clear of doors, solid cells, spawns, and other props.
func _prop_ok(pos: Vector2) -> bool:
	if _near_open_door(pos) or _solid_at_px(pos) or _near_spawn(pos):
		return false
	for m in _prop_marks:
		if pos.distance_to(m[0]) < TILE * 0.8:
			return false
	return true

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

# --- Rendering (textures if present, else greybox). Floor 2 of a zone (after the
# palier/mini-boss) uses each tile's "_alt" variant, or a darkened base. ---
func _draw() -> void:
	var w := _size.x
	var h := _size.y
	# Floor. A real TileMapLayer (variants) draws it when art exists; otherwise the
	# greybox single-tile / flat fill + grout grid is the fallback.
	if not _use_tilemap_floor:
		var fr := _tile("floor", _floor_color)
		if fr[0] != null:
			draw_texture_rect(fr[0], Rect2(Vector2.ZERO, _size), true, _dim(fr[1], 0.85))
		else:
			draw_rect(Rect2(Vector2.ZERO, _size), fr[1], true)
			draw_rect(Rect2(WALL_THICK, WALL_THICK, w - 2 * WALL_THICK, h - 2 * WALL_THICK),
				Color(_accent_color.r, _accent_color.g, _accent_color.b, 0.10), false, 3.0)
		_draw_floor_variation(w, h)
		_draw_floor_grid(w, h)  # crisp grout seams = a real tiled floor
	# Soft shadows under perimeter props (props are child sprites drawn after this).
	for mark in _prop_marks:
		draw_set_transform(mark[0], 0.0, Vector2(1.0, 0.4))
		draw_circle(Vector2.ZERO, mark[1], Color(0, 0, 0, 0.26))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Walls — drawn distinctly DARKER than the floor so the (possibly non-rect)
	# shape always reads, even when a realm's wall/floor palettes are close (Greece).
	var wr := _tile("wall", _wall_color)
	for r in [Rect2(0, 0, w, WALL_THICK), Rect2(0, h - WALL_THICK, w, WALL_THICK),
			Rect2(0, 0, WALL_THICK, h), Rect2(w - WALL_THICK, 0, WALL_THICK, h)]:
		if wr[0] != null:
			draw_texture_rect(wr[0], r, true, _dim(wr[1], 0.55))
		else:
			draw_rect(r, _dim(wr[1], 0.7))
	# Depth: bright top bevel on the outer rim + a tall dark "front face" under the
	# top wall + a soft drop shadow cast by every wall onto the floor.
	var bevel := Color(1, 1, 1, 0.10)
	draw_rect(Rect2(0, 0, w, 3.0), bevel)
	draw_rect(Rect2(0, 0, 3.0, h), bevel)
	draw_rect(Rect2(0, WALL_THICK, w, 12.0), Color(0, 0, 0, 0.28))         # front face
	for sh in [Rect2(WALL_THICK, WALL_THICK + 12.0, w - 2 * WALL_THICK, 12.0),  # under N
			Rect2(WALL_THICK, h - WALL_THICK - 12.0, w - 2 * WALL_THICK, 12.0),  # over S
			Rect2(WALL_THICK, WALL_THICK, 12.0, h - 2 * WALL_THICK),             # right of W
			Rect2(w - WALL_THICK - 12.0, WALL_THICK, 12.0, h - 2 * WALL_THICK)]: # left of E
		draw_rect(sh, Color(0, 0, 0, 0.14))
	# A lit lip along the wall's inner edge (where wall meets floor) reads as the
	# top surface of a raised wall, all the way around.
	var lip := Color(1, 1, 1, 0.12)
	draw_rect(Rect2(WALL_THICK, WALL_THICK - 3.0, w - 2 * WALL_THICK, 3.0), lip)        # N
	draw_rect(Rect2(WALL_THICK, h - WALL_THICK, w - 2 * WALL_THICK, 3.0), lip)          # S
	draw_rect(Rect2(WALL_THICK - 3.0, WALL_THICK, 3.0, h - 2 * WALL_THICK), lip)        # W
	draw_rect(Rect2(w - WALL_THICK, WALL_THICK, 3.0, h - 2 * WALL_THICK), lip)          # E
	# Darker corner blocks for a built, masonry feel.
	var corner := _dim(_wall_color, 0.4)
	var cs := WALL_THICK
	for cpos in [Vector2(0, 0), Vector2(w - cs, 0), Vector2(0, h - cs), Vector2(w - cs, h - cs)]:
		draw_rect(Rect2(cpos, Vector2(cs, cs)), Color(corner.r, corner.g, corner.b, 0.5))
	# Bespoke wall art (front face + corner pieces) when the realm provides it —
	# real depth instead of the flat procedural lip. Falls back silently if absent.
	var face := Sprites.tile(_pantheon, "wall_face")
	if face != null:
		draw_texture_rect(face, Rect2(WALL_THICK, WALL_THICK, w - 2 * WALL_THICK, 22.0), true)
	var wcorner := Sprites.tile(_pantheon, "wall_corner")
	if wcorner != null:
		for cpos in [Vector2(0, 0), Vector2(w - cs, 0), Vector2(0, h - cs), Vector2(w - cs, h - cs)]:
			draw_texture_rect(wcorner, Rect2(cpos, Vector2(cs, cs)), false)
	# Obstacles ('O') and carved interior walls ('#') — both full cells, with a top
	# bevel + drop shadow so they read as solid blocks, not flat squares.
	var ob := _tile("obstacle", _accent_color)
	var wl := _tile("wall", _wall_color)
	if template != null:
		for y in template.grid.size():
			var row: String = template.grid[y]
			for x in row.length():
				if not _is_solid_cell(row, x, y):
					continue
				var cell := Rect2(x * TILE, y * TILE, TILE, TILE)
				draw_rect(Rect2(cell.position + Vector2(4, TILE - 1), Vector2(TILE, 9)),
					Color(0, 0, 0, 0.26))  # drop shadow below the block
				var is_wall_cell := row[x] == "#"
				var t: Array = wl if is_wall_cell else ob
				var mod: Color = _dim(t[1], 0.55) if is_wall_cell else _dim(t[1], 0.9)
				if t[0] != null:
					draw_texture_rect(t[0], cell, true, mod)
				else:
					draw_rect(cell, mod)
				# Raised look: lit top third + dark base edge.
				draw_rect(Rect2(cell.position, Vector2(TILE, TILE * 0.34)), Color(1, 1, 1, 0.10))
				draw_rect(Rect2(cell.position, Vector2(TILE, 2.5)), Color(1, 1, 1, 0.18))
				draw_rect(Rect2(cell.position + Vector2(0, TILE - 4.0), Vector2(TILE, 4.0)), Color(0, 0, 0, 0.28))
	# Inner shadow band -> depth + focuses the eye on the centre (cheap vignette).
	for band in [[0.0, 0.22], [9.0, 0.13], [18.0, 0.07], [30.0, 0.04]]:
		var o: float = WALL_THICK + band[0]
		draw_rect(Rect2(o, o, w - 2.0 * o, h - 2.0 * o), Color(0, 0, 0, band[1]), false, 9.0)
	# Doorways: a framed arch in the accent colour (locked = dim red gate).
	for side in open_sides:
		_draw_doorway(side)

## Camouflage a secret room's entrance as a cracked wall segment: it fills the
## doorway like wall (the gap is still walkable), with faint cracks as a hint that
## an observant player can spot and walk through.
func _draw_secret_door(rect: Rect2, horizontal: bool) -> void:
	var wcol := _dim(_wall_color, 0.55)
	var wr := _tile("wall", _wall_color)
	if wr[0] != null:
		draw_texture_rect(wr[0], rect, true, _dim(wr[1], 0.55))
	else:
		draw_rect(rect, wcol)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 3) if horizontal else Vector2(3, rect.size.y)),
		Color(1, 1, 1, 0.08))  # faint top/edge bevel like the rest of the wall
	# A few hairline cracks (subtle hint).
	var c := rect.get_center()
	var crack := Color(0.0, 0.0, 0.0, 0.35)
	draw_line(c + Vector2(-10, -8), c + Vector2(-2, 2), crack, 1.5)
	draw_line(c + Vector2(-2, 2), c + Vector2(6, -4), crack, 1.5)
	draw_line(c + Vector2(6, -4), c + Vector2(12, 6), crack, 1.5)
	draw_line(c + Vector2(2, 0), c + Vector2(4, 10), crack, 1.0)

## Thin grout seams on the tile grid + a faint highlight, so the floor reads as
## laid tiles (matching the reference look) rather than one stretched texture.
func _draw_floor_grid(w: float, h: float) -> void:
	var seam := Color(0, 0, 0, 0.11)
	var lip := Color(1, 1, 1, 0.04)
	var x := WALL_THICK + TILE
	while x < w - WALL_THICK:
		draw_line(Vector2(x, WALL_THICK), Vector2(x, h - WALL_THICK), seam, 1.0)
		draw_line(Vector2(x + 1, WALL_THICK), Vector2(x + 1, h - WALL_THICK), lip, 1.0)
		x += TILE
	var y := WALL_THICK + TILE
	while y < h - WALL_THICK:
		draw_line(Vector2(WALL_THICK, y), Vector2(w - WALL_THICK, y), seam, 1.0)
		draw_line(Vector2(WALL_THICK, y + 1), Vector2(w - WALL_THICK, y + 1), lip, 1.0)
		y += TILE

## Deterministic faint light/dark patches over the floor cells (anti-repetition).
func _draw_floor_variation(w: float, h: float) -> void:
	var cols := int(ceil(w / TILE))
	var rows := int(ceil(h / TILE))
	for cy in rows:
		for cx in cols:
			var px := cx * TILE
			var py := cy * TILE
			# Skip the wall ring (variation only on walkable floor).
			if px < WALL_THICK or py < WALL_THICK \
					or px > w - WALL_THICK - TILE or py > h - WALL_THICK - TILE:
				continue
			var hsh := ((cx * 73856093) ^ (cy * 19349663)) & 255
			var cell := Rect2(px, py, TILE, TILE)
			if hsh < 40:
				draw_rect(cell, Color(0, 0, 0, 0.07))
			elif hsh > 224:
				draw_rect(cell, Color(1, 1, 1, 0.05))

## A doorway frame in the wall gap: an arched opening (accent), red gate if locked.
## A side leading to a SECRET room is camouflaged as a cracked wall instead.
func _draw_doorway(side: String) -> void:
	var p := _door_position(side)
	var horizontal := side == "N" or side == "S"
	var rect: Rect2
	if horizontal:
		rect = Rect2(p.x - DOOR_HALF, p.y - WALL_THICK * 0.5, DOOR_HALF * 2.0, WALL_THICK)
	else:
		rect = Rect2(p.x - WALL_THICK * 0.5, p.y - DOOR_HALF, WALL_THICK, DOOR_HALF * 2.0)
	if side in secret_sides:
		_draw_secret_door(rect, horizontal)
		return
	# Bespoke door/arch sprite if the realm provides one (centred on the opening),
	# tinted red while locked; else the drawn frame below.
	var door_tex := Sprites.tile(_pantheon, "door")
	if door_tex != null:
		var ds := DOOR_HALF * 2.0 + 16.0
		var dr := Rect2(p - Vector2(ds, ds) * 0.5, Vector2(ds, ds))
		draw_rect(rect, Color(0.05, 0.04, 0.06, 0.9))  # dark threshold behind it
		draw_texture_rect(door_tex, dr, false,
			Color(1, 0.6, 0.55) if locked else Color.WHITE)
		return
	var col := _accent_color if not locked else Color(0.55, 0.32, 0.30)
	# Dark threshold, bright frame.
	draw_rect(rect, Color(0.05, 0.04, 0.06, 0.9))
	draw_rect(rect, Color(col.r, col.g, col.b, 0.9), false, 3.0)
	if locked:
		# Barred gate.
		for i in range(1, 4):
			if horizontal:
				var gx := rect.position.x + rect.size.x * i / 4.0
				draw_line(Vector2(gx, rect.position.y), Vector2(gx, rect.end.y), col, 2.0)
			else:
				var gy := rect.position.y + rect.size.y * i / 4.0
				draw_line(Vector2(rect.position.x, gy), Vector2(rect.end.x, gy), col, 2.0)

## Returns [Texture2D|null, modulate] for a tile kind. On the zone's 2nd floor
## (post mini-boss) it uses the bespoke "<biome>_<kind>_alt.png" variant if it
## exists, else falls back to the base art / palette darkened to read as corrupted.
func _tile(kind: String, palette_col: Color) -> Array:
	var v2: bool = RunManager.floor_in_biome > 1
	if v2:
		var alt := Sprites.tile(_pantheon, kind + "_alt")
		if alt != null:
			return [alt, Color.WHITE]
	var bespoke := Sprites.tile(_pantheon, kind)
	if bespoke != null:
		return [bespoke, _variant_tint(Color.WHITE) if v2 else Color.WHITE]
	var generic := Sprites.tile_generic(kind)
	var col: Color = _variant_tint(palette_col) if v2 else palette_col
	if generic != null:
		return [generic, col]
	return [null, col]

## Multiply a colour's RGB (keep alpha) — used to dim floor/walls so entities pop.
func _dim(c: Color, f: float) -> Color:
	return Color(c.r * f, c.g * f, c.b * f, c.a)

## Darken/shift toward a corrupted look (fallback when no "_alt" art exists yet).
func _variant_tint(c: Color) -> Color:
	return Color(c.r * 0.72, c.g * 0.6, c.b * 0.82)
