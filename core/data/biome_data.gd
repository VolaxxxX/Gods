class_name BiomeData
extends RefCounted
## A biome = a pantheon's playable floor. Bundles palette, room quotas, enemy
## pool, and boss. Toggling a pantheon = enabling/disabling its biome.

var id: String = ""              # usually == pantheon, e.g. "greece"
var name_key: String = ""
var pantheon: String = ""
var palette: Dictionary = {}     # named Colors: bg, wall, floor, accent

# Atmosphere (presentation). `ambient` tints the whole world via a CanvasModulate
# (mood lighting); `ambient_particle` is a drifting overlay: ember/dust/snow/petal.
var ambient: Color = Color(1, 1, 1)
var ambient_particle: String = ""

# Floor generation quotas. The generator guarantees these counts (plus a boss).
var room_count: int = 6          # non-boss rooms per floor
var floors: int = 2              # sub-floors per zone: palier boss, then final
var enemy_pool: Array[String] = []   # EntityData ids
var elite_pool: Array[String] = []
var boss_id: String = ""             # EntityData id (role "boss")
var final: bool = false              # the final realm (Cthulhu) — locked until all others are conquered
var miniboss_id: String = ""         # EntityData id spawned in miniboss rooms

# How many combat enemies to spawn per combat room (scales with depth later).
var enemies_per_room_min: int = 2
var enemies_per_room_max: int = 4

# Per-realm difficulty multiplier (data-driven). Scales regular-enemy HP and ALL
# enemy damage (contact + ranged); boss/mini-boss HP stays hand-tuned. Kept in a
# gentle 1.0–1.25 band so every realm stays playable. 1.0 = the Greek prototype.
var difficulty: float = 1.0

# Decorative prop ids scattered (non-colliding) in rooms; sprites live at
# assets/sprites/props/<id>.png. Empty = none.
var props: Array[String] = []

func palette_color(key: String, fallback: Color) -> Color:
	if palette.has(key):
		return DataUtil.to_color(palette[key], fallback)
	return fallback

static func from_dict(d: Dictionary) -> BiomeData:
	var b := BiomeData.new()
	b.id = d.get("id", "")
	b.name_key = d.get("name_key", b.id)
	b.pantheon = d.get("pantheon", b.id)
	b.palette = d.get("palette", {})
	b.ambient = DataUtil.to_color(d.get("ambient", "#ffffff"), Color(1, 1, 1))
	b.ambient_particle = d.get("ambient_particle", "")
	b.room_count = int(d.get("room_count", 6))
	b.floors = int(d.get("floors", 2))
	b.enemy_pool = DataUtil.to_string_array(d.get("enemy_pool", []))
	b.elite_pool = DataUtil.to_string_array(d.get("elite_pool", []))
	b.boss_id = d.get("boss_id", "")
	b.final = bool(d.get("final", false))
	b.miniboss_id = d.get("miniboss_id", "")
	b.enemies_per_room_min = int(d.get("enemies_per_room_min", 2))
	b.enemies_per_room_max = int(d.get("enemies_per_room_max", 4))
	b.props = DataUtil.to_string_array(d.get("props", []))
	b.difficulty = float(d.get("difficulty", 1.0))
	return b
