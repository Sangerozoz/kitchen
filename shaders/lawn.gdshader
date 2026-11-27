shader_type canvas_item;

uniform vec2 grid_size = vec2(38.0, 52.0);
uniform vec2 field_size = vec2(608.0, 832.0);
uniform float fever_strength : hint_range(0.0, 1.0) = 0.0;
uniform int yard_theme = 0;

// 100% 16-bit mediump-safe fast hash for iOS & Android mobile WebGL2 GPUs
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
	vec2 world_px = UV * field_size;
	vec4 state = texture(TEXTURE, UV);

	float mowed = smoothstep(0.32, 0.68, state.r);
	float soil_mask = smoothstep(0.82, 0.96, state.b);
	vec2 px_step = 1.0 / grid_size;
	vec3 col;

	// Per-yard sunlit meadow color palette (0: Sunny Emerald, 1: Golden Autumn, 2: Spring Mint, 3: Deep Jade)
	vec3 mowed_a = vec3(0.49, 0.77, 0.30);
	vec3 mowed_b = vec3(0.43, 0.72, 0.26);
	vec3 tall_dark = vec3(0.14, 0.43, 0.16);
	vec3 tall_mid = vec3(0.20, 0.54, 0.20);
	vec3 tall_tip = vec3(0.32, 0.67, 0.25);
	if (yard_theme == 1) {
		// Golden Autumn Meadow
		mowed_a = vec3(0.76, 0.74, 0.30);
		mowed_b = vec3(0.69, 0.67, 0.25);
		tall_dark = vec3(0.44, 0.45, 0.12);
		tall_mid = vec3(0.58, 0.56, 0.16);
		tall_tip = vec3(0.76, 0.68, 0.22);
	} else if (yard_theme == 2) {
		// Spring Fresh Mint Meadow
		mowed_a = vec3(0.42, 0.80, 0.44);
		mowed_b = vec3(0.36, 0.74, 0.39);
		tall_dark = vec3(0.11, 0.46, 0.28);
		tall_mid = vec3(0.16, 0.58, 0.36);
		tall_tip = vec3(0.30, 0.74, 0.46);
	} else if (yard_theme == 3) {
		// Deep Sunlit Jade Grove
		mowed_a = vec3(0.45, 0.73, 0.28);
		mowed_b = vec3(0.39, 0.66, 0.23);
		tall_dark = vec3(0.10, 0.36, 0.14);
		tall_mid = vec3(0.16, 0.47, 0.18);
		tall_tip = vec3(0.28, 0.62, 0.24);
	}

	// Fast-path branching: Android/iOS mobile GPUs skip unused noise & texture taps!
	if (mowed > 0.98) {
		// Already mowed lawn: classic alternating stripes + cheap 1-hash grain + edge drop-shadow
		float stripe = step(0.5, fract(world_px.x * 0.015625));
		vec3 mowed_col = mix(mowed_a, mowed_b, stripe);
		float grain = hash21(floor(mod(world_px, 256.0) * 0.5));
		mowed_col += (grain - 0.5) * 0.036;

		float north_state = texture(TEXTURE, clamp(UV - vec2(0.0, px_step.y * 0.85), vec2(0.0), vec2(1.0))).r;
		float edge_shadow = 1.0 - smoothstep(0.3, 0.7, north_state);
		col = mowed_col * (1.0 - edge_shadow * 0.16);
	} else {
		float t = mod(TIME, 628.3185);

		// Wind-swaying lush tall grass (uses continuous world_px — zero tiling seams, 100% mediump-safe!)
		float wind = sin(t * 2.4 + world_px.x * 0.025 + world_px.y * 0.018) * 1.6;
		vec2 blade_uv = (world_px + vec2(wind, 0.0)) * 0.19;
		float blades = value_noise(blade_uv * vec2(1.7, 0.9));
		float clump = 0.5 + 0.5 * sin(world_px.x * 0.048 + world_px.y * 0.036);
		float tip = smoothstep(0.56, 0.90, blades);

		vec3 tall_col = mix(tall_dark, tall_mid, clump);
		tall_col = mix(tall_col, tall_tip, tip * 0.75);

		// Special colored grass (golden / flower-turf patches)
		float special = state.g;
		if (special > 0.15) {
			float spec_mask = smoothstep(0.18, 0.45, special);
			float shimmer = 0.5 + 0.5 * sin(t * 4.5 + world_px.x * 0.06 - world_px.y * 0.05);
			float sp_h = hash21(floor(world_px * 0.22 + vec2(floor(t * 2.0), -floor(t * 1.5))));
			float sparkle = smoothstep(0.92, 0.99, sp_h);
			float is_flower_turf = smoothstep(0.65, 0.9, special);
			vec3 gold_base = mix(vec3(0.96, 0.76, 0.14), vec3(0.32, 0.88, 0.72), shimmer * 0.42);
			vec3 flower_base = mix(vec3(0.97, 0.36, 0.68), vec3(1.0, 0.82, 0.24), shimmer * 0.55);
			vec3 special_col = mix(gold_base, flower_base, is_flower_turf) + vec3(1.0, 0.98, 0.80) * sparkle * 0.55;
			tall_col = mix(tall_col, special_col, spec_mask * 0.88);
		}

		// Crisp rim highlight on unmowed edge bordering mowed grass
		float south_state = texture(TEXTURE, clamp(UV + vec2(0.0, px_step.y * 0.6), vec2(0.0), vec2(1.0))).r;
		float cut_rim = smoothstep(0.35, 0.75, south_state) * (1.0 - mowed);
		tall_col += vec3(0.08, 0.12, 0.03) * cut_rim;

		if (mowed > 0.02) {
			float stripe = step(0.5, fract(world_px.x * 0.015625));
			vec3 mowed_col = mix(mowed_a, mowed_b, stripe);
			col = mix(tall_col, mowed_col, mowed);
		} else {
			col = tall_col;
		}
	}

	// Warm earth under rocks and tree trunks
	if (soil_mask > 0.01) {
		float dirt_g = hash21(floor(mod(world_px, 256.0) * 0.5));
		vec3 dirt = mix(vec3(0.45, 0.35, 0.24), vec3(0.39, 0.30, 0.20), dirt_g);
		col = mix(col, dirt, soil_mask * 0.85);
	}

	// Subtle golden sunlit warmth during 2x Fever
	if (fever_strength > 0.01) {
		col = mix(col, col * vec3(1.06, 1.03, 0.93) + vec3(0.04, 0.03, 0.0), fever_strength * 0.45);
	}

	COLOR = vec4(col, 1.0);
}
