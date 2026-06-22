extends Node
## Holds the state of the CURRENT run: seed, biome, generated floor, progress,
## and the player's carried stats (health etc.). The run scene reads/writes this;
## SaveManager serializes it for resume.

var active: bool = false
var seed_value: int = 0
var biome_id: String = "greece"
var character_id: String = "char_wanderer"
var floor_index: int = 0
var floor_in_biome: int = 1   # 1 = palier-boss floor, last = final-boss floor
var current_room_index: int = 0
# Multi-biome runs: realms descended so far this run (non-linear branching).
var visited_biomes: Array[String] = []

# Carried player state (greybox baseline; expands with items/blessings later).
var player_max_health: float = 8.0
var player_health: float = 8.0
var gold: int = 0
var owned_items: Array[String] = []
var chosen_blessings: Array[String] = []
# Curses incurred by mixing rival deities (syncretism risk). Each is a StatBlock
# modifier dict applied alongside items/blessings.
var curses: Array = []

# Run tallies (feed karma + soul judgment on run end).
var enemies_killed: int = 0
var rooms_cleared_count: int = 0

# Style tracking for the Egyptian "weighing of the soul" (Phase 2). Accumulated
# now so the data exists when the system lands.
var style: Dictionary = {"aggressive": 0, "cautious": 0, "greedy": 0, "merciful": 0}

# The generated floor graph (set by FloorGenerator). Not serialized directly;
# regenerated from the seed on resume to keep saves tiny and deterministic.
var floor_graph = null

func start_run(p_seed: int, p_biome: String = "greece", p_character: String = "char_wanderer") -> void:
	active = true
	resuming = false
	seed_value = p_seed
	biome_id = p_biome
	character_id = p_character
	floor_index = 0
	floor_in_biome = 1
	current_room_index = 0
	gold = 0
	enemies_killed = 0
	rooms_cleared_count = 0
	visited_biomes.clear()
	owned_items.clear()
	chosen_blessings.clear()
	curses.clear()
	style = {"aggressive": 0, "cautious": 0, "greedy": 0, "merciful": 0}
	# Apply the chosen character's starting kit (stats flow via collect_modifiers;
	# any start grants are added so the player picks them up on _ready).
	var ch = GameData.characters.get(character_id, null)
	if ch != null:
		if ch.start_item != "":
			owned_items.append(ch.start_item)
		if ch.start_blessing != "":
			chosen_blessings.append(ch.start_blessing)
	player_max_health = 8.0
	player_health = player_max_health
	RNG.seed_from_int(p_seed)
	Events.emit_signal("run_started", p_seed)

func end_run(victory: bool) -> void:
	active = false
	floor_graph = null
	# Weighing of the soul: play style produces a verdict + bonus karma.
	var judgment := SoulJudgment.weigh(style)
	SaveManager.meta["last_verdict"] = judgment["verdict_key"]
	Events.emit_signal("soul_judged", judgment["verdict_key"])
	# Reincarnation: convert the run's deeds into permanent karma.
	var karma_gain := rooms_cleared_count * 2 + int(enemies_killed / 2.0) \
		+ int(judgment["karma_bonus"]) + (25 if victory else 0)
	SaveManager.add_karma(karma_gain)
	SaveManager.clear_run()
	SaveManager.meta["runs_completed"] = int(SaveManager.meta.get("runs_completed", 0)) + 1
	SaveManager.save_meta()
	Events.emit_signal("run_ended", victory)

# --- Gold & kills ---
func add_gold(amount: int) -> void:
	gold += amount
	Events.emit_signal("gold_changed", gold)

func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	Events.emit_signal("gold_changed", gold)
	return true

func on_enemy_killed(gold_drop: int) -> void:
	enemies_killed += 1
	add_style("aggressive", 1)
	if gold_drop > 0:
		add_gold(gold_drop)

# --- Multi-biome runs (non-linear branches) ---
## How many realms a single run spans (capped so runs stay 15–30 min).
func max_biomes() -> int:
	return mini(3, GameData.biomes.size())

