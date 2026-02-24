shader_type spatial;

render_mode blend_mix, unshaded, cull_disabled;

uniform sampler2D atlas_texture : filter_nearest, repeat_disable;
uniform vec2 block_uv_offset;
uniform vec2 block_uv_size;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	vec2 atlas_size = vec2(textureSize(atlas_texture, 0));
	vec2 block_texels = block_uv_size * atlas_size;
	
	vec2 snapped_uv = (floor(UV * block_texels) + 0.5) / block_texels;
	
	vec2 half_texel = 0.5 / block_texels;
	snapped_uv = clamp(snapped_uv, half_texel, 1.0 - half_texel);
	
	vec2 final_uv = block_uv_offset + snapped_uv * block_uv_size;
	
	vec4 color = texture(atlas_texture, final_uv);
	
	// Альфа-тест: отбрасываем прозрачные пиксели
	if (color.a < alpha_scissor_threshold) {
		discard;
	}
	
	ALBEDO = color.rgb;
	ALPHA = 1.0; // После теста — полностью непрозрачный
}