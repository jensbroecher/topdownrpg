shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D noise_texture : filter_linear_mipmap;
uniform float edge_distance : hint_range(0.5, 1.0) = 0.85;
uniform float noise_scale : hint_range(0.01, 2.0) = 0.1;
uniform float noise_strength : hint_range(0.0, 1.0) = 0.2;
uniform float material_priority : hint_range(0.0, 10.0) = 0.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Use material priority + world hash to stack tiles and avoid Z-fighting.
	// Higher priority materials (like stone) will render slightly above lower ones (like grass).
	float hash = fract(sin(dot(world_pos.xz ,vec2(12.9898,78.233))) * 43758.5453);
	VERTEX.y += (material_priority * 0.01) + (hash * 0.002);
}

void fragment() {
	vec4 albedo = texture(albedo_texture, UV);
	
	// Distance from center of the tile (0.5, 0.5) in UV space.
	// In a 5m mesh for a 4m grid, dist=0.8 is the exact cell boundary.
	vec2 center_dist = abs(UV - 0.5) * 2.0;
	float dist = max(center_dist.x, center_dist.y);
	
	// Sample world-space noise for organic edges.
	float noise = texture(noise_texture, world_pos.xz * noise_scale).r;
	
	// Hard cutoff with noise jitter ensures tiles interlock without gaps.
	// Centering the threshold around edge_distance (0.85-0.95).
	float threshold = edge_distance + (noise - 0.5) * noise_strength;
	
	if (dist > threshold) {
		discard;
	}
	
	ALBEDO = albedo.rgb;
	// Subtle color variation for more realism.
	ALBEDO *= 0.98 + noise * 0.04;
	ROUGHNESS = 0.8;
}