## Realm ids not yet descended this run (branch options after a boss).
func realms_remaining() -> Array:
	var out: Array = []
	for id in GameData.biomes.keys():
		if id != biome_id and not (id in visited_biomes):
			out.append(id)
	return out

## True if clearing the current biome ends the whole run (final realm).
func is_final_biome() -> bool:
	return visited_biomes.size() + 1 >= max_biomes() or realms_remaining().is_empty()

## Record the current biome as cleared and descend into the next one. The run
## scene regenerates the floor; items/blessings/health/gold all carry over.
func advance_to_biome(next_biome: String) -> void:
	if not (biome_id in visited_biomes):
		visited_biomes.append(biome_id)
	biome_id = next_biome
	floor_in_biome = 1
	Events.emit_signal("biome_changed", next_biome)

# --- Floors within a zone (palier boss -> final boss) ---
func _biome_floors() -> int:
	var b := GameData.get_biome(biome_id)
	return b.floors if b != null else 1

func is_final_floor() -> bool:
	return floor_in_biome >= _biome_floors()

func advance_floor() -> void:
	floor_in_biome += 1

## Which boss the current floor's boss room should spawn: the palier (miniboss)
## on earlier floors, the true boss on the final floor.
func current_boss_id() -> String:
	var b := GameData.get_biome(biome_id)
	if b == null:
		return ""
	if not is_final_floor() and b.miniboss_id != "":
		return b.miniboss_id
	return b.boss_id

func add_style(kind: String, amount: int = 1) -> void:
	if style.has(kind):
		style[kind] = int(style[kind]) + amount

# --- Progression: items & blessings ---
func add_item(id: String) -> void:
	owned_items.append(id)
	Events.emit_signal("item_picked_up", id)

func add_blessing(id: String) -> void:
	# Syncretism: mixing a rival deity's boon angers the jealous gods → a curse.
	var b = GameData.blessings.get(id, null)
	var deity: String = b.deity_id if b != null else ""
	var angers_rival: bool = deity != "" and is_rival_of_owned(deity)
	chosen_blessings.append(id)
	if angers_rival:
		curses.append({"damage_mult": 0.9})
		Events.emit_signal("rivalry_incurred", deity)
	Events.emit_signal("blessing_chosen", id)

## Distinct deity ids the player currently has blessings from.
func owned_deities() -> Array:
	var out: Array = []
	for bid in chosen_blessings:
		var b = GameData.blessings.get(bid, null)
		if b != null and b.deity_id != "" and not (b.deity_id in out):
			out.append(b.deity_id)
	return out

## True if `deity_id` is a rival of any deity the player already follows (mutual).
func is_rival_of_owned(deity_id: String) -> bool:
	var dd = GameData.deities.get(deity_id, null)
	for od in owned_deities():
		if od == deity_id:
			continue
		if dd != null and (od in dd.rivals):
			return true
		var odd = GameData.deities.get(od, null)
		if odd != null and (deity_id in odd.rivals):
			return true
	return false

## The first owned deity that rivals `deity_id` (mutual), or "" if none — lets the
## offended god react jealously in dialogue.
func owned_rival_of(deity_id: String) -> String:
	var dd = GameData.deities.get(deity_id, null)
	for od in owned_deities():
		if od == deity_id:
			continue
		if dd != null and (od in dd.rivals):
			return od
		var odd = GameData.deities.get(od, null)
		if odd != null and (deity_id in odd.rivals):
			return od
	return ""

## All active stat modifiers from items + blessings + active synergies.
## Returns Array[Dictionary] for StatBlock.add_modifiers().
func collect_modifiers() -> Array:
	var mods: Array = []
	for id in owned_items:
		var it = GameData.items.get(id, null)
		if it != null and not it.modifiers.is_empty():
			mods.append(it.modifiers)
	for id in chosen_blessings:
		var b = GameData.blessings.get(id, null)
		if b != null and not b.modifiers.is_empty():
			mods.append(b.modifiers)
	for grant in _synergy_result()["modifiers"]:
		mods.append(grant)
	for curse in curses:
		mods.append(curse)
	var meta := meta_modifiers()
	if not meta.is_empty():
		mods.append(meta)
	var ch = GameData.characters.get(character_id, null)
	if ch != null and not ch.modifiers.is_empty():
		mods.append(ch.modifiers)
	return mods

