extends Node2D
## Orchestrates a run: generates the floor, spawns the player + projectile pool,
## builds one room at a time, handles door transitions, and ends the run on
## death (-> hub) or boss kill (-> victory). One Room is live at a time; the
## player and pool persist across rooms as children of this scene.

const OPPOSITE := {"N": "S", "S": "N", "E": "W", "W": "E"}

var graph: FloorGraph
var biome: BiomeData
var pool: ProjectilePool
var player: Player
var camera: Camera2D
var current_room: Room
var current_pos: Vector2i = Vector2i.ZERO
var _cleared: Dictionary = {}   # Vector2i -> true
var _ended: bool = false
var _room_damage_taken: bool = false  # for the "cautious" play-style tally
var _wrath_active: bool = false       # a god's wrath wave is in progress
var _char_intro_done: bool = false    # the chosen character's intro line (once per run)
var _canvas_mod: CanvasModulate       # per-realm mood lighting
var _post_fx: PostFX                  # full-screen grade + vignette + grain
var _minimap: Minimap

func _ready() -> void:
	# Start a fresh run if one isn't already active (e.g. launched directly).
	if not RunManager.active:
		RunManager.start_run(RNG.get_seed() if RNG.get_seed() != 0 else randi(), "greece")

	# One-time scene objects (persist across biomes within a run).
	pool = ProjectilePool.new()
	add_child(pool)

	player = Player.new()
	add_child(player)
	player.set_pool(pool)
	player.health.damaged.connect(func(_a, _c, _m): _room_damage_taken = true)

	# Rooms are (re)created after the player/pool, so without explicit z_index the
	# room floor would draw OVER them. Lift player and projectiles above it.
	pool.z_index = 10
	player.z_index = 20

	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	# Zoom in so the arena fills the screen instead of floating small in the
	# 1280x720 viewport. At 1.6x the camera is tight: you DON'T see the whole
	# (now larger) room at once — you move to explore it. More immersive on phones.
	# Tight zoom (mobile): the player is big and dead-centre, the view stays full
	# of action (not "creux"), and combat rooms are larger than the view so the
	# centred camera shows no void.
	camera.zoom = Vector2(2.0, 2.0)
	player.add_child(camera)
	camera.make_current()

	# Mood lighting: a per-realm CanvasModulate tints the world; a warm light pools
	# around the player so the hero is lit (a focal spotlight) and always readable
	# in the gloom. Pure code.
	_canvas_mod = CanvasModulate.new()
	add_child(_canvas_mod)
	var glow := Atmosphere.point_light(Color(1.0, 0.92, 0.78), 0.95, 300.0)
	player.add_child(glow)
	# A wide, dim, cool FILL light (key + fill) lifts the rest of the room out of
	# pitch black so foes on the far side stay readable, without flattening the
	# warm focal pool or the cinematic mood.
	var fill := Atmosphere.point_light(Color(0.62, 0.68, 0.82), 0.32, 720.0)
	player.add_child(fill)

	Events.entity_died.connect(_on_entity_died)
	Events.boss_spawned.connect(_on_boss_zoom)
	Events.boss_despawned.connect(func(): _zoom_to(2.0))

	# UI overlays (screen space).
	var hud := HUD.new()
	hud.player = player   # for the dash indicator
	add_child(hud)
	var ui_layer := CanvasLayer.new()
	ui_layer.layer = 5
	add_child(ui_layer)
	ui_layer.add_child(TouchControls.new())
	add_child(PauseMenu.new())
	# Floor minimap (top-right), refreshed on each room entry.
	var map_layer := CanvasLayer.new()
	map_layer.layer = 11
	add_child(map_layer)
	_minimap = Minimap.new()
	map_layer.add_child(_minimap)

	# Full-screen post-processing (sits above the world, below the HUD/touch UI).
	_post_fx = PostFX.new()
	add_child(_post_fx)

	_setup_biome(RunManager.resuming)

