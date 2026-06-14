class_name CharacterData
extends RefCounted
## A playable "soul" with a distinct starting kit (different base stats and an
## optional starting item/blessing). Data-driven; chosen at the hub. Applied at
## run start: its modifiers flow through StatBlock like everything else.

var id: String = ""
var name_key: String = ""
var desc_key: String = ""
var color: Color = Color(0.4, 0.85, 1.0)

# Flat stat modifiers (StatBlock convention) applied as part of the base build.
var modifiers: Dictionary = {}
# Optional grants at run start.
var start_item: String = ""
var start_blessing: String = ""

static func from_dict(d: Dictionary) -> CharacterData:
	var c := CharacterData.new()
	c.id = d.get("id", "")
	c.name_key = d.get("name_key", c.id)
	c.desc_key = d.get("desc_key", "")
	c.color = DataUtil.to_color(d.get("color", null), c.color)
	c.modifiers = d.get("modifiers", {})
	c.start_item = d.get("start_item", "")
	c.start_blessing = d.get("start_blessing", "")
	return c
