class_name BlessingData
extends RefCounted
## A divine blessing offered at an altar (Hades-style boon). Data-driven so it
## can be balanced without code. The effect is interpreted by the blessing
## system (Phase 2); for now it carries enough to display and to slot in later.

var id: String = ""
var name_key: String = ""
var desc_key: String = ""
var deity_id: String = ""
var pantheon: String = ""
var rarity: String = "common"        # common | rare | epic | legendary
var color: Color = Color(0.6, 0.8, 1.0)

# Effect descriptor interpreted by the blessing system. Example:
#   { "kind": "on_hit", "effect": "chain_lightning", "value": 3 }
var effect: Dictionary = {}
# Optional flat stat modifiers (StatBlock convention), for stat-boon blessings.
var modifiers: Dictionary = {}
var tags: Array[String] = []         # for syncretism synergies

static func from_dict(d: Dictionary) -> BlessingData:
	var b := BlessingData.new()
	b.id = d.get("id", "")
	b.name_key = d.get("name_key", b.id)
	b.desc_key = d.get("desc_key", "")
	b.deity_id = d.get("deity_id", "")
	b.pantheon = d.get("pantheon", "")
	b.rarity = d.get("rarity", "common")
	b.color = DataUtil.to_color(d.get("color", null), b.color)
	b.effect = d.get("effect", {})
	b.modifiers = d.get("modifiers", {})
	b.tags = DataUtil.to_string_array(d.get("tags", []))
	return b
