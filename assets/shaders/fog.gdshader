shader_type canvas_item;

uniform vec4 sources[128];
uniform int source_count = 0;
uniform float dim : hint_range(0.0, 1.0) = 0.45;
uniform float softness = 80.0;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float seen = 0.0;
	for (int i = 0; i < source_count; i++) {
		float d = distance(world_pos, sources[i].xy);
		seen = max(seen, 1.0 - smoothstep(sources[i].z - softness, sources[i].z, d));
	}
	COLOR = vec4(0.0, 0.0, 0.05, dim * (1.0 - seen));
}
