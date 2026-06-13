class_name DataUtil
extends RefCounted
## Small helpers for parsing loosely-typed JSON values into engine types.
## Keeps from_dict() methods terse and tolerant of authoring shorthand.

## Accepts: "#rrggbb" / "#rrggbbaa" string, [r,g,b] or [r,g,b,a] floats (0..1),
## or null (-> fallback).
static func to_color(value, fallback: Color = Color.WHITE) -> Color:
	if value == null:
		return fallback
	if typeof(value) == TYPE_STRING:
		return Color(value)  # Godot parses "#rrggbb[aa]"
	if typeof(value) == TYPE_ARRAY and value.size() >= 3:
		var a := 1.0 if value.size() < 4 else float(value[3])
		return Color(float(value[0]), float(value[1]), float(value[2]), a)
	return fallback

static func to_string_array(value) -> Array[String]:
	var out: Array[String] = []
	if typeof(value) == TYPE_ARRAY:
		for v in value:
			out.append(str(v))
	return out

static func to_vector2(value, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if typeof(value) == TYPE_ARRAY and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return fallback
