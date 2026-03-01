shader_type spatial;

render_mode blend_mix, unshaded, cull_back, shadows_disabled, depth_draw_opaque;

uniform sampler2D atlas_texture : source_color, filter_nearest, repeat_disable;

// Верхняя грань
uniform vec2 top_uv_offset;
uniform vec2 top_uv_size;

// Нижняя грань
uniform vec2 bottom_uv_offset;
uniform vec2 bottom_uv_size;

// Боковые грани (база)
uniform vec2 side_uv_offset;
uniform vec2 side_uv_size;

// Оверлей для боков
uniform vec2 overlay_uv_offset;
uniform vec2 overlay_uv_size;
uniform bool overlay_enabled = false;

varying vec3 model_normal;

void vertex() {
	model_normal = NORMAL;
}

void fragment() {
	vec2 atlas_size = vec2(textureSize(atlas_texture, 0));
	
	// Определяем грань по нормали
	vec2 uv_offset;
	vec2 uv_size;
	bool apply_overlay = false;
	
	if (model_normal.y > 0.5) {
		uv_offset = top_uv_offset;
		uv_size = top_uv_size;
	} else if (model_normal.y < -0.5) {
		uv_offset = bottom_uv_offset;
		uv_size = bottom_uv_size;
	} else {
		uv_offset = side_uv_offset;
		uv_size = side_uv_size;
		apply_overlay = overlay_enabled;
	}
	
	// Texel snapping для базовой текстуры
	vec2 base_texels = uv_size * atlas_size;
	vec2 base_snapped = (floor(UV * base_texels) + 0.5) / base_texels;
	vec2 base_half = 0.5 / base_texels;
	base_snapped = clamp(base_snapped, base_half, 1.0 - base_half);
	vec2 final_uv = uv_offset + base_snapped * uv_size;
	
	vec4 color = texture(atlas_texture, final_uv);
	
	// Оверлей на боках (без поворота)
	if (apply_overlay) {
		vec2 over_texels = overlay_uv_size * atlas_size;
		vec2 over_snapped = (floor(UV * over_texels) + 0.5) / over_texels;
		vec2 over_half = 0.5 / over_texels;
		over_snapped = clamp(over_snapped, over_half, 1.0 - over_half);
		vec2 over_uv = overlay_uv_offset + over_snapped * overlay_uv_size;
		
		vec4 over_color = texture(atlas_texture, over_uv);
		color.rgb = mix(color.rgb, over_color.rgb, over_color.a);
	}
	
	ALBEDO = color.rgb;
}