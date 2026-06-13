class_name Pickup
extends Area2D
## A grabbable item lying in a reward/shop room. Greybox = a colored disc.
## On touch by the player it grants the item to the run and despawns. The actual
## stat effect is applied by the player via RunManager (data-driven), not here.

const RADIUS := 15.0

var item: ItemData

func setup(p_item: ItemData) -> void:
	item = p_item

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
	if item != null:
		RunManager.add_item(item.id)
	queue_free()

func _draw() -> void:
	var col := item.color if item != null else Color(1, 1, 1)
	draw_circle(Vector2.ZERO, RADIUS, col)
	draw_arc(Vector2.ZERO, RADIUS + 3.0, 0, TAU, 24, Color(1, 1, 1, 0.7), 2.0)
