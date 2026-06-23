class_name FloatingText
extends Node2D
## A small number that rises and fades, then frees itself — damage/heal popups.
## Presentation only; spawn it into a world-space parent (the room).

const LIFE := 0.6

var _text := ""
var _color := Color.WHITE
var _t := 0.0

static func spawn(parent: Node, world_pos: Vector2, text: String, color: Color) -> void:
	if parent == null:
		return
	var ft := FloatingText.new()
	ft.position = world_pos
	ft._text = text
	ft._color = color
	parent.add_child(ft)

func _ready() -> void:
	z_index = 40
	var l := Label.new()
	l.text = _text
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", _color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 4)
	l.position = Vector2(-12, -12)
	add_child(l)

func _process(delta: float) -> void:
	_t += delta
	position.y -= 42.0 * delta
	modulate.a = clampf(1.0 - _t / LIFE, 0.0, 1.0)
	if _t >= LIFE:
		queue_free()
