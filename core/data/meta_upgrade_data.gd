class_name MetaUpgradeData
extends RefCounted
## A permanent, karma-bought upgrade applied at the hub (reincarnation traits).
## Data-driven: each level adds a StatBlock modifier to the player's base stats.

var id: String = ""
var name_key: String = ""
var desc_key: String = ""
var stat: String = ""            # StatBlock stat name, e.g. "max_health", "damage"
var mode: String = "add"         # "add" -> stat_add, "mult" -> stat_mult
var per_level: float = 1.0       # amount granted per purchased level
var max_level: int = 5
var base_cost: int = 10
var cost_growth: float = 1.6     # cost multiplier per owned level

static func from_dict(d: Dictionary) -> MetaUpgradeData:
	var m := MetaUpgradeData.new()
	m.id = d.get("id", "")
	m.name_key = d.get("name_key", m.id)
	m.desc_key = d.get("desc_key", "")
	m.stat = d.get("stat", "")
	m.mode = d.get("mode", "add")
	m.per_level = float(d.get("per_level", 1.0))
	m.max_level = int(d.get("max_level", 5))
	m.base_cost = int(d.get("base_cost", 10))
	m.cost_growth = float(d.get("cost_growth", 1.6))
	return m

## Karma cost to buy the next level given the currently owned level.
func cost_for_level(owned_level: int) -> int:
	return int(round(base_cost * pow(cost_growth, owned_level)))

## The StatBlock modifier key this upgrade contributes (e.g. "max_health_add").
func modifier_key() -> String:
	return "%s_%s" % [stat, "mult" if mode == "mult" else "add"]
