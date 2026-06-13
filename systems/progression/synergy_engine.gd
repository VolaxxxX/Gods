class_name SynergyEngine
extends RefCounted
## Resolves which synergies are active given the player's owned items, and
## aggregates their granted modifiers/effects. Pure & headless-testable: it takes
## plain data in and returns plain data out (no autoloads, no scene access).

## owned_item_ids: Array[String]
## items_registry: Dictionary id -> ItemData (for tag lookup)
## synergies: Array[SynergyData]
## Returns: { "active": Array[String] (synergy ids),
##            "modifiers": Array[Dictionary],
##            "effects": Array[Dictionary] }
static func resolve(owned_item_ids: Array, items_registry: Dictionary, synergies: Array) -> Dictionary:
	var owned := {}
	var tags := {}
	for id in owned_item_ids:
		owned[id] = true
		var item = items_registry.get(id, null)
		if item != null:
			for tag in item.tags:
				tags[tag] = int(tags.get(tag, 0)) + 1

	var active: Array = []
	var modifiers: Array = []
	var effects: Array = []
	for syn in synergies:
		if _satisfied(syn, owned, tags):
			active.append(syn.id)
			if not syn.grants.is_empty():
				modifiers.append(syn.grants)
			if not syn.effect.is_empty():
				effects.append(syn.effect)
	return {"active": active, "modifiers": modifiers, "effects": effects}

static func _satisfied(syn: SynergyData, owned: Dictionary, tags: Dictionary) -> bool:
	for item_id in syn.requires_items:
		if not owned.has(item_id):
			return false
	for tag in syn.requires_tags:
		if not tags.has(tag):
			return false
	# Reject empty/degenerate synergies that would always trigger.
	return not (syn.requires_items.is_empty() and syn.requires_tags.is_empty())
