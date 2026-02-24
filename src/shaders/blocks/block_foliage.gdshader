shader_type spatial;
render_mode blend_mix, unshaded, shadows_disabled, cull_back;

uniform sampler2D atlas_texture : filter_nearest, repeat_disable;
uniform vec2 block_uv_offset;
uniform vec2 block_uv_size;
uniform float alpha_scissor_threshold = 0.6;

void fragment() {
	vec2 uv = vec2(
		block_uv_offset.x + (UV.x * block_uv_size.x),
		block_uv_offset.y + (UV.y * block_uv_size.y)
	);
	
	vec4 color = texture(atlas_texture, uv);
	
	if (color.a < alpha_scissor_threshold) {
		discard;
	}
	
	ALBEDO = color.rgb;
	ALPHA = 1.0;
}