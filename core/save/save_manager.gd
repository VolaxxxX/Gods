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
		"unlocks": [],
		"options": {"auto_aim": true, "auto_fire": false, "music": 0.8, "sfx": 0.9},
		"runs_completed": 0,
	}

## Forward-migration hook. Bump SAVE_VERSION and add cases as the schema evolves.
func _migrate(data: Dictionary) -> Dictionary:
	var v: int = int(data.get("version", 0))
	# Example future migration:
	# if v < 2: data["new_field"] = default; v = 2
	data["version"] = SAVE_VERSION
	return data

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
