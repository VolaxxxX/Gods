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
var _boss_cam: Camera2D       # dedicated framed camera for the Cthulhu fight
var _boss_bg: CanvasLayer      # R'lyeh backdrop behind the arena (colossus fight)
var _boss_fg: CanvasLayer      # 3D colossus layer ABOVE the floor (looms over the top edge)
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
	Events.boss_phase2.connect(_on_boss_phase2)
	Events.boss_fake_death.connect(_on_boss_fake_death)
	Events.boss_despawned.connect(func(): _exit_boss_camera(); _zoom_to(2.0))

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
	# Hidden boss-test: force the start room to be the boss arena with the chosen boss.
	if RunManager.debug_boss_test != "":
		var bn := graph.get_node(current_pos)
		bn["type"] = "boss"
		var arena := _boss_arena_template(biome)
		if arena != "":
			bn["template_id"] = arena

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
	# Boss-test: drop the player at the bottom of the arena, far from the boss that
	# spawns up top — gives a clean Typhon-style framing and avoids spawn overlap.
	if RunManager.debug_boss_test != "" and current_room != null and is_instance_valid(player):
		var rs := current_room.room_size()
		player.global_position = current_room.global_position + Vector2(rs.x * 0.5, rs.y - 130.0)
		player.velocity = Vector2.ZERO

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
		if b == "hell":
			# No lord rules R'lyeh — the gods of the OTHER realms reach across the void
			# to describe this place even the narrator cannot map.
			for fg in ["greece_zeus", "egypt_osiris", "norse_odin", "aztec_mictlantecuhtli", "japan_amaterasu", "bali_acintya"]:
				Dialogue.speak(fg, "enter_hell")
		else:
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
		# Hidden boss-test: just return to the hub after the kill (no progression).
		if RunManager.debug_boss_test != "":
			RunManager.debug_boss_test = ""
			Engine.time_scale = 1.0
			_ended = true
			RunManager.end_run(true)
			SceneRouter.goto_hub()
			return
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
	if r < 0.28:
		_offer_boon()
	elif r < 0.40:
		_trigger_wrath()
	elif r < 0.52:
		_grant_shrine_heal()

## A roaming god's mercy: restore a chunk of health. Relevant now that bosses hit
## harder — skipped silently when already at full so it's never a wasted beat.
func _grant_shrine_heal() -> void:
	if player == null or player.health == null:
		return
	if player.health.health >= player.health.max_health:
		return
	var amount: float = maxf(2.0, player.health.max_health * 0.30)
	player.health.heal(amount)
	if current_room != null:
		var local: Vector2 = player.global_position - current_room.global_position
		FloatingText.spawn(current_room, local + Vector2(0, -44),
			"+%d ❤" % int(round(amount)), Color(0.55, 1.0, 0.65))

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
		# Eldritch finale: once the normal realms are cleared, the unknown realm
		# (R'LYEH) opens as the TRUE final descent into the Old God — once per run.
		if RunManager.biome_id != "hell" and not RunManager.has_visited("hell") and GameData.get_biome("hell") != null:
			var hellb := GameData.get_biome("hell")
			var hui := RealmChoice.new()
			hui.setup([hellb])
			hui.chosen.connect(_on_realm_chosen)
			add_child(hui)
			return
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
	if entity != null and is_instance_valid(entity):
		var d = entity.get("data")
		if d != null and String(d.id) == "hell_cthulhu" and not _ended:
			_cthulhu_death(entity)
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
	var cthulhu := false
	if e != null and is_instance_valid(e):
		var d = e.get("data")
		if d != null and String(d.id) == "greece_hydra":
			z = 1.35
		elif d != null and String(d.id) == "hell_cthulhu":
			z = 0.9  # colossal Old God — pull WAY back, Typhon-style framing
			cthulhu = true
	_zoom_to(z)
	if cthulhu:
		_cthulhu_intro(e)

func _zoom_to(z: float) -> void:
	if camera == null or not is_instance_valid(camera):
		return
	var tw := create_tween()
	tw.tween_property(camera, "zoom", Vector2(z, z), 0.6)