## (Re)build the floor for the current biome and enter its start room. Called on
## run start, on resume, and each time the player descends into a new realm.
func _setup_biome(from_resume: bool) -> void:
	biome = GameData.get_biome(RunManager.biome_id)
	if biome == null:
		push_error("RunScene: unknown biome '%s'" % RunManager.biome_id)
		return
	if _canvas_mod != null:
		_canvas_mod.color = biome.ambient.darkened(0.14)
	if _post_fx != null:
		_post_fx.grade(RunManager.biome_id)
	# Deep realm-tinted background so the area beyond the room walls (now visible
	# with the player kept centred) reads as surrounding darkness, not black void.
	RenderingServer.set_default_clear_color(biome.ambient.darkened(0.80))

	_cleared.clear()
	if pool != null:
		pool.deactivate_all()
	graph = FloorGenerator.new().generate(biome)
	current_pos = graph.start_pos

	# Resume: restore cleared rooms and start at the saved room (floor is
	# regenerated deterministically from the seed, so coordinates still map).
	if from_resume:
		for c in RunManager.resume_cleared:
			if c.size() >= 2:
				_cleared[Vector2i(int(c[0]), int(c[1]))] = true
		if graph.has(RunManager.resume_room_coords):
			current_pos = RunManager.resume_room_coords
		RunManager.resuming = false

	_enter_room(current_pos, "")

	# Arriving in a NEW realm (its first floor): the narrator teaches its myth and
	# its lord greets you. Plays in the safe start room; lore is told once, then a
	# short flavour line on later visits. Skipped on floor regen and on resume.
	if not from_resume and RunManager.floor_in_biome == 1:
		# On the very first descent of the run, the Ferryman sizes up the chosen
		# soul (queues before the realm's lore, so it plays first).
		if not _char_intro_done:
			_char_intro_done = true
			Dialogue.speak("narrator", RunManager.character_id)
		var b := RunManager.biome_id
		Dialogue.speak("narrator", "enter_" + b)
		var god: String = REALM_LORDS.get(b, "")
		if god != "":
			Dialogue.speak(god, "enter_" + b)

func _enter_room(pos: Vector2i, from_side: String) -> void:
	if current_room != null:
		current_room.queue_free()
		current_room = null

	var node := graph.get_node(pos)
	var open: Array[String] = []
	var secret: Array[String] = []   # sides whose neighbour is a hidden secret room
	for side in node["neighbors"].keys():
		open.append(side)
		var npos: Vector2i = node["neighbors"][side]
		if graph.has(npos) and graph.get_node(npos)["type"] == "secret":
			secret.append(side)

	var template: RoomTemplate = null
	if node["template_id"] != "":
		template = GameData.get_room(node["template_id"])
	var already: bool = _cleared.has(pos)

	current_room = Room.new()
	add_child(current_room)
	current_room.door_taken.connect(_on_door_taken)
	current_room.cleared.connect(_on_room_cleared.bind(pos, node["type"]))

	_room_damage_taken = false

	# Build. If already cleared, build it EMPTY ("cleared" matches no content rule)
	# so re-entering never re-spawns loot (the floating orb bug) or enemies.
	var build_type: String = node["type"] if not already else "cleared"
	current_room.secret_sides = secret
	current_room.build(template, biome, open, build_type, player, pool)

	# Mobile-friendly framing: keep the player dead-centre and let the camera
	# follow them everywhere (no room clamp). The deep realm-dark clear colour
	# (set per biome) makes the area beyond the walls read as surrounding
	# darkness rather than a void.
	if camera != null:
		camera.limit_left = -10000000
		camera.limit_top = -10000000
		camera.limit_right = 10000000
		camera.limit_bottom = 10000000
		camera.reset_smoothing()

	# Place the player: at the door we came through, else the room's spawn.
	if from_side != "":
		player.global_position = current_room.entry_point_for(from_side)
	else:
		player.global_position = current_room.player_spawn_point()
	player.velocity = Vector2.ZERO

	Events.emit_signal("room_entered", current_room)
	if _minimap != null:
		_minimap.set_map(graph, current_pos, _cleared)
	_save_progress()

	# First-visit flavour for the special rooms (toasts, so they never block the
	# shopping / pact UI). `build_type` is "reward" once a room is cleared, so these
	# only fire the first time the room is its true self.
	match build_type:
		"shop":
			Dialogue.speak("shade", "shop")
		"challenge":
			Dialogue.speak("narrator", "sacrifice")
		"altar":
			Dialogue.speak("narrator", "altar")

	# Altars offer a divine pact on first visit.
	if build_type == "altar":
		_offer_blessing()

## Up to `n` random not-yet-owned blessings of the current pantheon.
func _blessing_options(n: int) -> Array:
	var avail: Array = []
	for b in GameData.blessings_for(biome.pantheon):
		if not (b.id in RunManager.chosen_blessings):
			avail.append(b)
	RNG.shuffle("blessing", avail)
	return avail.slice(0, mini(n, avail.size()))

func _offer_blessing() -> void:
	var opts := _blessing_options(3)
	if opts.is_empty():
		return
	var ui := BlessingChoice.new()
	ui.setup(opts)
	ui.chosen.connect(func(id): RunManager.add_blessing(id))
	add_child(ui)

