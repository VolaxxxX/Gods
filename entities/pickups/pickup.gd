class_name Pickup
extends Area2D
## A grabbable item lying in a reward/shop room. Greybox = a colored disc.
## In shops it has a gold price (shown beneath it); the player must afford it.
## The actual stat effect is applied by the player via RunManager (data-driven).

const RADIUS := 15.0

var item: ItemData
var price: int = 0  # 0 = free (reward room)

func setup(p_item: ItemData, p_price: int = 0) -> void:
	item = p_item
	price = p_price

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

func _on_body_entered(_body: Node) -> void:
	if item == null:
		return
	# Shops charge gold; if the player can't afford it, leave it on the floor.
	if price > 0:
		if not RunManager.spend_gold(price):
			return
		RunManager.add_style("greedy")
	RunManager.add_item(item.id)
	queue_free()

func _draw() -> void:
	var col := item.color if item != null else Color(1, 1, 1)
	draw_circle(Vector2.ZERO, RADIUS, col)
	draw_arc(Vector2.ZERO, RADIUS + 3.0, 0, TAU, 24, Color(1, 1, 1, 0.7), 2.0)
	if price > 0:
		draw_string(ThemeDB.fallback_font, Vector2(-RADIUS, RADIUS + 20.0),
			"%d" % price, HORIZONTAL_ALIGNMENT_CENTER, RADIUS * 2.0, 16,
			Color(1, 0.86, 0.4))