## Boss-intro cinematic for the final Old God: the storm gathers, lightning
## cracks, and Cthulhu RISES from under the rain to loose a god's roar before the
## fight begins. Pure code + the existing rain/lightning/roar cues; freezes the
## boss AI (intro_lock) and the player for the duration.
func _cthulhu_intro(e) -> void:
	if e == null or not is_instance_valid(e):
		return
	_enter_boss_camera()  # cinematic framing: colossus up top, hero down low
	Dialogue.speak("hell_cthulhu", "cthulhu_intro")  # he speaks BEFORE the fight
	# Freeze the fight: lock the boss AI and the player's input/movement.
	e.set("intro_lock", true)
	if player != null and is_instance_valid(player):
		player.velocity = Vector2.ZERO
		player.set_physics_process(false)
		player.set_process(false)
	# Silence the boss's CONTACT damage during the cinematic — the player is frozen
	# and the Old God is huge, so otherwise contact ticks would kill them on spawn.
	var c = e.get("contact")
	if c != null:
		c.set_deferred("monitoring", false)
		c.set_deferred("monitorable", false)
	# Storm overlay: a dark veil + a white lightning flash, above the world and
	# below the HUD. Removed when the intro ends.
	var storm := CanvasLayer.new()
	storm.layer = 3
	add_child(storm)
	var dark := ColorRect.new()
	dark.color = Color(0.02, 0.03, 0.06, 0.0)
	dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	storm.add_child(dark)
	var flash := ColorRect.new()
	flash.color = Color(0.86, 0.92, 1.0, 0.0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	storm.add_child(flash)

	# He starts sunk below his arena spot and pitch-black (a silhouette under the
	# downpour), then surfaces.
	var anim_node = e.get("_anim")
	var home: Vector2 = e.position
	e.position = home + Vector2(0.0, 280.0)
	if anim_node != null:
		anim_node.modulate = Color(0.0, 0.0, 0.0, 0.0)
	Audio.duck_music(-16.0, 0.6)  # pull the theme down so the roar can DROP it back in
	if e.has_method("play_intro_emerge"):
		e.play_intro_emerge()  # the bespoke rise/unfurl sheet (if present)

	# 1) The storm gathers: darken, two lightning cracks with thunder + shake.
	var t0 := create_tween()
	t0.tween_property(dark, "color:a", 0.6, 0.7)
	await get_tree().create_timer(0.4).timeout
	await _lightning(flash, 0.9)
	await get_tree().create_timer(0.35).timeout
	await _lightning(flash, 0.7)

	# 2) Cthulhu rises from under the rain over ~2.3s (slide up + fade from black),
	#    a low rumble swelling under it.
	Audio.play_sfx("boss", 0.55)
	var rise := create_tween()
	rise.set_parallel(true)
	rise.tween_property(e, "position", home, 2.3) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if anim_node != null:
		rise.tween_property(anim_node, "modulate", Color(1.0, 1.0, 1.0, 1.0), 2.3) \
			.set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(2.0).timeout
	await _lightning(flash, 0.8)
	await get_tree().create_timer(0.4).timeout

	# 3) THE ROAR: violent shake, a blinding flash, the god-roar cue, and an
	#    eldritch shockwave ring bursting off the risen Old God.
	Audio.play_sfx("roar", 1.0)
	if e.has_method("ignite_eyes"):
		e.ignite_eyes()  # the red eyes blaze open on the roar
	if e.has_method("play_scream"):
		e.play_scream()  # the animated roar (tentacles thrash, jaw flares)
	Audio.swell_music(0.35)  # the boss theme DROPS in on the beat
	Juice.add_trauma(0.95)
	if is_instance_valid(e):
		Fx.play("burst_hell_cthulhu" if Fx.has("burst_hell_cthulhu") else "shockwave", \
			e.global_position, 560.0)
	var rf := create_tween()
	rf.tween_property(flash, "color:a", 0.95, 0.05)
	rf.tween_property(flash, "color:a", 0.0, 0.6)
	await get_tree().create_timer(0.9).timeout

	# 4) Lift the veil and HAND OVER to the fight.
	var clear := create_tween()
	clear.tween_property(dark, "color:a", 0.0, 0.5)
	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(storm):
		storm.queue_free()
	if e != null and is_instance_valid(e):
		e.set("intro_lock", false)
		var c2 = e.get("contact")
		if c2 != null:
			c2.set_deferred("monitoring", true)
			c2.set_deferred("monitorable", true)
	if player != null and is_instance_valid(player):
		player.set_physics_process(true)
		player.set_process(true)

## One lightning crack: a quick white flash + thunder cue + a kick of shake.
func _lightning(flash: ColorRect, strength: float) -> void:
	if not is_instance_valid(flash):
		return
	Audio.play_sfx("thunder", 0.9 + randf() * 0.2)
	Juice.add_trauma(0.35 * strength)
	var tw := create_tween()
	tw.tween_property(flash, "color:a", strength, 0.04)
	tw.tween_property(flash, "color:a", 0.0, 0.28)
	await tw.finished


## Phase-2 beat for the Old God: the sky tears open — a blood-red full-screen
## pulse, a short second roar, and a kick of shake as his moveset turns.
## The Old God's bar hits zero — the watching gods believe it is over and give
## thanks to the hero... then he RISES again for the true second phase.
func _on_boss_fake_death(e) -> void:
	Audio.duck_music(-10.0, 0.5)
	var spoke := false
	for fg in ["greece_zeus", "egypt_osiris", "norse_odin", "aztec_mictlantecuhtli", "japan_amaterasu", "bali_acintya"]:
		spoke = Dialogue.speak(fg, "cthulhu_fakedeath") or spoke
	spoke = Dialogue.speak("narrator", "cthulhu_fakedeath") or spoke
	var revive := func() -> void:
		if is_instance_valid(e) and e.has_method("revive_phase2"):
			Audio.swell_music(0.4)
			Audio.play_sfx("roar", 1.1)
			e.revive_phase2()
	if spoke:
		Dialogue.queue_empty.connect(revive, CONNECT_ONE_SHOT)
	else:
		revive.call()

func _on_boss_phase2(e) -> void:
	if e == null or not is_instance_valid(e):
		return
	var d = e.get("data")
	if d == null or String(d.id) != "hell_cthulhu":
		return
	var sky := CanvasLayer.new()
	sky.layer = 3
	add_child(sky)
	var red := ColorRect.new()
	red.color = Color(0.72, 0.05, 0.08, 0.0)
	red.set_anchors_preset(Control.PRESET_FULL_RECT)
	red.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky.add_child(red)
	Audio.play_sfx("roar", 1.25)
	if e.has_method("play_scream"):
		e.play_scream()
	Dialogue.speak("hell_cthulhu", "cthulhu_phase2")  # he speaks BETWEEN the two phases
	Juice.add_trauma(0.7)
	var tw := create_tween()
	tw.tween_property(red, "color:a", 0.55, 0.08)
	tw.tween_property(red, "color:a", 0.0, 0.9)
	await tw.finished
	if is_instance_valid(sky):
		sky.queue_free()

## Death cinematic for the Old God: time slows, the world darkens, a final tremor
## rolls out while the boss sinks (the Enemy plays its own collapse/fade), then
## time resumes and the post-boss flow takes over.
func _cthulhu_death(e) -> void:
	if player != null and is_instance_valid(player):
		player.velocity = Vector2.ZERO
		player.set_physics_process(false)
		player.set_process(false)
	Engine.time_scale = 0.4
	Juice.add_trauma(0.85)
	Audio.play_sfx("roar", 0.7)
	Audio.duck_music(-24.0, 0.4)
	var veil := CanvasLayer.new()
	veil.layer = 3
	add_child(veil)
	var dark := ColorRect.new()
	dark.color = Color(0.0, 0.0, 0.0, 0.0)
	dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.add_child(dark)
	var tw := create_tween()
	tw.tween_property(dark, "color:a", 0.6, 1.2)
	# Real-time waits so the slowed time_scale doesn't stretch them forever.
	await get_tree().create_timer(1.1, true, false, true).timeout
	Engine.time_scale = 1.0
	await get_tree().create_timer(0.5, true, false, true).timeout
	var lift := create_tween()
	lift.tween_property(dark, "color:a", 0.0, 0.6)
	await get_tree().create_timer(0.6).timeout
	if is_instance_valid(veil):
		veil.queue_free()
	if player != null and is_instance_valid(player):
		player.set_physics_process(true)
		player.set_process(true)

## Pick a boss-arena room template for this biome (for the boss-test shortcut).
func _boss_arena_template(b: BiomeData) -> String:
	var fallback := ""
	for r in GameData.rooms.values():
		if r.type == "boss" and r.pantheon == b.pantheon:
			if String(r.id).findn("arena") != -1:
				return r.id
			if fallback == "":
				fallback = r.id
	return fallback


## Cinematic boss camera: a fixed Camera2D that frames the whole arena with the
## colossus looming at the top and the hero small in the lower half (Typhon-style),
## instead of the usual player-follow cam. Restored by _exit_boss_camera.
func _enter_boss_camera() -> void:
	if current_room == null or not is_instance_valid(current_room):
		return
	if _boss_cam != null and is_instance_valid(_boss_cam):
		return
	var rs: Vector2 = current_room.room_size()
	_boss_cam = Camera2D.new()
	_boss_cam.position_smoothing_enabled = true
	_boss_cam.position_smoothing_speed = 4.0
	add_child(_boss_cam)
	# Centre horizontally; bias slightly DOWN so the top-anchored colossus dominates
	# the upper screen while the playable lower arena stays in view.
	_boss_cam.global_position = current_room.global_position + Vector2(rs.x * 0.5, rs.y * 0.52)
	var vp: Vector2 = get_viewport().get_visible_rect().size
	# Fit the whole arena (a little margin) so nothing important is off-screen.
	var z: float = minf(vp.x / maxf(rs.x, 1.0), vp.y / maxf(rs.y, 1.0)) * 0.82
	_boss_cam.zoom = Vector2(z, z)
	_boss_cam.make_current()
	# R'lyeh backdrop: a drowned cyclopean city behind the arena (rain falls in front).
	if _boss_bg == null:
		_boss_bg = CanvasLayer.new()
		_boss_bg.layer = -1
		add_child(_boss_bg)
		if ResourceLoader.exists("res://assets/sprites/bg_rlyeh.png"):
			var tr := TextureRect.new()
			tr.texture = load("res://assets/sprites/bg_rlyeh.png")
			tr.set_anchors_preset(Control.PRESET_FULL_RECT)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			tr.modulate = Color(0.72, 0.72, 0.72, 1.0)
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_boss_bg.add_child(tr)

	# The 3D colossus renders on a layer ABOVE the floor so it is actually visible,
	# anchored to the TOP of the screen — it overhangs the arena's top edge (Typhon).
	if _boss_fg == null and ResourceLoader.exists("res://presentation/colossus_3d.gd"):
		_boss_fg = CanvasLayer.new()
		_boss_fg.layer = 1
		add_child(_boss_fg)
		_boss_fg.add_child(load("res://presentation/colossus_3d.gd").new())
		# Depth: fade the colossus' lower body into shadow toward the arena top.
		var grad := Gradient.new()
		grad.set_color(0, Color(0.02, 0.05, 0.05, 0.0))
		grad.set_color(1, Color(0.02, 0.05, 0.05, 0.7))
		var gt := GradientTexture2D.new()
		gt.gradient = grad
		gt.fill_from = Vector2(0.0, 0.0)
		gt.fill_to = Vector2(0.0, 1.0)
		gt.width = 8
		gt.height = 64
		var fade := TextureRect.new()
		fade.texture = gt
		fade.set_anchors_preset(Control.PRESET_FULL_RECT)
		fade.anchor_top = 0.40
		fade.anchor_bottom = 0.60
		fade.offset_left = 0.0
		fade.offset_right = 0.0
		fade.offset_top = 0.0
		fade.offset_bottom = 0.0
		fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fade.stretch_mode = TextureRect.STRETCH_SCALE
		fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_boss_fg.add_child(fade)
		# Cinematic set-piece (Hades-2 / Typhon feel): a soft vignette frames the
		# arena, and a low teal fog band gives the ground depth and majesty.
		var vgrad := Gradient.new()
		vgrad.offsets = PackedFloat32Array([0.52, 1.0])
		vgrad.colors = PackedColorArray([Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.02, 0.02, 0.58)])
		var vgt := GradientTexture2D.new()
		vgt.gradient = vgrad
		vgt.fill = GradientTexture2D.FILL_RADIAL
		vgt.fill_from = Vector2(0.5, 0.5)
		vgt.fill_to = Vector2(1.0, 0.5)
		vgt.width = 256
		vgt.height = 256
		var vig := TextureRect.new()
		vig.texture = vgt
		vig.set_anchors_preset(Control.PRESET_FULL_RECT)
		vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		vig.stretch_mode = TextureRect.STRETCH_SCALE
		vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_boss_fg.add_child(vig)
		var fgrad := Gradient.new()
		fgrad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		fgrad.colors = PackedColorArray([Color(0.10, 0.40, 0.34, 0.0), Color(0.10, 0.42, 0.36, 0.20), Color(0.10, 0.40, 0.34, 0.0)])
		var fgt := GradientTexture2D.new()
		fgt.gradient = fgrad
		fgt.fill_from = Vector2(0.0, 0.0)
		fgt.fill_to = Vector2(0.0, 1.0)
		fgt.width = 8
		fgt.height = 64
		var fog := TextureRect.new()
		fog.texture = fgt
		fog.set_anchors_preset(Control.PRESET_FULL_RECT)
		fog.anchor_top = 0.58
		fog.anchor_bottom = 0.92
		fog.offset_left = 0.0
		fog.offset_right = 0.0
		fog.offset_top = 0.0
		fog.offset_bottom = 0.0
		fog.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fog.stretch_mode = TextureRect.STRETCH_SCALE
		fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_boss_fg.add_child(fog)

func _exit_boss_camera() -> void:
	if _boss_cam != null and is_instance_valid(_boss_cam):
		_boss_cam.queue_free()
		_boss_cam = null
	if _boss_bg != null and is_instance_valid(_boss_bg):
		_boss_bg.queue_free()
		_boss_bg = null
	if _boss_fg != null and is_instance_valid(_boss_fg):
		_boss_fg.queue_free()
		_boss_fg = null
	if camera != null and is_instance_valid(camera):
		camera.make_current()
