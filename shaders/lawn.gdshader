shader_type canvas_item;

uniform vec2 grid_size = vec2(64.0, 96.0);
uniform vec2 field_size = vec2(1024.0, 1536.0);
uniform float fever_strength : hint_range(0.0, 1.0) = 0.0;

// 100% 16-bit mediump-safe hash for iOS Safari / Apple mobile WebGL2 GPUs
// Never overflows 65504 half-float limit!
float hash21(vec2 p) {
	vec2 q = fract(p * vec2(0.1031, 0.1030));
	q += dot(q, q.yx + 19.19);
	return fract((q.x + q.y) * q.x);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void fragment() {
	float t = mod(TIME, 628.3185);
	vec2 world_px = UV * field_size;
	vec2 wrapped_px = mod(world_px, 256.0);
	vec4 state = texture(TEXTURE, UV);

	float mowed = smoothstep(0.32, 0.68, state.r);
	float special = state.g;
	float soil_mask = smoothstep(0.82, 0.96, state.b);

	// Classic freshly mowed lawn stripes
	float stripe = step(0.5, fract(world_px.x * 0.015625));
	vec3 mowed_a = vec3(0.49, 0.77, 0.30);
	vec3 mowed_b = vec3(0.43, 0.72, 0.26);
	vec3 mowed_col = mix(mowed_a, mowed_b, stripe);

	// Subtle mowed grass texture grain
	float fine_grain = value_noise(wrapped_px * 0.25);
	mowed_col += (fine_grain - 0.5) * 0.045;

	// Wind-swaying lush tall grass
	float wind = sin(t * 2.4 + wrapped_px.x * 0.025 + wrapped_px.y * 0.018) * 1.6;
	vec2 blade_uv = (wrapped_px + vec2(wind, 0.0)) * 0.19;
	float clump = value_noise(wrapped_px * 0.045);
	float blades = value_noise(blade_uv * vec2(1.8, 0.9));
	float tip = smoothstep(0.58, 0.92, blades);

	vec3 tall_dark = vec3(0.14, 0.43, 0.16);
	vec3 tall_mid = vec3(0.20, 0.54, 0.20);
	vec3 tall_tip = vec3(0.32, 0.67, 0.25);
	vec3 tall_col = mix(tall_dark, tall_mid, clump);
	tall_col = mix(tall_col, tall_tip, tip * 0.75);

	// Special colored grass (shimmering golden / rainbow-cyan / magenta-gold patches)
	if (special > 0.15) {
		float spec_mask = smoothstep(0.18, 0.45, special);
		float shimmer = 0.5 + 0.5 * sin(t * 4.5 + wrapped_px.x * 0.06 - wrapped_px.y * 0.05);
		float sparkle = smoothstep(0.86, 0.98, value_noise(wrapped_px * 0.22 + vec2(mod(t * 1.4, 64.0), -mod(t * 1.1, 64.0))));
		float is_flower_turf = smoothstep(0.65, 0.9, special);
		vec3 gold_base = mix(vec3(0.96, 0.76, 0.14), vec3(0.32, 0.88, 0.72), shimmer * 0.42);
		vec3 flower_base = mix(vec3(0.97, 0.36, 0.68), vec3(1.0, 0.82, 0.24), shimmer * 0.55);
		vec3 special_col = mix(gold_base, flower_base, is_flower_turf);
		special_col += vec3(1.0, 0.98, 0.80) * sparkle * 0.55;
		tall_col = mix(tall_col, special_col, spec_mask * 0.88);
	}

	// Soft drop-shadow on mowed grass right beneath tall grass edges
	vec2 px_step = 1.0 / grid_size;
	float north_state = texture(TEXTURE, clamp(UV - vec2(0.0, px_step.y * 0.85), vec2(0.0), vec2(1.0))).r;
	float edge_shadow = (1.0 - smoothstep(0.3, 0.7, north_state)) * mowed;
	mowed_col *= (1.0 - edge_shadow * 0.16);

	// Subtle crisp rim highlight on unmowed edge
	float south_state = texture(TEXTURE, clamp(UV + vec2(0.0, px_step.y * 0.6), vec2(0.0), vec2(1.0))).r;
	float cut_rim = smoothstep(0.35, 0.75, south_state) * (1.0 - mowed);
	tall_col += vec3(0.08, 0.12, 0.03) * cut_rim;

	vec3 col = mix(tall_col, mowed_col, mowed);

	// Warm earth under rocks and tree trunks
	if (soil_mask > 0.01) {
		vec3 dirt = mix(vec3(0.45, 0.35, 0.24), vec3(0.39, 0.30, 0.20), fine_grain);
		col = mix(col, dirt, soil_mask * 0.85);
	}

	// Subtle golden sunlit warmth during 2x Fever
	if (fever_strength > 0.01) {
		col = mix(col, col * vec3(1.06, 1.03, 0.93) + vec3(0.04, 0.03, 0.0), fever_strength * 0.45);
	}

	COLOR = vec4(col, 1.0);
}
