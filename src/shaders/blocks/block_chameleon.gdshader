shader_type spatial;
render_mode blend_mix, unshaded, cull_back, shadows_disabled, depth_draw_opaque;

// Основной атлас текстур
uniform sampler2D atlas_texture : source_color, filter_nearest, repeat_disable;

// Хеш-таблица хамелеонов (без source_color — это данные, не цвет!)
uniform sampler2D chameleon_keys : filter_nearest, repeat_disable;
uniform sampler2D chameleon_data : filter_nearest, repeat_disable;
uniform int chameleon_map_size = 4096;

// UV дефолтной текстуры (до покраски)
uniform vec2 default_uv_offset = vec2(0.0, 0.0);
uniform vec2 default_uv_size = vec2(0.0625, 0.0625);

// Передаём мировую позицию из vertex в fragment
varying vec3 v_world_pos;
varying vec3 v_world_normal;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = mat3(MODEL_MATRIX) * NORMAL;
}

// Хеш-функция — ДОЛЖНА совпадать с GDScript версией!
int hash_voxel(int x, int y, int z) {
	int wx = ((x % 1024) + 1024) % 1024;
	int wy = ((y % 1024) + 1024) % 1024;
	int wz = ((z % 1024) + 1024) % 1024;
	int h = wx * 73 + wy * 523 + wz * 997;
	return h % chameleon_map_size;
}

void fragment() {
	// ═══ 1. Определяем позицию вокселя ═══
	// Сдвигаемся чуть внутрь блока по нормали,
	// чтобы floor() дал правильную позицию на краях
	vec3 interior = v_world_pos - normalize(v_world_normal) * 0.01;
	vec3 voxel_pos = floor(interior);

	// ═══ 2. Ищем в хеш-таблице ═══
	vec2 uv_offset = default_uv_offset;
	vec2 uv_size = default_uv_size;

	int base_hash = hash_voxel(int(voxel_pos.x), int(voxel_pos.y), int(voxel_pos.z));

	// Линейный поиск (до 8 попыток)
	for (int i = 0; i < 8; i++) {
		int idx = (base_hash + i) % chameleon_map_size;
		vec4 key = texelFetch(chameleon_keys, ivec2(idx, 0), 0);

		// Пустой слот — значит нет данных, выходим
		if (key.a < 0.5) {
			break;
		}

		// Проверяем совпадение позиции
		if (abs(key.r - voxel_pos.x) < 0.5 &&
			abs(key.g - voxel_pos.y) < 0.5 &&
			abs(key.b - voxel_pos.z) < 0.5) {
			// Нашли! Берём UV данные
			vec4 data = texelFetch(chameleon_data, ivec2(idx, 0), 0);
			uv_offset = data.rg;
			uv_size = data.ba;
			break;
		}
	}

	// ═══ 3. Применяем текстуру из атласа ═══
	vec2 atlas_size = vec2(textureSize(atlas_texture, 0));
	vec2 block_texels = uv_size * atlas_size;
	vec2 snapped_uv = (floor(UV * block_texels) + 0.5) / block_texels;
	vec2 half_texel = 0.5 / block_texels;
	snapped_uv = clamp(snapped_uv, half_texel, 1.0 - half_texel);

	vec2 final_uv = uv_offset + snapped_uv * uv_size;
	vec4 color = texture(atlas_texture, final_uv);
	ALBEDO = color.rgb;
}