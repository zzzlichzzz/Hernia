# scripts/blocks/voxel_block.gd
extends Resource
class_name VoxelBlock

@export var block_name: String = "stone"

# АВТОМАТИЧЕСКИЙ ВЫБОР LOD - БЕЗ УКАЗАНИЯ!
func get_uv() -> Rect2:
	return LODManager.get_block_uv(block_name)

func get_texture() -> AtlasTexture:
	return LODManager.get_block_texture(block_name)

func get_material() -> ShaderMaterial:
	var mat = ShaderMaterial.new()
	mat.shader = preload("res://src/shaders/blocks/block_lod.gdshader")
	mat.set_shader_parameter("atlas_texture", LODManager.get_lod().atlas_texture)
	mat.set_shader_parameter("block_uv", get_uv())
	return mat
