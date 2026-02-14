shader_type spatial;
render_mode blend_mix, depth_draw_opaque;

uniform sampler2D atlas_texture;
uniform vec4 block_uv; // x, y, width, height в UV координатах
uniform float lod_factor = 1.0;

void fragment() {
	// Вычисляем UV внутри блока
	vec2 uv = vec2(
		block_uv.x + (UV.x * block_uv.z),
		block_uv.y + (UV.y * block_uv.w)
	);
	
	// Используем textureLOD для контроля качества
	vec4 color = texture(atlas_texture, uv);
	
	ALBEDO = color.rgb;
	ROUGHNESS = 0.8;
	METALLIC = 0.0;
}

void vertex() {
	// Можно добавить визуализацию LOD через цвет
	if (lod_factor > 1.0) {
		// Легкое изменение цвета для визуализации LOD
		COLOR.rgb = mix(COLOR.rgb, vec3(0.8, 0.9, 1.0), (lod_factor - 1.0) / 7.0);
	}
}