func _on_door_taken(side: String) -> void:
	var node := graph.get_node(current_pos)
	if not node["neighbors"].has(side):
		return
	var next: Vector2i = node["neighbors"][side]
	current_pos = next
	_enter_room(next, OPPOSITE[side])

func _on_room_cleared(pos: Vector2i, type: String) -> void:
	var first := not _cleared.has(pos)
	if first:
		RunManager.rooms_cleared_count += 1
		# Clearing a fight unscathed reads as a cautious soul.
		if type in ["combat", "boss", "miniboss"] and not _room_damage_taken:
			RunManager.add_style("cautious")
		# Lingering vigor: clearing a combat room sometimes restores a little health
		# (Isaac-style heart drop) so a floor isn't pure attrition.
		if type == "combat" and player != null and player.health.fraction() < 1.0 \
				and RNG.stream("heal").randf() < 0.33:
			player.health.heal(2.0)
			Audio.play_sfx("pickup")
	_cleared[pos] = true
	if _minimap != null:
		_minimap.set_map(graph, current_pos, _cleared)
	Events.emit_signal("room_cleared", current_room)

	if type == "boss" and not _ended:
		# Palier boss -> pick one of 2 doors, then deeper into the SAME zone; final
		# boss -> next realm/win (RealmChoice).
		if RunManager.is_final_floor():
			_complete_biome()
		else:
			_offer_doors()
		return
	# A god's wrath wave just ended -> reward.
	if _wrath_active:
		_wrath_active = false
		_grant_wrath_reward()
		return
	# On first clearing a combat room, a god of the realm may appear (Hades-style).
	if first and type == "combat":
		_roll_god_encounter()

## Random roaming-god event after clearing a combat room: a boon choice, a wrath
## fight, or nothing.
func _roll_god_encounter() -> void:
	var r := RNG.stream("encounter").randf()
	if r < 0.30:
		_offer_boon()
	elif r < 0.40:
		_trigger_wrath()

func _offer_boon() -> void:
	var opts := _blessing_options(2)
	if opts.is_empty():
		return
	# Stage it: the Ferryman announces the god's appearance, THEN the gift is
	# offered (the chosen god then speaks via the normal "boon" line).
	if Dialogue.speak("narrator", "god_encounter"):
		Dialogue.queue_empty.connect(_show_boon_offer.bind(opts), CONNECT_ONE_SHOT)
	else:
		_show_boon_offer(opts)

func _show_boon_offer(opts: Array) -> void:
	var ui := BlessingChoice.new()
	ui.setup(opts, "ui.god_favor")
	ui.chosen.connect(func(id): RunManager.add_blessing(id))
	add_child(ui)

func _trigger_wrath() -> void:
	if current_room == null:
		return
	# A god's patience snaps: announce it, then unleash the wave.
	if Dialogue.speak("narrator", "wrath"):
		Dialogue.queue_empty.connect(_spawn_wrath_wave, CONNECT_ONE_SHOT)
	else:
		_spawn_wrath_wave()

func _spawn_wrath_wave() -> void:
	if current_room == null:
		return
	_wrath_active = true
	current_room.spawn_wave(player, pool, biome.enemy_pool, 3)

func _grant_wrath_reward() -> void:
	RunManager.add_gold(25)
	var items := GameData.items_for(biome.pantheon)
	var it = RNG.pick("encounter", items)
	if it != null:
		RunManager.add_item(it.id)

# The realm god who comments when that zone's boss falls.
const REALM_LORDS := {
	"greece": "greece_zeus", "bali": "bali_acintya", "egypt": "egypt_osiris",
	"norse": "norse_odin", "japan": "japan_amaterasu", "aztec": "aztec_mictlantecuhtli",
}

## Boss down: narrator + realm god comment on its fall, THEN win or branch on.
func _complete_biome() -> void:
	# Beating a zone's true boss conquers that realm (drives the meta goal).
	SaveManager.record_realm_cleared(RunManager.biome_id)
	# All six conquered ever -> unlock the true ending beat (shown next at the hub).
	if SaveManager.realms_cleared().size() >= 6:
		SaveManager.set_flag("all_six")
	var b := RunManager.biome_id
	var shown := Dialogue.speak("narrator", "boss_" + b)
	var god: String = REALM_LORDS.get(b, "")
	if god != "":
		shown = Dialogue.speak(god, "boss_" + b) or shown
	# A mythological reminder + moral, last in the queue.
	shown = Dialogue.speak("narrator", "moral_" + b) or shown
	if shown:
		Dialogue.queue_empty.connect(_after_boss, CONNECT_ONE_SHOT)
	else:
		_after_boss()

