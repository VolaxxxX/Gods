class_name ItemData
extends RefCounted
## A passive/active item. Items modify player stats and carry tags so two items
## can combine into emergent synergies (the Isaac pillar). The synergy engine
## (Phase 2) reads `tags` and `synergies`.

var id: String = ""
var name_key: String = ""
var desc_key: String = ""
var pantheon: String = ""
var rarity: String = "common"   # common | rare | cursed | relic
var color: Color = Color(0.9, 0.85, 0.4)

# Flat additive / multiplicative stat modifiers applied to the player.
# Keys are stat names understood by StatBlock (Phase 2). Example:
#   { "damage_add": 1, "fire_rate_mult": 1.15, "speed_add": 10 }
var modifiers: Dictionary = {}

# Tags drive synergies, pools, and shop filtering (e.g. "lightning", "fire").
var tags: Array[String] = []

# Optional explicit synergy hooks: other item/tag ids this combines with.
var synergies: Array[String] = []

static func from_dict(d: Dictionary) -> ItemData:
	var it := ItemData.new()
	it.id = d.get("id", "")
	it.name_key = d.get("name_key", it.id)
	it.desc_key = d.get("desc_key", "")
	it.pantheon = d.get("pantheon", "")
	it.rarity = d.get("rarity", "common")
	it.color = DataUtil.to_color(d.get("color", null), it.color)
	it.modifiers = d.get("modifiers", {})
	it.tags = DataUtil.to_string_array(d.get("tags", []))
	it.synergies = DataUtil.to_string_array(d.get("synergies", []))
	return it
