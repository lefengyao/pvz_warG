shader_type spatial;

render_mode cull_disabled, diffuse_burley;

uniform bool surface_is_crack = false;
uniform vec4 stone_color : source_color = vec4(0.851, 0.812, 0.718, 1.0);
uniform vec4 grain_color : source_color = vec4(0.608, 0.553, 0.443, 1.0);
uniform float grain_scale : hint_range(1.0, 64.0, 1.0) = 16.0;
uniform float grain_strength : hint_range(0.0, 0.35, 0.01) = 0.07;
uniform vec4 crack_color : source_color = vec4(0.400, 0.337, 0.239, 1.0);
uniform float damage_contrast : hint_range(0.0, 1.0, 0.01) = 0.85;
uniform float roughness : hint_range(0.0, 1.0, 0.01) = 0.92;
uniform float specular : hint_range(0.0, 1.0, 0.01) = 0.16;

varying vec3 brick_local_position;

float hash13(vec3 value) {
	value = fract(value * 0.1031);
	value += dot(value, value.yzx + 33.33);
	return fract((value.x + value.y) * value.z);
}

void vertex() {
	brick_local_position = VERTEX;
}

void fragment() {
	vec3 grain_cell = floor(brick_local_position * max(grain_scale, 1.0));
	float grain_mask = step(0.74, hash13(grain_cell)) * clamp(grain_strength, 0.0, 0.35);
	vec3 stone_albedo = mix(stone_color.rgb, grain_color.rgb, grain_mask);
	vec3 crack_albedo = mix(stone_color.rgb, crack_color.rgb, clamp(damage_contrast, 0.0, 1.0));

	if (surface_is_crack) {
		ALBEDO = crack_albedo;
	} else {
		ALBEDO = stone_albedo;
	}
	ROUGHNESS = clamp(roughness, 0.0, 1.0);
	SPECULAR = clamp(specular, 0.0, 1.0);
}
