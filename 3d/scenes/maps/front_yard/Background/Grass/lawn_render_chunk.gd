@tool
extends Node3D
class_name LawnRenderChunk

## 纯渲染区块：LawnGrid 提供合并后的实例数据，本节点只创建 MultiMeshInstance3D。

func rebuild(
	merged_transforms_by_key: Dictionary,
	merged_custom_data_by_key: Dictionary,
	model_meshes: Array[Mesh],
	grass_materials_by_variant: Array,
	chunk_aabb: AABB,
	grass_cast_shadow: bool = true
) -> void:
	clear_generated_renderers()
	for key in merged_transforms_by_key.keys():
		var transforms: Array = merged_transforms_by_key[key]
		if transforms.is_empty() or not merged_custom_data_by_key.has(key):
			continue
		var custom_data: Array = merged_custom_data_by_key[key]
		if not key is Vector2i:
			continue
		var style_id: int = key.x
		var variant_index: int = key.y
		if style_id < 0 or style_id >= grass_materials_by_variant.size():
			continue
		var style_materials: Array = grass_materials_by_variant[style_id]
		if variant_index < 0 or variant_index >= model_meshes.size() or variant_index >= style_materials.size():
			continue
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_custom_data = true
		multimesh.mesh = model_meshes[variant_index]
		multimesh.instance_count = transforms.size()
		multimesh.custom_aabb = chunk_aabb
		for instance_index in range(transforms.size()):
			multimesh.set_instance_transform(instance_index, transforms[instance_index])
			multimesh.set_instance_custom_data(instance_index, custom_data[instance_index])
		var renderer := MultiMeshInstance3D.new()
		renderer.name = "ChunkGrass_Style_%d_Variant_%d" % [style_id, variant_index]
		renderer.multimesh = multimesh
		renderer.material_override = style_materials[variant_index]
		renderer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if grass_cast_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		renderer.set_meta("lawn_generated", true)
		add_child(renderer)

func clear_generated_renderers() -> void:
	for child in get_children():
		if child.get_meta("lawn_generated", false):
			child.free()
