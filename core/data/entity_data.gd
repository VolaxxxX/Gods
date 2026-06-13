class_name EntityData
extends RefCounted
## Data for an entity archetype (enemy, or a playable starting "form").
## Constructed from JSON by GameData. Pure data — no scene logic here.

var id: String = ""
var name_key: String = ""        # Loc key for display name
var role: String = "enemy"       # "enemy" | "player" | "boss" | "miniboss"
var pantheon: String = ""        # e.g. "greece"
var max_health: float = 10.0
var move_speed: float = 80.0     # px/s
var contact_damage: float = 1.0
var color: Color = Color(0.85, 0.3, 0.3)   # greybox tint
var radius: float = 12.0         # greybox size & collision radius
var ai: String = "chase"         # behavior id read by AIComponent
var weapon_id: String = ""       # optional ranged weapon (ItemData/weapon)
var tags: Array[String] = []

static func from_dict(d: Dictionary) -> EntityData:
	var e := EntityData.new()
	e.id = d.get("id", "")
	e.name_key = d.get("name_key", e.id)
	e.role = d.get("role", "enemy")
	e.pantheon = d.get("pantheon", "")
	e.max_health = float(d.get("max_health", 10.0))
	e.move_speed = float(d.get("move_speed", 80.0))
	e.contact_damage = float(d.get("contact_damage", 1.0))
	e.radius = float(d.get("radius", 12.0))
	e.ai = d.get("ai", "chase")
	e.weapon_id = d.get("weapon_id", "")
	e.color = DataUtil.to_color(d.get("color", null), e.color)
	e.tags = DataUtil.to_string_array(d.get("tags", []))
	return e
