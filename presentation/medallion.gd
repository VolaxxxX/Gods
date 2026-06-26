class_name Medallion
extends Control
## A pro "boon medallion" frame drawn procedurally around a (possibly simple) icon
## texture: a drop shadow, a soft accent glow, an ornate gold bezel with a bevel
## highlight, and the icon seated inside. Makes flat icons read as premium relics
## with no extra art. Reusable (boon picks, doors, HUD build row).

var _tex: Texture2D
var _accent: Color = Color(0.85, 0.72, 0.38)
var _rarity: String = "common"

func setup(tex: Texture2D, accent: Color, rarity: String = "common") -> void:
	_tex = tex
	_accent = accent
	_rarity = rarity
	queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	var rad: float = minf(size.x, size.y) * 0.5

	# Drop shadow grounds the medallion.
	draw_circle(c + Vector2(0.0, rad * 0.10), rad * 0.98, Color(0, 0, 0, 0.5))
	# Soft accent glow (the deity's colour) bleeding past the rim.
	draw_circle(c, rad, Color(_accent.r, _accent.g, _accent.b, 0.30))

	# Gold bezel ring (two tones for depth) framing the icon.
	var gold := _bezel_color()
	var gold_dark := gold.darkened(0.42)
	draw_arc(c, rad * 0.86, 0.0, TAU, 56, gold_dark, rad * 0.22, true)
	draw_arc(c, rad * 0.86, 0.0, TAU, 56, gold, rad * 0.13, true)
	# Bevel: lit on the top-left, shaded on the bottom-right (top-left light source).
	draw_arc(c, rad * 0.93, deg_to_rad(150), deg_to_rad(330), 28, Color(1.0, 0.96, 0.80, 0.6), 2.5, true)
	draw_arc(c, rad * 0.93, deg_to_rad(-30), deg_to_rad(150), 28, Color(0, 0, 0, 0.35), 2.5, true)
	# Thin accent rim just inside the bezel.
	draw_arc(c, rad * 0.74, 0.0, TAU, 44, _accent, 2.0, true)

	# The icon, seated inside the ring (or a greybox gem if absent).
	if _tex != null:
		var s: float = rad * 1.42
		draw_texture_rect(_tex, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false)
	else:
		draw_circle(c, rad * 0.6, _accent.darkened(0.2))
		draw_circle(c, rad * 0.6, Color(1, 1, 1, 0.0))

## Rarity tints the bezel: common bronze-gold → legendary bright gold.
func _bezel_color() -> Color:
	match _rarity:
		"legendary": return Color(0.95, 0.80, 0.36)
		"epic": return Color(0.80, 0.62, 0.85)
		"rare": return Color(0.70, 0.78, 0.92)
		_: return Color(0.80, 0.66, 0.34)
