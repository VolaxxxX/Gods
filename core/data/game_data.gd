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
var synergies: Dictionary = {}  # SynergyData
var meta_upgrades: Dictionary = {}  # MetaUpgradeData
var characters: Dictionary = {}     # CharacterData

func _ready() -> void:
	load_all()

func load_all() -> void:
	_clear()
	var manifest: Variant = _read_json(MANIFEST_PATH)
	if typeof(manifest) != TYPE_DICTIONARY:
		push_error("GameData: manifest missing or invalid at %s" % MANIFEST_PATH)
		return
	var files: Array = manifest.get("files", [])
	for path in files:
		_load_file(str(path))
	print("GameData loaded: %d entities, %d items, %d deities, %d blessings, %d biomes, %d rooms, %d synergies" % [
		entities.size(), items.size(), deities.size(),
		blessings.size(), biomes.size(), rooms.size(), synergies.size()])

func _load_file(path: String) -> void:
	var data: Variant = _read_json(path)
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
		"synergy":
			var s := SynergyData.from_dict(entry)
			synergies[s.id] = s
		"meta_upgrade":
			var mu := MetaUpgradeData.from_dict(entry)
			meta_upgrades[mu.id] = mu
		"character":
			var c := CharacterData.from_dict(entry)
			characters[c.id] = c
		_:
			push_warning("GameData: unknown category '%s'" % category)

# --- Typed getters ---
func get_entity(id: String) -> EntityData:
	return entities.get(id, null)

func get_biome(id: String) -> BiomeData:
	return biomes.get(id, null)

func get_room(id: String) -> RoomTemplate:
	return rooms.get(id, null)

## Room templates for a pantheon of a given type. Includes shared templates
## (pantheon == "") so every realm draws from a common pool of layouts plus its
## own — lots of variety without per-pantheon duplication (palette gives identity).
func rooms_for(pantheon: String, type: String) -> Array[RoomTemplate]:
	var out: Array[RoomTemplate] = []
	for r in rooms.values():
		if r.type == type and (r.pantheon == pantheon or r.pantheon == ""):
			out.append(r)
	return out

## All items belonging to a pantheon (for shop/reward pools).
func items_for(pantheon: String) -> Array[ItemData]:
	var out: Array[ItemData] = []
	for it in items.values():
		if it.pantheon == pantheon:
			out.append(it)
	return out

## All blessings belonging to a pantheon (for altar offerings).
func blessings_for(pantheon: String) -> Array[BlessingData]:
	var out: Array[BlessingData] = []
	for b in blessings.values():
		if b.pantheon == pantheon:
			out.append(b)
	return out

## Synergies belonging to a pantheon (empty pantheon = cross-pantheon).
func synergies_for(pantheon: String) -> Array[SynergyData]:
	var out: Array[SynergyData] = []
	for s in synergies.values():
		if s.pantheon == pantheon or s.pantheon == "":
			out.append(s)
	return out

func _clear() -> void:
	entities.clear(); items.clear(); deities.clear()
	blessings.clear(); biomes.clear(); rooms.clear(); synergies.clear()
	meta_upgrades.clear(); characters.clear()

func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("GameData: file not found %s" % path)
		return null
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if parsed == null:
		push_error("GameData: JSON parse failed for %s" % path)
	return parsed