## Permanent karma upgrades (reincarnation traits) as a single StatBlock dict.
func meta_modifiers() -> Dictionary:
	var out := {}
	for up in GameData.meta_upgrades.values():
		var level := SaveManager.upgrade_level(up.id)
		if level > 0:
			# Multiplicative modifiers are factors around 1.0; additive are flat.
			if up.mode == "mult":
				out[up.modifier_key()] = 1.0 + up.per_level * level
			else:
				out[up.modifier_key()] = up.per_level * level
	return out

## All active special effects (on_hit / passive) from blessings + synergies.
func collect_effects() -> Array:
	var fx: Array = []
	for id in chosen_blessings:
		var b = GameData.blessings.get(id, null)
		if b != null and not b.effect.is_empty():
			fx.append(b.effect)
	for e in _synergy_result()["effects"]:
		fx.append(e)
	return fx

func active_synergy_ids() -> Array:
	return _synergy_result()["active"]

func _synergy_result() -> Dictionary:
	# Evaluate ALL synergies, not just the current biome's: items persist across
	# biomes in multi-realm runs, so tag-based synergies fire cross-pantheon.
	return SynergyEngine.resolve(owned_items, GameData.items, GameData.synergies.values())

# --- Serialization for save & resume ---
# Set to true by from_snapshot so the run scene resumes at the exact room.
var resuming: bool = false
var resume_room_coords: Vector2i = Vector2i.ZERO
var resume_cleared: Array = []  # of [x, y]

## Called by the run scene each room so the snapshot can resume in place.
func set_room_progress(coords: Vector2i, cleared_keys: Array) -> void:
	resume_room_coords = coords
	var packed: Array = []
	for k in cleared_keys:
		packed.append([k.x, k.y])
	resume_cleared = packed

func to_snapshot() -> Dictionary:
	return {
		"seed": seed_value,
		"biome": biome_id,
		"character": character_id,
		"visited_biomes": visited_biomes,
		"floor_index": floor_index,
		"floor_in_biome": floor_in_biome,
		"player_max_health": player_max_health,
		"player_health": player_health,
		"gold": gold,
		"owned_items": owned_items,
		"chosen_blessings": chosen_blessings,
		"curses": curses,
		"style": style,
		"enemies_killed": enemies_killed,
		"rooms_cleared_count": rooms_cleared_count,
		"current_room": [resume_room_coords.x, resume_room_coords.y],
		"cleared": resume_cleared,
	}

func from_snapshot(s: Dictionary) -> void:
	active = true
	resuming = true
	seed_value = int(s.get("seed", 0))
	biome_id = s.get("biome", "greece")
	character_id = s.get("character", "char_wanderer")
	visited_biomes = DataUtil.to_string_array(s.get("visited_biomes", []))
	floor_index = int(s.get("floor_index", 0))
	floor_in_biome = int(s.get("floor_in_biome", 1))
	player_max_health = float(s.get("player_max_health", 6.0))
	player_health = float(s.get("player_health", player_max_health))
	gold = int(s.get("gold", 0))
	owned_items = DataUtil.to_string_array(s.get("owned_items", []))
	chosen_blessings = DataUtil.to_string_array(s.get("chosen_blessings", []))
	curses = s.get("curses", [])
	style = s.get("style", style)
	enemies_killed = int(s.get("enemies_killed", 0))
	rooms_cleared_count = int(s.get("rooms_cleared_count", 0))
	var cr: Array = s.get("current_room", [0, 0])
	resume_room_coords = Vector2i(int(cr[0]), int(cr[1])) if cr.size() >= 2 else Vector2i.ZERO
	resume_cleared = s.get("cleared", [])
	RNG.seed_from_int(seed_value)
