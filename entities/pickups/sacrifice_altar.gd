class_name SacrificeAltar
extends Area2D
## A blood altar (offering/sacrifice room). Stepping onto it once trades a chunk
## of current HP for a random item — a real risk/reward dilemma. Themed per
## pantheon later (Aztec blood, coin for Charon, …); greybox red cross for now.

const RADIUS := 26.0
const HP_COST := 2.0

var _used: bool = false

func _ready() -> void:
	collision_layer = 0
	collision_mask = Collision.PLAYER_BODY
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	queue_redraw()

func _on_body_entered(body) -> void:
	if _used or not body.has_method("pay_health"):
		return
	# Never let the offering kill the player.
	if body.health.health <= HP_COST:
		return
	body.pay_health(HP_COST)
	var pool := GameData.items_for(RunManager.biome_id)
	var item = RNG.pick("loot", pool)  # untyped: pick() may return null
	if item != null:
		RunManager.add_item(item.id)
	_used = true
	queue_redraw()

func _draw() -> void:
	var col := Color(0.35, 0.06, 0.08) if _used else Color(0.7, 0.12, 0.15)
	draw_circle(Vector2.ZERO, RADIUS, col)
	if not _used:
		# A pale cross to read as an altar.
		draw_line(Vector2(0, -12), Vector2(0, 12), Color(1, 0.9, 0.9, 0.9), 3.0)
		draw_line(Vector2(-9, -4), Vector2(9, -4), Color(1, 0.9, 0.9, 0.9), 3.0)
