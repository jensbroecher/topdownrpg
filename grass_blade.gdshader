shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, hint_default_white;
uniform float alpha_scissor_threshold : hint_range(0, 1) = 0.5;
uniform float wind_speed = 1.0;
uniform float wind_strength = 0.1;
uniform float wind_scale = 1.0;

void vertex() {
	// Simple wind sway
	float height_factor = 1.0 - UV.y;
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float time = TIME * wind_speed + world_pos.x * wind_scale + world_pos.z * wind_scale;
	VERTEX.x += sin(time) * wind_strength * height_factor;
	VERTEX.z += cos(time * 0.7) * wind_strength * height_factor;
}

void fragment() {
	vec4 albedo_tex = texture(texture_albedo, UV);
	ALBEDO = albedo_tex.rgb;
	ALPHA = albedo_tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
}