func _after_boss() -> void:
	# The true ending: all six underworlds have now been conquered (ever). Play the
	# cinematic once, instead of the ordinary victory return.
	if SaveManager.has_flag("all_six") and not SaveManager.has_flag("ending_played"):
		SaveManager.set_flag("ending_played")
		_ended = true
		RunManager.end_run(true)
		SceneRouter.goto_ending()
		return
	if RunManager.is_final_biome():
		_victory_ending()
		return
	var opts: Array = []
	for id in RunManager.realms_remaining():
		var b := GameData.get_biome(id)
		if b != null:
			opts.append(b)
	if opts.is_empty():
		_victory_ending()
		return
	var ui := RealmChoice.new()
	ui.setup(opts)
	ui.chosen.connect(_on_realm_chosen)
	add_child(ui)

func _on_realm_chosen(next_biome: String) -> void:
	player.health.heal(player.health.max_health * 0.5)  # reward for the descent
	RunManager.advance_to_biome(next_biome)
	_setup_biome(false)

## Palier boss down: present TWO doors (Hades-style) previewing their reward; the
## chosen reward is applied, then descend into a fresh map of the SAME zone.
func _offer_doors() -> void:
	# The palier (mini-boss) has fallen: narrator + realm god mark it, THEN the
	# two reward doors appear.
	var b := RunManager.biome_id
	var shown := Dialogue.speak("narrator", "miniboss_" + b)
	var god: String = REALM_LORDS.get(b, "")
	if god != "":
		shown = Dialogue.speak(god, "miniboss_" + b) or shown
	# A mythological reminder + moral for the palier creature, last in the queue.
	shown = Dialogue.speak("narrator", "moral_mini_" + b) or shown
	if shown:
		Dialogue.queue_empty.connect(_show_doors, CONNECT_ONE_SHOT)
	else:
		_show_doors()

func _show_doors() -> void:
	var kinds := ["treasure", "boon", "vigor"]
	RNG.shuffle("door", kinds)
	var ui := DoorChoice.new()
	ui.setup(kinds.slice(0, 2))
	ui.chosen.connect(_on_door_chosen)
	add_child(ui)

func _on_door_chosen(kind: String) -> void:
	match kind:
		"treasure":
			RunManager.add_gold(30)
			var it = RNG.pick("door", GameData.items_for(biome.pantheon))
			if it != null:
				RunManager.add_item(it.id)
		"boon":
			var opts := _blessing_options(1)
			if not opts.is_empty():
				RunManager.add_blessing(opts[0].id)
		"vigor":
			player.health.heal(player.health.max_health)  # full heal through the door
	_next_floor()

## A new map of the SAME zone (regenerated layout), keeping everything. A door
## reward was already granted; still top up a little so the descent feels safe.
func _next_floor() -> void:
	player.health.heal(player.health.max_health * 0.2)
	RunManager.advance_floor()
	_setup_biome(false)

func _on_entity_died(entity) -> void:
	if entity == player and not _ended:
		_ended = true
		# The death beat: a full-screen epitaph, then back to the shore (hub).
		var ds := DeathScreen.new()
		ds.continued.connect(func():
			RunManager.end_run(false)
			SceneRouter.goto_hub())
		add_child(ds)

## A won run ends on a realm-themed ending cinematic (the realm the cycle was
## broken in colours it), then back to the hub.
func _victory_ending() -> void:
	_ended = true
	RunManager.end_run(true)
	SceneRouter.goto_ending()

func _end_run(victory: bool) -> void:
	_ended = true
	RunManager.end_run(victory)
	SceneRouter.goto_hub()

func _save_progress() -> void:
	# Minimal save & resume: carried state + seed. The floor is regenerated
	# deterministically from the seed on resume (Phase 1 resumes at the start
	# room; exact-room resume is a Phase 5 polish item).
	if RunManager.active:
		RunManager.set_room_progress(current_pos, _cleared.keys())
		SaveManager.save_run(RunManager.to_snapshot())

## Pull the camera back for boss fights (the Hydra especially is huge).
func _on_boss_zoom(e, _name_key: String) -> void:
	var z := 1.55
	if e != null and is_instance_valid(e):
		var d = e.get("data")
		if d != null and String(d.id) == "greece_hydra":
			z = 1.35
	_zoom_to(z)

func _zoom_to(z: float) -> void:
	if camera == null or not is_instance_valid(camera):
		return
	var tw := create_tween()
	tw.tween_property(camera, "zoom", Vector2(z, z), 0.6)
