shader_type spatial;

uniform sampler2D atlas_texture;
uniform vec4 block_uv;  // x, y, width, height в UV координатах
uniform float lod_factor = 1.0;  // Автоматически от LODManager

void fragment() {
    vec2 uv = vec2(
        block_uv.x + (UV.x * block_uv.z),
        block_uv.y + (UV.y * block_uv.w)
    );
    
    // Дополнительное сглаживание для LOD
    vec4 color = texture(atlas_texture, uv);
    
    #ifdef LOD_QUALITY
        // Бикубическая интерполяция для лучшего качества
        color = textureLod(atlas_texture, uv, lod_factor);
    #endif
    
    ALBEDO = color.rgb;
}