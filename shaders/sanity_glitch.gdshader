shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float time_scale = 1.0;

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * time_scale;
	float line = hash(floor(uv.y * 48.0 + t * 10.0));
	float band = step(0.88, line);
	float shift = (hash(t * 3.0 + uv.y * 20.0) - 0.5) * 0.06 * intensity;
	float n = hash(uv.x * 40.0 + uv.y * 15.0 + t);
	float a = band * intensity * 0.45 + n * intensity * 0.12;
	vec3 col = vec3(0.85 + shift, 0.15, 0.35 + abs(shift));
	col = mix(vec3(0.1, 0.0, 0.05), col, band);
	COLOR = vec4(col, a);
}
