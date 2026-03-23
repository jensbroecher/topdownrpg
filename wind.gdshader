shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D texture_albedo : source_color, filter_nearest, hint_default_white;
uniform float alpha_scissor_threshold = 0.5;

uniform float wind_speed = 1.0;
uniform float wind_strength = 0.1;

void vertex() {
	// Wind sway
	float height_factor = 1.0 - UV.y; // 0 at bottom, 1 at top
	float time = TIME * wind_speed + NODE_POSITION_WORLD.x + NODE_POSITION_WORLD.z;
	VERTEX.x += sin(time) * wind_strength * height_factor;
}

void fragment() {
	vec4 albedo_tex = texture(texture_albedo, UV);
	ALBEDO = albedo_tex.rgb;
	ALPHA = albedo_tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
}
