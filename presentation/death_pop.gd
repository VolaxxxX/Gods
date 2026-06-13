class_name DeathPop
extends Node2D
## Tiny one-shot greybox death effect: an expanding, fading ring. Frees itself.
## Presentation only.

const LIFE := 0.25

var _t: float = 0.0
var _color: Color = Color(1, 0.6, 0.3)

func start(pos: Vector2, c: Color) -> void:
	global_position = pos
	_color = c

func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
	else:
		queue_redraw()

func _draw() -> void:
	var f := _t / LIFE
	var col := Color(_color.r, _color.g, _color.b, 1.0 - f)
	draw_arc(Vector2.ZERO, 8.0 + 34.0 * f, 0, TAU, 24, col, 3.0)
