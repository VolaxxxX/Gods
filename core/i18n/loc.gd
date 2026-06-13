extends Node
## Localization. English-only for now, but ALL displayed text goes through here
## so other languages can be added later without touching the UI.
##
## Backed by a flat JSON of key -> string (localization/en.json). We use a custom
## loader (not Godot .translation) so files stay hand-editable, web-safe, and
## need no editor reimport step.
##
## Usage: Loc.t("ui.play")  ->  "Play"
##        Loc.t("item.swift_sandals.name")
##        Loc.t("hud.floor", {"n": 2})  ->  "Floor 2"   (named {placeholders})

const LOCALE_PATH := "res://localization/en.json"

var _strings: Dictionary = {}

func _ready() -> void:
	_load(LOCALE_PATH)

func _load(path: String) -> void:
	if not FileAccess.file_exists(path):
		push_warning("Loc: locale file not found: %s" % path)
		return
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Loc: locale file is not a JSON object: %s" % path)
		return
	_strings = parsed

## Translate a key. Unknown keys return the key itself (visible in-game so
## missing strings are obvious). `args` substitutes {name} placeholders.
func t(key: String, args: Dictionary = {}) -> String:
	var value: String = _strings.get(key, key)
	if not args.is_empty():
		for k in args:
			value = value.replace("{%s}" % k, str(args[k]))
	return value

func has(key: String) -> bool:
	return _strings.has(key)
