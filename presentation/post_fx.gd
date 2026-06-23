class_name PostFX
extends CanvasLayer
## Full-screen post-processing: a per-realm colour grade, a soft vignette, fine
## film grain and a whisper of chromatic aberration. One canvas_item shader, no
## render-pipeline features — safe on the GL Compatibility (Web/mobile) renderer.
##
## It sits just above the world (layer 4) and below the HUD / touch controls
## (layers 5+), so the game world is graded and framed while the UI stays crisp.

# Per-realm grade: lift (shadow tint, added), gain (highlight tint, multiplied),
# contrast, saturation. Tuned to give each underworld its own colour identity.
const REALM_GRADE := {
	"greece": {"lift": Vector3(-0.012, -0.004, 0.022), "gain": Vector3(0.97, 1.0, 1.07), "contrast": 1.11, "sat": 1.02},
	"bali":   {"lift": Vector3(0.026, 0.040, 0.030),   "gain": Vector3(1.06, 1.14, 1.06), "contrast": 1.04, "sat": 1.12},
	"egypt":  {"lift": Vector3(0.022, 0.008, -0.014),  "gain": Vector3(1.07, 1.0, 0.90),  "contrast": 1.09, "sat": 1.09},
	"norse":  {"lift": Vector3(-0.006, 0.0, 0.018),    "gain": Vector3(0.94, 0.99, 1.09), "contrast": 1.06, "sat": 0.90},
	"japan":  {"lift": Vector3(-0.010, 0.006, 0.006),  "gain": Vector3(0.95, 1.04, 1.02), "contrast": 1.08, "sat": 0.98},
	"aztec":  {"lift": Vector3(0.026, 0.0, -0.010),    "gain": Vector3(1.09, 0.97, 0.93), "contrast": 1.15, "sat": 1.07},
}
const DEFAULT_GRADE := {"lift": Vector3.ZERO, "gain": Vector3.ONE, "contrast": 1.08, "sat": 1.03}

var _mat: ShaderMaterial

func _ready() -> void:
	layer = 4
	process_mode = Node.PROCESS_MODE_ALWAYS
	_mat = ShaderMaterial.new()
	_mat.shader = _make_shader()
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = _mat
	add_child(rect)

## Apply the colour grade for a realm (call on biome entry).
func grade(biome_id: String) -> void:
	if _mat == null:
		return
	var g: Dictionary = REALM_GRADE.get(biome_id, DEFAULT_GRADE)
	_mat.set_shader_parameter("lift", g["lift"])
	_mat.set_shader_parameter("gain", g["gain"])
	_mat.set_shader_parameter("contrast", g["contrast"])
	_mat.set_shader_parameter("saturation", g["sat"])

func _make_shader() -> Shader:
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float vig_strength = 0.54;
uniform float vig_extent = 0.74;
uniform float grain = 0.028;
uniform float contrast = 1.08;
uniform float saturation = 1.03;
uniform vec3 lift = vec3(0.0);
uniform vec3 gain = vec3(1.0);
uniform float aberration = 0.0016;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 dir = uv - vec2(0.5);
	float d = length(dir);

	// Subtle chromatic aberration, scaled toward the edges.
	vec3 col;
	col.r = texture(screen_tex, uv - dir * aberration).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv + dir * aberration).b;

	// Colour grade: gain (highlights), lift (shadows), contrast, saturation.
	col = col * gain + lift;
	col = (col - 0.5) * contrast + 0.5;
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(l), col, saturation);

	// Vignette: frames the action and adds depth.
	float v = 1.0 - vig_strength * pow(smoothstep(vig_extent * 0.34, vig_extent, d), 1.4);
	col *= v;

	// Animated film grain to kill banding and add texture.
	float n = hash21(uv * vec2(1280.0, 720.0) + fract(TIME) * 91.7) - 0.5;
	col += n * grain;

	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
"""
	return sh
