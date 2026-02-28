shader_type spatial;

render_mode blend_mix, unshaded, cull_back, shadows_disabled, depth_draw_opaque;

// ✅ source_color — говорит GPU: "эта текстура в sRGB, конвертируй при чтении"
uniform sampler2D atlas_texture : source_color, filter_nearest, repeat_disable;
uniform vec2 block_uv_offset;
uniform vec2 block_uv_size;

void fragment() {
	vec2 atlas_size = vec2(textureSize(atlas_texture, 0));
	vec2 block_texels = block_uv_size * atlas_size;
	
	vec2 snapped_uv = (floor(UV * block_texels) + 0.5) / block_texels;
	
	vec2 half_texel = 0.5 / block_texels;
	snapped_uv = clamp(snapped_uv, half_texel, 1.0 - half_texel);
	
	vec2 final_uv = block_uv_offset + snapped_uv * block_uv_size;
	
	vec4 color = texture(atlas_texture, final_uv);
	ALBEDO = color.rgb;
}