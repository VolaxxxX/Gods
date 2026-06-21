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
	# 1280x720 viewport (a 13x9 room is 832x576 px; at 1.25x it fills the height
	# while keeping the whole standard room visible). Bigger rooms scroll naturally.
	camera.zoom = Vector2(1.25, 1.25)
	player.add_child(camera)
	camera.make_current()

	Events.entity_died.connect(_on_entity_died)

	# UI overlays (screen space).
	add_child(HUD.new())
	var ui_layer := CanvasLayer.new()
	ui_layer.layer = 5
	add_child(ui_layer)
	ui_layer.add_child(TouchControls.new())
	add_child(PauseMenu.new())

	_setup_biome(RunManager.resuming)

## (Re)build the floor for the current biome and enter its start room. Called on
## run start, on resume, and each time the player descends into a new realm.
func _setup_biome(from_resume: bool) -> void:
	biome = GameData.get_biome(RunManager.biome_id)
	if biome == null:
		push_error("RunScene: unknown biome '%s'" % RunManager.biome_id)
		return

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

func _enter_room(pos: Vector2i, from_side: String) -> void:
	if current_room != null:
		current_room.queue_free()
		current_room = null

	var node := graph.get_node(pos)
	var open: Array[String] = []
	for side in node["neighbors"].keys():
		open.append(side)

	var template: RoomTemplate = null
	if node["template_id"] != "":
		template = GameData.get_room(node["template_id"])
	var already: bool = _cleared.has(pos)

	current_room = Room.new()
	add_child(current_room)
	current_room.door_taken.connect(_on_door_taken)
	current_room.cleared.connect(_on_room_cleared.bind(pos, node["type"]))

	_room_damage_taken = false

	# Build. If already cleared, treat as a safe room (no respawn).
	var build_type: String = node["type"] if not already else "reward"
	current_room.build(template, biome, open, build_type, player, pool)

	# Place the player: at the door we came through, else the room's spawn.
	if from_side != "":
		player.global_position = current_room.entry_point_for(from_side)
	else:
		player.global_position = current_room.player_spawn_point()
	player.velocity = Vector2.ZERO

	Events.emit_signal("room_entered", current_room)
	_save_progress()

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
	_cleared[pos] = true
	Events.emit_signal("room_cleared", current_room)

	if type == "boss" and not _ended:
		# Palier boss -> deeper into the SAME zone; final boss -> next realm/win.
		if RunManager.is_final_floor():
			_complete_biome()
		else:
			_next_floor()
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
	var ui := BlessingChoice.new()
	ui.setup(opts, "ui.god_favor")
	ui.chosen.connect(func(id): RunManager.add_blessing(id))
	add_child(ui)

func _trigger_wrath() -> void:
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
	var b := RunManager.biome_id
	var shown := Dialogue.speak("narrator", "boss_" + b)
	var god: String = REALM_LORDS.get(b, "")
	if god != "":
		shown = Dialogue.speak(god, "boss_" + b) or shown
	if shown:
		Dialogue.queue_empty.connect(_after_boss, CONNECT_ONE_SHOT)
	else:
		_after_boss()

func _after_boss() -> void:
	if RunManager.is_final_biome():
		_end_run(true)
		return
	var opts: Array = []
	for id in RunManager.realms_remaining():
		var b := GameData.get_biome(id)
		if b != null:
			opts.append(b)
	if opts.is_empty():
		_end_run(true)
		return
	var ui := RealmChoice.new()
	ui.setup(opts)
	ui.chosen.connect(_on_realm_chosen)
	add_child(ui)

func _on_realm_chosen(next_biome: String) -> void:
	player.health.heal(player.health.max_health * 0.5)  # reward for the descent
	RunManager.advance_to_biome(next_biome)
	_setup_biome(false)

## Palier boss down: a new map of the SAME zone (regenerated layout), keeping
## everything and healing somewhat. The final floor's boss is the true 2-phase boss.
func _next_floor() -> void:
	player.health.heal(player.health.max_health * 0.35)
	RunManager.advance_floor()
	_setup_biome(false)

func _on_entity_died(entity) -> void:
	if entity == player and not _ended:
		_end_run(false)

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
