shader_type spatial;

render_mode blend_mix, unshaded, cull_back, shadows_disabled, depth_draw_opaque;

uniform sampler2D atlas_texture : source_color, filter_nearest, repeat_disable;

// Базовая текстура (земля)
uniform vec2 block_uv_offset;
uniform vec2 block_uv_size;

// Оверлей (трава с прозрачностью)
uniform vec2 overlay_uv_offset;
uniform vec2 overlay_uv_size;

// Включён ли оверлей
uniform bool overlay_enabled = false;

void fragment() {
	vec2 atlas_size = vec2(textureSize(atlas_texture, 0));
	
	// ═══ БАЗОВАЯ ТЕКСТУРА ═══
	vec2 base_texels = block_uv_size * atlas_size;
	vec2 base_snapped = (floor(UV * base_texels) + 0.5) / base_texels;
	vec2 base_half = 0.5 / base_texels;
	base_snapped = clamp(base_snapped, base_half, 1.0 - base_half);
	vec2 base_uv = block_uv_offset + base_snapped * block_uv_size;
	
	vec4 base_color = texture(atlas_texture, base_uv);
	
	if (overlay_enabled) {
		// ═══ ОВЕРЛЕЙ ═══
		vec2 over_texels = overlay_uv_size * atlas_size;
		vec2 over_snapped = (floor(UV * over_texels) + 0.5) / over_texels;
		vec2 over_half = 0.5 / over_texels;
		over_snapped = clamp(over_snapped, over_half, 1.0 - over_half);
		vec2 over_uv = overlay_uv_offset + over_snapped * overlay_uv_size;
		
		vec4 over_color = texture(atlas_texture, over_uv);
		
		// Смешивание: оверлей поверх базы по альфа-каналу оверлея
		base_color.rgb = mix(base_color.rgb, over_color.rgb, over_color.a);
	}
	
	ALBEDO = base_color.rgb;
}