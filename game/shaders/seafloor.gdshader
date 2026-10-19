// Sand with ripples and drifting caustics. Compatibility-renderer safe.
shader_type spatial;

uniform vec4 sand_a : source_color = vec4(0.5, 0.45, 0.35, 1.0);
uniform vec4 sand_b : source_color = vec4(0.36, 0.33, 0.26, 1.0);
uniform float caustic_strength = 0.12;
uniform float arena_radius = 22.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float caustic(vec2 p, float t) {
	float c = 0.0;
	c += sin(p.x * 1.7 + t * 0.9 + sin(p.y * 1.3 + t * 0.7) * 1.5);
	c += sin(p.y * 1.9 - t * 0.8 + sin(p.x * 1.1 - t * 0.6) * 1.5);
	return pow(clamp(1.0 - abs(c) * 0.6, 0.0, 1.0), 4.0);
}

void fragment() {
	vec2 p = world_pos.xz;
	float ripple = sin(p.x * 2.2 + sin(p.y * 0.5) * 2.0) * 0.5 + 0.5;
	float patch = sin(p.x * 0.17) * sin(p.y * 0.21) * 0.5 + 0.5;
	vec3 col = mix(sand_b.rgb, sand_a.rgb, ripple * 0.35 + patch * 0.65);
	float r = length(p);
	col *= mix(1.0, 0.55, smoothstep(arena_radius - 2.0, arena_radius + 8.0, r));   // darker past the arena edge
	ALBEDO = col;
	ROUGHNESS = 0.95;
	EMISSION = vec3(0.55, 0.85, 1.0) * caustic(p * 0.6, TIME) * caustic_strength * (1.0 - smoothstep(arena_radius - 4.0, arena_radius + 6.0, r));
}
