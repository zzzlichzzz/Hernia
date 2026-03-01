shader_type spatial;

render_mode blend_mix, unshaded, cull_back, shadows_disabled, depth_draw_opaque;

uniform sampler2D atlas_texture : source_color, filter_nearest, repeat_disable;

uniform vec2 top_uv_offset;
uniform vec2 top_uv_size;

uniform vec2 bottom_uv_offset;
uniform vec2 bottom_uv_size;

uniform vec2 north_uv_offset;
uniform vec2 north_uv_size;

uniform vec2 south_uv_offset;
uniform vec2 south_uv_size;

uniform vec2 east_uv_offset;
uniform vec2 east_uv_size;

uniform vec2 west_uv_offset;
uniform vec2 west_uv_size;

varying vec3 world_normal;

void vertex() {
	world_normal = NORMAL;
}

void fragment() {
	vec2 atlas_size = vec2(textureSize(atlas_texture, 0));
	
	vec2 uv_offset;
	vec2 uv_size;
	
	if (world_normal.y > 0.5) {
		uv_offset = top_uv_offset;
		uv_size = top_uv_size;
	} else if (world_normal.y < -0.5) {
		uv_offset = bottom_uv_offset;
		uv_size = bottom_uv_size;
	} else if (world_normal.z < -0.5) {
		uv_offset = north_uv_offset;
		uv_size = north_uv_size;
	} else if (world_normal.z > 0.5) {
		uv_offset = south_uv_offset;
		uv_size = south_uv_size;
	} else if (world_normal.x > 0.5) {
		uv_offset = east_uv_offset;
		uv_size = east_uv_size;
	} else {
		uv_offset = west_uv_offset;
		uv_size = west_uv_size;
	}
	
	// Texel snapping
	vec2 block_texels = uv_size * atlas_size;
	vec2 snapped_uv = (floor(UV * block_texels) + 0.5) / block_texels;
	vec2 half_texel = 0.5 / block_texels;
	snapped_uv = clamp(snapped_uv, half_texel, 1.0 - half_texel);
	
	vec2 final_uv = uv_offset + snapped_uv * uv_size;
	
	vec4 color = texture(atlas_texture, final_uv);
	ALBEDO = color.rgb;
}