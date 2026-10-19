// Swaying kelp blade (box mesh, origin at its centre). Compatibility-renderer safe.
shader_type spatial;
render_mode cull_disabled;

uniform vec4 tint : source_color = vec4(0.2, 0.5, 0.22, 1.0);
uniform float phase = 0.0;
uniform float height = 4.0;

void vertex() {
	float h = VERTEX.y + height * 0.5;   // 0 at the bottom of the blade
	float bend = max(h, 0.0) * max(h, 0.0) * 0.02;
	VERTEX.x += sin(TIME * 0.9 + phase + VERTEX.y * 0.6) * bend;
	VERTEX.z += cos(TIME * 0.7 + phase) * bend * 0.6;
}

void fragment() {
	ALBEDO = tint.rgb * (0.7 + 0.3 * UV.y);
	ROUGHNESS = 0.8;
}
