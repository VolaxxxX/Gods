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
var gold: int = 1                # gold dropped on death
var tags: Array[String] = []

# Optional ranged attack (bosses, casters). When `ranged` is true the entity
# gets an enemy-faction weapon that fires at the player.
var ranged: bool = false
var range_damage: float = 2.0
var range_rate: float = 1.0      # shots per second
var range_speed: float = 260.0   # projectile speed (px/s)

# Bespoke boss/miniboss patterns. Each entry: a Dictionary like
#   {"kind": "nova"|"spread"|"summon", "cooldown": s, "count": n, ...}
# Interpreted by the Enemy ability scheduler; cooldowns shorten when enraged.
var abilities: Array = []
# Final-boss second phase: abilities ADDED when HP drops below phase2_at,
# accompanied by a burst. Empty = single-phase enemy.
var phase2_abilities: Array = []
var phase2_at: float = 0.5

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
	e.gold = int(d.get("gold", 1))
	e.ranged = bool(d.get("ranged", false))
	e.range_damage = float(d.get("range_damage", 2.0))
	e.range_rate = float(d.get("range_rate", 1.0))
	e.range_speed = float(d.get("range_speed", 260.0))
	e.abilities = d.get("abilities", [])
	e.phase2_abilities = d.get("phase2_abilities", [])
	e.phase2_at = float(d.get("phase2_at", 0.5))
	e.color = DataUtil.to_color(d.get("color", null), e.color)
	e.tags = DataUtil.to_string_array(d.get("tags", []))
	return e
