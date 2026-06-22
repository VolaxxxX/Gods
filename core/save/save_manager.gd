extends Node
## Robust, versioned persistence. Two payloads:
##   - meta:  permanent progression (karma, unlocks, options) — survives death.
##   - run:   in-progress run snapshot for save & resume (tab/app can close any
##            time, especially on Web). Cleared when a run ends.
##
## Stored as JSON under user:// (browser-backed storage on Web exports).

const SAVE_VERSION := 1
const META_PATH := "user://meta.save"
const RUN_PATH := "user://run.save"

var meta: Dictionary = {}

func _ready() -> void:
	load_meta()

# --- Meta progression ---
func load_meta() -> void:
	meta = _read(META_PATH)
	if meta.is_empty():
		meta = _default_meta()
	meta = _migrate(meta)

func save_meta() -> void:
	meta["version"] = SAVE_VERSION
	_write(META_PATH, meta)

func _default_meta() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"karma": 0,
		"unlocks": {},  # meta_upgrade id -> owned level
		"options": {"auto_aim": true, "auto_fire": false, "music": 0.8, "sfx": 0.9},
		"runs_completed": 0,
		# Narrative state (Hades-style): per-speaker meeting counts, story flags,
		# one-shot lines seen, realms whose final boss is beaten.
		"story": {"stage": 0, "flags": [], "met": {}, "seen": []},
		"bosses_cleared": [],
	}

## Forward-migration hook. Bump SAVE_VERSION and add cases as the schema evolves.
func _migrate(data: Dictionary) -> Dictionary:
	# Normalize fields that may be missing or of an older shape.
	if typeof(data.get("unlocks")) != TYPE_DICTIONARY:
		data["unlocks"] = {}
	if not data.has("karma"):
		data["karma"] = 0
	if typeof(data.get("story")) != TYPE_DICTIONARY:
		data["story"] = {"stage": 0, "flags": [], "met": {}, "seen": []}
	# Normalize story sub-fields so a malformed/older save can't crash set_flag /
	# mark_line_seen (which expect flags & seen as Arrays, met as a Dictionary).
	var st: Dictionary = data["story"]
	if typeof(st.get("flags")) != TYPE_ARRAY:
		st["flags"] = []
	if typeof(st.get("seen")) != TYPE_ARRAY:
		st["seen"] = []
	if typeof(st.get("met")) != TYPE_DICTIONARY:
		st["met"] = {}
	if not data.has("bosses_cleared"):
		data["bosses_cleared"] = []
	data["version"] = SAVE_VERSION
	return data

# --- Narrative state ---
func story() -> Dictionary:
	if typeof(meta.get("story")) != TYPE_DICTIONARY:
		meta["story"] = {"stage": 0, "flags": [], "met": {}, "seen": []}
	return meta["story"]

func meetings(speaker: String) -> int:
	return int(story().get("met", {}).get(speaker, 0))

func meet(speaker: String) -> int:
	var s := story()
	var m: Dictionary = s.get("met", {})
	m[speaker] = int(m.get(speaker, 0)) + 1
	s["met"] = m
	save_meta()
	return m[speaker]

func has_flag(f: String) -> bool:
	return f in story().get("flags", [])

func set_flag(f: String) -> void:
	var s := story()
	var a: Array = s.get("flags", [])
	if not (f in a):
		a.append(f)
		s["flags"] = a
		save_meta()

func line_seen(id: String) -> bool:
	return id in story().get("seen", [])

func mark_line_seen(id: String) -> void:
	var s := story()
	var a: Array = s.get("seen", [])
	if not (id in a):
		a.append(id)
		s["seen"] = a
		save_meta()

func story_stage() -> int:
	return int(story().get("stage", 0))

func set_story_stage(n: int) -> void:
	var s := story()
	s["stage"] = n
	save_meta()

func realms_cleared() -> Array:
	return meta.get("bosses_cleared", [])

func record_realm_cleared(biome: String) -> void:
	var a: Array = meta.get("bosses_cleared", [])
	if not (biome in a):
		a.append(biome)
		meta["bosses_cleared"] = a
		set_story_stage(a.size())  # stage advances with realms conquered

# --- Meta convenience ---
func get_karma() -> int:
	return int(meta.get("karma", 0))

func add_karma(amount: int) -> void:
	meta["karma"] = get_karma() + amount
	Events.emit_signal("karma_changed", get_karma())

func upgrade_level(id: String) -> int:
	return int(meta.get("unlocks", {}).get(id, 0))

func set_upgrade_level(id: String, level: int) -> void:
	if not meta.has("unlocks"):
		meta["unlocks"] = {}
	meta["unlocks"][id] = level

# --- Run resume ---
func save_run(snapshot: Dictionary) -> void:
	snapshot["version"] = SAVE_VERSION
	_write(RUN_PATH, snapshot)

func load_run() -> Dictionary:
	return _read(RUN_PATH)

func has_run() -> bool:
	return FileAccess.file_exists(RUN_PATH)

func clear_run() -> void:
	if FileAccess.file_exists(RUN_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RUN_PATH))
		# On Web/sandboxed FS, fall back to truncating.
		if FileAccess.file_exists(RUN_PATH):
			_write(RUN_PATH, {})

# --- IO ---
func _write(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: cannot write %s" % path)
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()

func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
