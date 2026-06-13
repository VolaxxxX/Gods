class_name DeityData
extends RefCounted
## A blessing-giving deity. Belongs to one pantheon and has a mechanical
## identity (e.g. Zeus = chain lightning). Rivalries (jealous gods) drive the
## syncretism risk/reward system in Phase 2.

var id: String = ""
var name_key: String = ""
var pantheon: String = ""
var color: Color = Color(0.6, 0.8, 1.0)
var identity_key: String = ""        # short Loc tagline of the deity's theme
var blessing_ids: Array[String] = [] # blessings this deity can offer
var rivals: Array[String] = []       # deity ids that clash (curse risk)

static func from_dict(d: Dictionary) -> DeityData:
	var dd := DeityData.new()
	dd.id = d.get("id", "")
	dd.name_key = d.get("name_key", dd.id)
	dd.pantheon = d.get("pantheon", "")
	dd.color = DataUtil.to_color(d.get("color", null), dd.color)
	dd.identity_key = d.get("identity_key", "")
	dd.blessing_ids = DataUtil.to_string_array(d.get("blessing_ids", []))
	dd.rivals = DataUtil.to_string_array(d.get("rivals", []))
	return dd
