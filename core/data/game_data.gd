extends Node
## Central content registry. Loads content/manifest.json, then each listed file,
## parsing entries into typed objects keyed by id. This is the heart of the
## data-driven architecture: adding content = adding a JSON file + manifest line,
## never touching engine code.

const MANIFEST_PATH := "res://content/manifest.json"

# Registries: id -> typed object.
var entities: Dictionary = {}   # EntityData
var items: Dictionary = {}      # ItemData
var deities: Dictionary = {}    # DeityData
var blessings: Dictionary = {}  # BlessingData
var biomes: Dictionary = {}     # BiomeData
var rooms: Dictionary = {}      # RoomTemplate

func _ready() -> void:
	load_all()

func load_all() -> void:
	_clear()
	var manifest := _read_json(MANIFEST_PATH)
	if typeof(manifest) != TYPE_DICTIONARY:
		push_error("GameData: manifest missing or invalid at %s" % MANIFEST_PATH)
		return
	var files: Array = manifest.get("files", [])
	for path in files:
		_load_file(str(path))
	print("GameData loaded: %d entities, %d items, %d deities, %d blessings, %d biomes, %d rooms" % [
		entities.size(), items.size(), deities.size(),
		blessings.size(), biomes.size(), rooms.size()])

func _load_file(path: String) -> void:
	var data := _read_json(path)
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("GameData: skipping invalid file %s" % path)
		return
	var category: String = data.get("type", "")
	var entries: Array = data.get("entries", [])
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		_register(category, entry)

func _register(category: String, entry: Dictionary) -> void:
	match category:
		"entity":
			var e := EntityData.from_dict(entry)
			entities[e.id] = e
		"item":
			var it := ItemData.from_dict(entry)
			items[it.id] = it
		"deity":
			var d := DeityData.from_dict(entry)
			deities[d.id] = d
		"blessing":
			var b := BlessingData.from_dict(entry)
			blessings[b.id] = b
		"biome":
			var bi := BiomeData.from_dict(entry)
			biomes[bi.id] = bi
		"room":
			var r := RoomTemplate.from_dict(entry)
			rooms[r.id] = r
		_:
			push_warning("GameData: unknown category '%s'" % category)

# --- Typed getters ---
func get_entity(id: String) -> EntityData:
	return entities.get(id, null)

func get_biome(id: String) -> BiomeData:
	return biomes.get(id, null)

func get_room(id: String) -> RoomTemplate:
	return rooms.get(id, null)

## All room templates for a pantheon of a given type.
func rooms_for(pantheon: String, type: String) -> Array[RoomTemplate]:
	var out: Array[RoomTemplate] = []
	for r in rooms.values():
		if r.pantheon == pantheon and r.type == type:
			out.append(r)
	return out

func _clear() -> void:
	entities.clear(); items.clear(); deities.clear()
	blessings.clear(); biomes.clear(); rooms.clear()

func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("GameData: file not found %s" % path)
		return null
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if parsed == null:
		push_error("GameData: JSON parse failed for %s" % path)
	return parsed
