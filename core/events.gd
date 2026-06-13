extends Node
## Global signal bus. Decouples systems: emitters and listeners never need to
## know about each other. Keep signals coarse and meaningful.
##
## Usage: Events.emit_signal("room_cleared", room) / Events.room_cleared.connect(cb)

# --- Run lifecycle ---
signal run_started(seed_value: int)
signal run_ended(victory: bool)
signal floor_generated(floor_index: int)
signal biome_changed(biome_id: String)

# --- Room flow ---
signal room_entered(room)
signal room_cleared(room)

# --- Combat ---
signal entity_damaged(target, amount: float)
signal entity_died(entity)
signal player_health_changed(current: float, maximum: float)

# --- Pickups / progression ---
signal item_picked_up(item_id: String)
signal blessing_chosen(blessing_id: String)
signal gold_changed(total: int)
signal karma_changed(total: int)
signal rivalry_incurred(deity_id: String)
signal soul_judged(verdict_key: String)
