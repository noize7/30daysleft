shader_type canvas_item;

// Glitch de cordura: distorsión horizontal + split RGB (rojo / verde / azul)
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float time_scale = 1.0;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

float hash(float n) {
	return fract(sin(n) * 43758.5453123);
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = TIME * time_scale;
	float i = intensity;

	// Bandas horizontales que se desplazan (scanline glitch)
	float band_y = floor(uv.y * (28.0 + i * 40.0) + t * 8.0);
	float band_rnd = hash(band_y + floor(t * 3.0));
	float band_active = step(0.82 - i * 0.25, band_rnd);

	// Desplazamiento horizontal por banda (más suave)
	float shift = (hash(band_y * 1.7 + t * 2.3) - 0.5) * 0.028 * i * (0.35 + band_active);

	// Ruido fino adicional
	float fine = (hash2(uv * 60.0 + t) - 0.5) * 0.007 * i;

	vec2 uv_base = uv + vec2(shift + fine, 0.0);

	// Split cromático RGB (rojo / verde / azul) — menos extremo
	float chroma = 0.0025 + i * 0.010;
	float chroma_pulse = chroma * (1.0 + band_active * 1.2);

	vec2 uv_r = uv_base + vec2(-chroma_pulse, 0.0);
	vec2 uv_g = uv_base + vec2(0.0, fine * 0.25);
	vec2 uv_b = uv_base + vec2(chroma_pulse, 0.0);

	float r = texture(screen_texture, uv_r).r;
	float g = texture(screen_texture, uv_g).g;
	float b = texture(screen_texture, uv_b).b;

	vec3 col = vec3(r, g, b);

	// Tint ocasional en bandas activas (rojo/cian) — más sutil
	if (band_active > 0.5 && i > 0.2) {
		float tint_mix = 0.08 + i * 0.18;
		vec3 tint = mix(vec3(1.0, 0.25, 0.3), vec3(0.25, 0.85, 1.0), hash(band_y + 9.0));
		col = mix(col, col * tint, tint_mix * band_active);
	}

	// Líneas de interferencia finas
	float scan = sin(uv.y * 900.0 + t * 40.0) * 0.5 + 0.5;
	col *= 1.0 - scan * i * 0.05;

	// Noise grain leve
	float grain = (hash2(uv * 400.0 + t * 10.0) - 0.5) * i * 0.07;
	col += grain;

	// Oscurecer un poco cuando hay mucha intensidad
	col *= 1.0 - i * 0.08;

	// Alpha limitada para no tapar la UI
	float a = clamp(i * 0.75, 0.0, 0.72);
	COLOR = vec4(col, a);
}
