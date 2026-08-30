# FrontYard 编辑器预览

打开 `FrontYard.tscn` 后，`@tool` 脚本会在编辑器中生成边框、草坪数据和区块渲染节点；底板是场景中持久保存的节点。场景层级为：

```text
FrontYard
├─ Background
│  ├─ Camera3D
│  ├─ DirectionalLight3D
│  ├─ WorldEnvironment
│  ├─ Grass
│  │  ├─ Board
│  │  │  └─ BoardBase
│  │  └─ LawnGrid
│  │     └─ LawnCell_row_column
│  │        └─ GrassRenderer         # 保留为单格数据/编辑容器
│  │     └─ LawnRenderChunk_row_column
│  │        ├─ ChunkGrass_Style_0_Variant_0
│  │        └─ ...                   # 每个样式×模型变体一个 MultiMeshInstance3D
│  └─ Decorations
└─ AnimatedSprite3D                  # 向日葵，保持独立于背景
```

相机、平行光、环境、`LawnGrid` 和 `Decorations` 可以在场景树中重新挂载；`front_yard.gd` 会按节点名递归解析它们，不要求固定父节点。建议保持上面的容器结构，便于在文件系统和 Scene Tree 中按背景/草坪归类。

`FrontYard` 只负责场景编排；`Background` 集中管理相机、灯光、环境、装饰和草坪背景，`Background/Grass` 集中管理底板与草坪生成。`Board/BoardBase` 是场景中持久保存的底板节点，不会由脚本在运行时创建或删除；可以直接在 `Board` 下继续添加碰撞体、建筑基座和其他场景内容。`LawnGrid` 负责行列、格子尺寸、模型资源、共享材质、噪声和渲染区块；每个 `LawnCell` 负责自己的草实例数据和编辑覆盖，`LawnRenderChunk` 负责把多个格子的同类实例合并成 MultiMesh。编辑器中的 `LawnCell` 会保留场景 owner 以便逐格编辑，渲染区块是临时预览节点，不会写回场景文件。

## 相机和灯光

在 `FrontYard` Inspector 中调整 `camera_down_angle`、`camera_distance`、`camera_height` 和 `camera_fov`。其中 `camera_distance` 控制 Z 轴水平距离，`camera_height` 控制 Y 轴垂直距离，两者可以独立组合出不同视角；脚本只同步相机位置、旋转和 FOV，不覆盖 Projection、Current、裁剪面或其他 Camera3D 属性。当前场景保留透视投影；`DirectionalLight3D` 的位置、旋转、能量和阴影全部由 Inspector 管理，脚本不会跟随相机修改光源。

## 草坪全局参数

选中 `LawnGrid`，展开 `settings` 资源：

- `model_scene`：默认 `res://Assets/Textures/Grass/stylized_lawn_demo.glb`；替换为其他 GLB 可更换草簇模型。
- `model_mesh_name_filter`：默认留空，收集 GLB 中全部网格；填写名称片段后才会筛选。
- `model_variant_weights`：按收集顺序设置各模型占比。当前 GLB 的顺序为 `Grass_Fine`、`Grass_Broad`、`Plant_Coin`，资源中的比例可按需调整。
- `model_clumps_per_cell`：每格基础草簇数量，默认 `25`。
- `model_grass_scale`：模型基础缩放，默认 `0.68`。
- `grass_cast_shadow`：模型草是否投射阴影，默认开启；关闭可减少草模型阴影通道开销，不影响草模型接收场景阴影。
- `dark_color`、`light_color`：棋盘格两种草色，覆写白膜模型材质。
- `cell_coverage`：草簇中心的采样跨度；可略微超过格子范围以保持边缘密度，但 shader 会裁掉所有越界片段。
- `grass_cell_overflow`：允许草簇越过自身格子边界的范围，默认 `0.20`；草可以自然渗透到相邻格，但仍会在扩展后的范围外裁切。
- 格子分界只来自深浅草色和草簇密度，`BoardBase` 使用统一中性绿色，不再绘制棋盘格地板。底板尺寸当前为 `18 × 10`，若草坪行列或格子尺寸发生变化，请在 Inspector 中同步调整 `BoardBase` 的 `PlaneMesh` 尺寸；脚本不会覆盖你对底板及其子节点的编辑。
- `render_chunk_rows`、`render_chunk_columns`：一个渲染区块包含的格子行列数，默认均为 `3`。增大可减少 MultiMesh 节点和绘制提交，减小可缩小单格修改时的重建范围；它们不改变草模型、实例数量或材质精度。

### 草材质

- `grass_light_wrap`：背光面的保留亮度，避免草面完全死黑。
- `grass_highlight_color`：草尖像素亮边颜色。
- `grass_highlight_strength`：亮边与基础草色的混合强度。
- `grass_highlight_threshold`：亮边开始出现的模型高度比例。
- `grass_highlight_hardness`：亮边分段硬度，值越高越像硬朗的像素块。
- `grass_emission_strength`：亮边的低强度自发光，只作用于高光带并配合场景 Glow。
- `grass_root_color`：每片叶片根部的颜色，默认较深，用于压住模型底部的亮度。
- `grass_tip_color`：每片叶片顶端的颜色，默认较亮，用于形成自然的叶尖提亮。
- `grass_gradient_strength`：根部到顶端渐变与基础草色的混合强度；设为 `0` 可关闭渐变。
- `grass_gradient_exponent`：渐变曲线指数；增大后亮色更集中在叶尖，减小后中段更早变亮。
- `grass_wind_strength`：草叶顶部的最大水平摆动距离；默认 `0.035`，设为 `0` 可关闭风摆。
- `grass_wind_animated`：是否随时间动态摆动；关闭后草簇保留不同的静态弯曲姿态，适合静态截图或低性能模式。
- `grass_wind_speed`：风摆动画速度；设为 `0` 会冻结在初始相位。
- `grass_wind_frequency`：风摆空间频率；值越大，不同位置草簇的摆动相位差越明显。
- `grass_wind_direction`：XZ 平面内的风向向量；方向会自动归一化，零向量会回退为 X 轴方向。

