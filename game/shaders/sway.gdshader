// Gentle underwater sway for props built from many small meshes (corals,
// anemones, seagrass). The offset depends only on world position and height,
// so every piece of a prop bends together and joints stay attached.
// Compatibility-renderer safe.
shader_type spatial;
render_mode cull_disabled;

uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 glow : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float glow_energy = 0.0;
uniform float sway = 0.02;
uniform float speed = 1.0;
uniform float roughness = 0.75;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = max(w.y, 0.0);
	vec3 off = vec3(sin(TIME * speed + w.x * 0.7 + w.z * 0.4), 0.0, cos(TIME * speed * 0.8 + w.z * 0.6 + w.x * 0.3)) * sway * h * h;
	VERTEX += (inverse(MODEL_MATRIX) * vec4(off, 0.0)).xyz;
}

void fragment() {
	ALBEDO = albedo.rgb;
	ROUGHNESS = roughness;
	EMISSION = glow.rgb * glow_energy;
}
