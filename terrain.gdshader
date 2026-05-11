shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D noise_texture : filter_linear_mipmap;
uniform float edge_distance : hint_range(0.5, 1.0) = 0.85;
uniform float noise_scale : hint_range(0.01, 2.0) = 0.1;
uniform float noise_strength : hint_range(0.0, 1.0) = 0.2;
uniform float material_priority : hint_range(0.0, 10.0) = 0.0;
uniform float green_boost : hint_range(0.0, 4.0) = 1.6;
uniform float height_scale : hint_range(0.0, 0.5) = 0.15;
uniform float variation_scale : hint_range(0.01, 1.0) = 0.05;
uniform float variation_strength : hint_range(0.0, 1.0) = 0.2;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Use material priority + world hash to stack tiles and avoid Z-fighting.
	// Higher priority materials (like stone) will render slightly above lower ones (like grass).
	float hash = fract(sin(dot(world_pos.xz ,vec2(12.9898,78.233))) * 43758.5453);
	VERTEX.y += (material_priority * 0.01) + (hash * 0.002);
}

void fragment() {
	// Sample world-space noise for organic edges and height variation.
	float noise = texture(noise_texture, world_pos.xz * noise_scale).r;

	// Parallax effect for standing grass.
	vec2 modified_uv = UV;
	vec4 albedo = texture(albedo_texture, modified_uv);
	
	// Removed color variations to keep texture pure as requested.
	albedo.rgb *= 1.0;
	
	// Clean floor for grass, organic edges only for paths/stone.
	if (material_priority > 0.5) {
		// Distance from center of the tile (0.5, 0.5) in UV space.
		vec2 center_dist = abs(UV - 0.5) * 2.0;
		float dist = max(center_dist.x, center_dist.y);
		
		// Smoother, more organic curves for the edges.
		// lower noise_scale (already set in tiles.tres) + higher influence
		float organic_noise = noise * 1.5 - 0.25; 
		float threshold = edge_distance + (organic_noise - 0.5) * noise_strength;
		
		if (dist > threshold) {
			discard;
		}
	}
	
	ALBEDO = albedo.rgb;
	
	ROUGHNESS = 0.8;
}