编辑器材质同步时会把风向归一化一次再传给 shader；设置资源保留原始 Inspector 数值和签名语义，零向量仍回退为 X 轴方向。

草 shader 会使用 GLB 顶点色做轻微色差，并按每个模型变体自己的包围盒高度计算根部到顶端渐变；根色和顶色会按深/浅样式基础色的亮度比例缩放，因此渐变不会抹平格子之间的明暗差异。方向受光始终来自当前 `DirectionalLight3D`，不会在 shader 中写死世界光照方向。每个“深/浅样式 × 模型变体”拥有独立 `ShaderMaterial`，因此 `Grass_Fine`、`Grass_Broad` 和 `Plant_Coin` 的叶尖位置不会互相影响。
草 shader 还会按叶片高度应用轻微顶点风摆：根部保持固定，顶部使用两组正弦波叠加；实例位置和 yaw 会生成不同相位，避免整块草坪同步晃动。风摆只修改顶点位置和小幅法线倾斜，不改变现有密度、模型权重、渐变或格子裁剪参数。
- `density_noise_strength`、`density_noise_frequency`：按格子中心连续采样的密度起伏。
- `min_clumps_per_cell`：噪声后的密度下限，避免出现裸露格子，默认 `9`。
- `height_noise_strength`、`height_noise_frequency`：按草簇世界坐标连续采样的高度起伏。
- `grass_scale_noise_strength`：同一份世界坐标噪声对草簇整体宽高的影响强度，默认 `0.35`；相邻格边缘不会重置噪声。
- `noise_seed`：噪声种子；相同种子会保持稳定分布。

模型模式由 `LawnGrid` 共享一次网格、按样式和变体创建材质，以及两个 `FastNoiseLite` 对象。每格使用固定配额分配变体，再用随机种子打乱位置，因此不同模型会按权重全部出现。每个 `LawnCell` 将实例变换和自定义数据交给所属 `LawnRenderChunk`，区块按样式×模型变体各创建一个 MultiMesh；Shader 使用实例世界位置减去 `INSTANCE_CUSTOM.rg` 中的格子中心逐实例裁剪，因此合批后草仍可有限跨格但不会无限蔓延。草 shader 使用双面法线受光和根部到顶端渐变，修复 `Grass_Fine` 与 `Grass_Broad` 叶片法线分散导致的受光弱问题，`Plant_Coin` 的顶点色层次仍然保留。

## 单格覆盖

选中某个 `LawnCell`：

- `density_override = -1`：继承全局密度；设置非负值可只改变该格的模型草数量。
- `style_override = -1`：继承棋盘格样式；设置 `0` 或 `1` 可固定该格颜色。
- `height_multiplier`：在高度噪声结果上叠加该格高度倍率。

也可以从代码调用 `FrontYard.set_cell_grass_density(row, column, density)` 和 `FrontYard.set_cell_grass_style(row, column, style_id)`；调用只重建对应的 `LawnCell`。

## 编辑器刷新和运行时

修改 `LawnGrid` 的行列、尺寸、`settings` 字段或单格覆盖后，编辑器会自动刷新。刷新由 dirty 状态驱动：普通帧不会构造完整字符串签名，设置资源的 `changed` 信号会立即标记重建；为兼容未发出信号的脚本修改，仍保留 250ms 一次的签名兜底检查。视口没有立即变化时，点击 `LawnGrid` 或 `FrontYard` Inspector 中的 **Rebuild** 按钮。运行时会使用同样的节点和配置重建草坪，不依赖编辑器生成的 MultiMesh 子节点，也不会重新生成或替换 `Board/BoardBase`。修改单个 `LawnCell` 时只重建其所属渲染区块，其他区块保持不变。

每个 `LawnRenderChunk` 的 `MultiMesh.custom_aabb` 会根据合批后的实际模型包围盒、实例变换和最大世界空间风摆位移计算，并保留小幅数值安全余量。不要直接缩小 AABB 以追求裁剪率；必须确认区块边缘、风摆顶部和方向光阴影没有提前消失。

草坪 shader 仍使用一套完整路径提供双面草叶、逐实例格子裁剪、风摆、根尖渐变、顶端高光、顶点色、包裹光照和零镜面反射。优化只移除由设置归一化保证的重复保护；`cull_disabled`、片元 `discard`、自定义 `light()`、正弦风摆和分段高光不能在没有 profiling 与画面对比的情况下删除或替换。

FrontYard 只使用 `settings.model_scene` 中收集到的 GLB 网格生成模型草。模型资源为空、无法实例化或过滤后没有网格时，`LawnCell` 会清空自己的 `GrassRenderer` 并发出 warning，不会自动切换到其他草生成方式。
