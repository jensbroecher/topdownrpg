shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, unshaded;

uniform sampler2D tex : source_color;
uniform vec4 key_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float similarity : hint_range(0.0, 1.0) = 0.12;
uniform float smoothness : hint_range(0.0, 1.0) = 0.08;

uniform bool show_debug_line = false;

void fragment() {
	// Debug line to visualize 0.85 threshold
	if (show_debug_line && abs(UV.y - 0.85) < 0.001) {
		ALBEDO = vec4(1.0, 1.0, 0.0, 1.0).rgb;
		ALPHA = 1.0;
	} else {
		//vec4 rgba = texture(tex, UV); // Moved below

		vec4 rgba = texture(tex, UV);
		vec3 rgb = rgba.rgb;
		
		// Distance to white
		float diff_white = distance(rgb, key_color.rgb);
		
		// Distance to a typical gray shadow (desaturation)
		float gray_val = (rgb.r + rgb.g + rgb.b) / 3.0;
		float diff_gray = distance(rgb, vec3(gray_val));
		
		// Feathering effect at the top (increase smoothness for UV.y < 0.3)
		float top_feather = 1.0 - smoothstep(0.0, 0.3, UV.y);
		
		// Default similarity is weak to save details
		float current_sim = similarity;
		float current_smooth = smoothness + (top_feather * 0.15);
		
		// Smart inner pixel protection (Upper 85%)
		ivec2 tex_size = textureSize(tex, 0);
		if (UV.y < 0.85 && tex_size.x > 0) {
			// Extremely sensitive to 'not pure white' to save edge sword pixels
			if (diff_white > 0.02) {
				float d_count = 0.0;
				vec2 dirs[4] = vec2[](vec2(1,0), vec2(-1,0), vec2(0,1), vec2(0,-1));
				for (int i = 0; i < 4; i++) {
					// Scan even further (25 pixels) to catch long swords
					for (float d = 1.0; d <= 25.0; d += 3.0) {
						vec3 n_rgb = texture(tex, UV + dirs[i] * d / vec2(tex_size)).rgb;
						// If neighbor is clearly a character color
						if (distance(n_rgb, key_color.rgb) > 0.22) {
							d_count += 1.0;
							break; 
						}
					}
				}
				// If it has at least 1 character neighbor, protect it
				if (d_count >= 1.0) {
					current_sim = 0.0;
				}
			}
		}
		
		// Extreme cleanup at the bottom (lower 15%)
		if (UV.y > 0.85) {
			// Max discard for background at the feet
			current_sim = 0.95;
			// Discard anything that is desaturated (even darker grays)
			if (diff_gray < 0.45) {
				current_sim = 1.0; 
			}
		}
		
		// Catch artifacts in the corners
		float corner_dist = distance(UV, vec2(0.5, 0.5));
		if (corner_dist > 0.6) {
			current_sim = max(current_sim, 0.15);
		}
		
		float mask = smoothstep(current_sim, current_sim + current_smooth, diff_white);
		
		if (mask <= 0.0) {
			discard;
		}
		
		// Aggressive black outline to hide white fringes
		float outline_factor = smoothstep(0.0, 0.8, mask);
		ALBEDO = mix(vec3(0.0, 0.0, 0.0), rgb, outline_factor);
		ALPHA = mask * rgba.a;
	}
}
