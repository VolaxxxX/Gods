class_name SynergyData
extends RefCounted
## A data-driven item synergy (the Isaac pillar): when the player owns the right
## combination of items (by id) and/or tags, an emergent bonus activates.
## Resolved by SynergyEngine. Adding a synergy = a JSON entry, no code.

var id: String = ""
var name_key: String = ""
var desc_key: String = ""
var pantheon: String = ""

# Activation requirements (ALL must be satisfied):
var requires_items: Array[String] = []  # specific item ids owned
var requires_tags: Array[String] = []   # tags present across owned items

# What it grants while active:
var grants: Dictionary = {}              # stat modifiers (StatBlock convention)
var effect: Dictionary = {}              # optional special effect descriptor

static func from_dict(d: Dictionary) -> SynergyData:
	var s := SynergyData.new()
	s.id = d.get("id", "")
	s.name_key = d.get("name_key", s.id)
	s.desc_key = d.get("desc_key", "")
	s.pantheon = d.get("pantheon", "")
	s.requires_items = DataUtil.to_string_array(d.get("requires_items", []))
	s.requires_tags = DataUtil.to_string_array(d.get("requires_tags", []))
	s.grants = d.get("grants", {})
	s.effect = d.get("effect", {})
	return s
