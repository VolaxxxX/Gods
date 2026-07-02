class_name Pickup
extends Area2D
## A grabbable item lying in a reward/shop room. Greybox = a colored disc.
## In shops it has a gold price (shown beneath it); the player must afford it.
## The actual stat effect is applied by the player via RunManager (data-driven).

const RADIUS := 15.0

var item: ItemData
var price: int = 0  # 0 = free (reward room)
var _tex: Texture2D
var _t: float = 0.0

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
	if item != null:
		_tex = Sprites.icon(item.id)  # framed art if present, else a greybox gem
	body_entered.connect(_on_body_entered)
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
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
	var bob: float = sin(_t * 2.6) * 4.0          # gentle float
	var c := Vector2(0.0, -bob)
	# Contact shadow stays on the floor (shrinks as the relic floats up).
	var sh: float = 0.6 - 0.12 * (bob / 4.0)
	draw_circle(Vector2(0.0, RADIUS * 0.55), RADIUS * sh, Color(0, 0, 0, 0.35))
	# Soft pulsing glow in the item's colour.
	var pulse: float = 0.18 + 0.10 * (0.5 + 0.5 * sin(_t * 3.4))
	draw_circle(c, RADIUS * 1.7, Color(col.r, col.g, col.b, pulse))
	if _tex != null:
		# Framed art: a thin gold bezel + the icon.
		draw_arc(c, RADIUS + 2.0, 0.0, TAU, 28, Color(0.82, 0.68, 0.34), 3.0, true)
		var s: float = RADIUS * 2.3
		draw_texture_rect(_tex, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false)
	else:
		# Greybox gem with a bevel highlight and dark rim.
		draw_circle(c, RADIUS + 2.0, Color(0, 0, 0, 0.5))
		draw_circle(c, RADIUS, col)
		draw_circle(c + Vector2(-RADIUS * 0.3, -RADIUS * 0.3), RADIUS * 0.4, col.lightened(0.5))
		draw_arc(c, RADIUS, 0.0, TAU, 24, col.lightened(0.3), 2.0, true)
	# Name + description so the player knows what a shop bonus actually DOES.
	if item != null:
		var font := ThemeDB.fallback_font
		var nm := Loc.t(item.name_key)
		draw_string(font, c + Vector2(-110.0, -RADIUS - 16.0), nm,
			HORIZONTAL_ALIGNMENT_CENTER, 220.0, 16, Color(1.0, 0.9, 0.5))
		var desc := Loc.t(item.desc_key)
		if desc != "" and desc != item.desc_key:
			draw_multiline_string(font, c + Vector2(-115.0, RADIUS + 42.0), desc,
				HORIZONTAL_ALIGNMENT_CENTER, 230.0, 12, -1, Color(0.82, 0.84, 0.92))
	if price > 0:
		draw_string(ThemeDB.fallback_font, c + Vector2(-RADIUS, RADIUS + 22.0),
			"%d gold" % price, HORIZONTAL_ALIGNMENT_CENTER, RADIUS * 2.0 + 40.0, 15,
			Color(1, 0.86, 0.4))
