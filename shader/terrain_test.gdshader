shader_type spatial;
#include "res://shader/noise.gdshaderinc"

varying vec3 world_position;
uniform vec3 camera_position;
// Textures for material
uniform sampler2D gravel_texture;
uniform sampler2D normal_texture;
uniform sampler2D metal_texture;
uniform sampler2D metal_normal_texture;
uniform sampler2D metal_roughness_texture;
uniform sampler2D metal_metallic_texture;
uniform float texture_scale = 1.0;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec2 get_distorted_uv(vec2 original_uv, vec2 position, float distortion_strength) {
	float noise1 = cnoise2D(position * 0.1);
	float noise2 = cnoise2D(position * 0.2);
	float noise3 = cnoise2D(position * 0.4);

	vec2 distortion = vec2(
		noise1 * 0.5 + noise2 * 0.3 + noise3 * 0.2,
		noise1 * 0.5 + noise2 * 0.3 + noise3 * 0.2
	) * distortion_strength;

	return original_uv + distortion;
}

void fragment() {
	float scale_variation = 1.0 + cnoise2D(world_position.xz * 0.05) * 0.1;
	vec2 base_uv = UV * texture_scale * scale_variation;

	vec2 distorted_uv = get_distorted_uv(base_uv, world_position.xz, 0.005);

	vec2 second_uv = base_uv * 1.7 + vec2(0.33, 0.66);

	float blend_factor = (cnoise2D(world_position.xz * 0.015) * 0.3 + 0.5);
	vec2 final_uv = mix(distorted_uv, second_uv, blend_factor);

	//float metal_raw = cnoise2D(vec2(world_position.x * 0.8, world_position.z * 0.2)) - 0.5;
	float metal_raw = 0.0;

	float metal = smoothstep(-0.001, 0.001, metal_raw);
	float metal_inv = 1.0 - metal;

	vec3 gravel_color = texture(gravel_texture, final_uv).rgb;
	vec3 metal_color = texture(metal_texture, final_uv).rgb;
	float metal_roughness = texture(metal_roughness_texture, final_uv).r;
	float metal_metallic = texture(metal_metallic_texture, final_uv).r;
	vec3 gravel_normal = texture(normal_texture, final_uv).rgb;
	vec3 metal_normal = texture(metal_normal_texture, final_uv).rgb;

	vec3 final_color = mix(gravel_color, metal_color, metal);

	ALBEDO = final_color;
	ROUGHNESS = mix(1.0, metal_roughness, metal);
	METALLIC = mix(0.0, metal_metallic, metal);

	NORMAL_MAP = mix(gravel_normal, metal_normal, metal);
	NORMAL_MAP_DEPTH = 2.0 * (metal_inv + 0.2);
}