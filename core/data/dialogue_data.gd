class_name DialogueData
extends RefCounted
## A conversation snippet for a speaker (a deity id, or "narrator"). Selection is
## conditional (meeting count, story stage, flags, once) so dialogue EVOLVES like
## Hades. `lines` are shown one by one. Text goes through Loc (raw English passes
## through untranslated, so lines can be authored directly).

var id: String = ""
var speaker: String = ""      # deity id or "narrator"
var trigger: String = ""      # "hub" | "boon" | "death" | "victory" | ...
var lines: Array = []         # Array[String]
var once: bool = false        # show at most once ever
var min_meet: int = 0         # require >= this many prior meetings with speaker
var max_meet: int = -1        # -1 = no cap
var min_stage: int = 0        # require story stage >=
var max_stage: int = -1
var requires_flags: Array = []
var set_flags: Array = []
var modal: bool = false       # true = pause + tap to advance; false = toast
var weight: float = 1.0

static func from_dict(d: Dictionary) -> DialogueData:
	var dd := DialogueData.new()
	dd.id = d.get("id", "")
	dd.speaker = d.get("speaker", "narrator")
	dd.trigger = d.get("trigger", "hub")
	dd.lines = d.get("lines", [])
	dd.once = bool(d.get("once", false))
	dd.min_meet = int(d.get("min_meet", 0))
	dd.max_meet = int(d.get("max_meet", -1))
	dd.min_stage = int(d.get("min_stage", 0))
	dd.max_stage = int(d.get("max_stage", -1))
	dd.requires_flags = DataUtil.to_string_array(d.get("requires_flags", []))
	dd.set_flags = DataUtil.to_string_array(d.get("set_flags", []))
	dd.modal = bool(d.get("modal", false))
	dd.weight = float(d.get("weight", 1.0))
	return dd
