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
	SaveManager.clear_run()
	SaveManager.meta["runs_completed"] = int(SaveManager.meta.get("runs_completed", 0)) + 1
	SaveManager.save_meta()
	Events.emit_signal("run_ended", victory)

func add_style(kind: String, amount: int = 1) -> void:
	if style.has(kind):
		style[kind] = int(style[kind]) + amount

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
