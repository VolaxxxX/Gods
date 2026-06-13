extends Node
## Holds the state of the CURRENT run: seed, biome, generated floor, progress,
## and the player's carried stats (health etc.). The run scene reads/writes this;
## SaveManager serializes it for resume.

var active: bool = false
var seed_value: int = 0
var biome_id: String = "greece"
var floor_index: int = 0
var current_room_index: int = 0

# Carried player state (greybox baseline; expands with items/blessings later).
var player_max_health: float = 6.0
var player_health: float = 6.0
var gold: int = 0
var owned_items: Array[String] = []
var chosen_blessings: Array[String] = []

# Run tallies (feed karma on run end).
var enemies_killed: int = 0
var rooms_cleared_count: int = 0

# Style tracking for the Egyptian "weighing of the soul" (Phase 2). Accumulated
# now so the data exists when the system lands.
var style: Dictionary = {"aggressive": 0, "cautious": 0, "greedy": 0, "merciful": 0}

# The generated floor graph (set by FloorGenerator). Not serialized directly;
# regenerated from the seed on resume to keep saves tiny and deterministic.
var floor_graph = null

func start_run(p_seed: int, p_biome: String = "greece") -> void:
	active = true
	seed_value = p_seed
	biome_id = p_biome
	floor_index = 0
	current_room_index = 0
	gold = 0
	enemies_killed = 0
	rooms_cleared_count = 0
	owned_items.clear()
	chosen_blessings.clear()
	style = {"aggressive": 0, "cautious": 0, "greedy": 0, "merciful": 0}
	var biome := GameData.get_biome(p_biome)
	if biome:
		player_max_health = 6.0
	player_health = player_max_health
	RNG.seed_from_int(p_seed)
	Events.emit_signal("run_started", p_seed)

func end_run(victory: bool) -> void:
	active = false
	floor_graph = null
	# Reincarnation: convert the run's deeds into permanent karma.
	var karma_gain := rooms_cleared_count * 2 + int(enemies_killed / 2.0) + (25 if victory else 0)
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

func add_style(kind: String, amount: int = 1) -> void:
	if style.has(kind):
		style[kind] = int(style[kind]) + amount

# --- Progression: items & blessings ---
func add_item(id: String) -> void:
	owned_items.append(id)
	Events.emit_signal("item_picked_up", id)

func add_blessing(id: String) -> void:
	chosen_blessings.append(id)
	Events.emit_signal("blessing_chosen", id)

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
	var meta := meta_modifiers()
	if not meta.is_empty():
		mods.append(meta)
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
	return SynergyEngine.resolve(owned_items, GameData.items, GameData.synergies_for(biome_id))

# --- Serialization for save & resume ---
func to_snapshot() -> Dictionary:
	return {
		"seed": seed_value,
		"biome": biome_id,
		"floor_index": floor_index,
		"current_room_index": current_room_index,
		"player_max_health": player_max_health,
		"player_health": player_health,
		"gold": gold,
		"owned_items": owned_items,
		"chosen_blessings": chosen_blessings,
		"style": style,
	}

func from_snapshot(s: Dictionary) -> void:
	active = true
	seed_value = int(s.get("seed", 0))
	biome_id = s.get("biome", "greece")
	floor_index = int(s.get("floor_index", 0))
	current_room_index = int(s.get("current_room_index", 0))
	player_max_health = float(s.get("player_max_health", 6.0))
	player_health = float(s.get("player_health", player_max_health))
	gold = int(s.get("gold", 0))
	owned_items = DataUtil.to_string_array(s.get("owned_items", []))
	chosen_blessings = DataUtil.to_string_array(s.get("chosen_blessings", []))
	style = s.get("style", style)
	RNG.seed_from_int(seed_value)
