class_name BiomeData
extends RefCounted
## A biome = a pantheon's playable floor. Bundles palette, room quotas, enemy
## pool, and boss. Toggling a pantheon = enabling/disabling its biome.

var id: String = ""              # usually == pantheon, e.g. "greece"
var name_key: String = ""
var pantheon: String = ""
var palette: Dictionary = {}     # named Colors: bg, wall, floor, accent

# Floor generation quotas. The generator guarantees these counts (plus a boss).
var room_count: int = 8          # total non-boss rooms target
var enemy_pool: Array[String] = []   # EntityData ids
var elite_pool: Array[String] = []
var boss_id: String = ""             # EntityData id (role "boss")
var miniboss_id: String = ""         # EntityData id spawned in miniboss rooms

# How many combat enemies to spawn per combat room (scales with depth later).
var enemies_per_room_min: int = 2
var enemies_per_room_max: int = 4

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
	b.room_count = int(d.get("room_count", 8))
	b.enemy_pool = DataUtil.to_string_array(d.get("enemy_pool", []))
	b.elite_pool = DataUtil.to_string_array(d.get("elite_pool", []))
	b.boss_id = d.get("boss_id", "")
	b.miniboss_id = d.get("miniboss_id", "")
	b.enemies_per_room_min = int(d.get("enemies_per_room_min", 2))
	b.enemies_per_room_max = int(d.get("enemies_per_room_max", 4))
	return b
