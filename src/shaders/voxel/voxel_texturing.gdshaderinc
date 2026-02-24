// voxel_texturing.gdshaderinc
// Адаптировано из демо godot_voxel

// Эти функции можно использовать в наших шейдерах блоков

// Получить UV координаты из атласа
vec2 get_block_uv(vec2 uv, vec2 block_uv_offset, vec2 block_uv_size) {
	return vec2(
		block_uv_offset.x + (uv.x * block_uv_size.x),
		block_uv_offset.y + (uv.y * block_uv_size.y)
	);
}

// Получить цвет с поддержкой прозрачности
vec4 get_block_color(sampler2D atlas, vec2 uv, 
                    vec2 offset, vec2 size,
                    bool use_alpha, float alpha_threshold) {
	
	vec2 block_uv = get_block_uv(uv, offset, size);
	vec4 color = texture(atlas, block_uv);
	
	if (use_alpha && color.a < alpha_threshold) {
		discard;
	}
	
	return color;
}