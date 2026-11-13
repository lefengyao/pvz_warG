# 2D / 3D 项目整合设计

日期：2026-11-13

## 目标

将复制来的 2D 项目与已有的 3D 前院原型整合为一个 Godot 项目。2D 游戏流程作为 F5 主流程，3D FrontYard 作为独立开发场景，通过 F6 启动。整合过程保留现有玩法、资源、场景 UID、插件和测试能力，避免直接覆盖重复文件。

## 当前项目边界

复制来的项目位于 `E:/生产项目/项目/Godot/pvz_warG`，当前以 2D 游戏为主，使用 `src/`、`scenes/`、`assets/`、`resources/` 结构，包含主菜单、选关、植物、僵尸、子弹、关卡和 UI 流程。

已有项目位于 `E:/生产项目/项目/GodotProject/pvz_warG/pvz_warG`，包含 3D FrontYard、草坪渲染、3D 相机和光照、3D 卡牌展示、ECSmini，以及一部分旧的 2D 内容。当前整合根目录是 `E:/生产项目/项目/GodotProject/pvz_warG`。

旧项目中的 2D 内容与复制项目存在同名或同功能资源，必须先比较路径、哈希、UID 和引用关系，再决定保留版本。

## 目标目录

```text
project-root/
├─ 2d/
│  ├─ src/
│  ├─ scenes/
│  ├─ assets/
│  └─ resources/
├─ 3d/
│  ├─ src/
│  ├─ scenes/
│  ├─ assets/
│  └─ resources/
├─ shared/
│  ├─ src/
│  ├─ scenes/
│  ├─ assets/
│  └─ resources/
├─ addons/
├─ tests/
├─ tools/
├─ docs/
└─ project.godot
```

`addons/` 必须保留在项目根目录，以便 Godot 正确发现插件。测试、工具和文档也保持根目录职责，不放进 2D 或 3D 模块。

## 分类规则

### 2D

以下内容归入 `2d/`：

- 使用 `Node2D`、`Sprite2D`、`Camera2D` 或 `Control` 作为主要运行节点的场景。
- 复制项目中的关卡、植物、僵尸、子弹、对象和 2D UI。
- 对应的 `src/plants`、`src/zombies`、`src/levels`、`src/projectiles`、`src/objects` 和 `src/ui` 代码。
- 2D 角色帧、地图贴图、2D 特效和关卡专用资源。

### 3D

以下内容归入 `3d/`：

- `Map/FrontYard` 及其背景、草坪、相机、光照和环境节点。
- `Manager/EcsFrontYardDemo.gd` 与 `EcsFrontYardDemo.tscn`。
- `Scene/CardsBox` 中使用 `MeshInstance3D`、`Sprite3D` 和 `Camera3D` 的卡牌展示。
- 3D 模型、草坪着色器、渲染区块和 3D 专用材质。
- 3D 专用管理器、3D 演示场景和 3D ECS 展示代码。

### 共享

以下内容归入 `shared/` 或继续保留在根目录：

- 不依赖具体渲染维度的基础角色属性、状态机、事件接口和数据资源。
- 公共音频、字体、通用 UI 数据和项目级配置资源。
- ECSmini 的核心运行时、查询、存储、持久化和调度代码。
- ECSmini 的 2D、3D 适配器继续按适配维度区分。
- `addons/ecsmini`、其他 Godot 插件、测试、工具和文档。

UI 的归属由运行方式决定：2D 游戏内界面归入 `2d/`；跨场景通用设置和音频控件归入 `shared/`；3D 场景专用 HUD 归入 `3d/`。

## 配置合并

以复制项目的 `project.godot` 作为配置基线，保留其 2D 主流程和现有 Autoload 名称。将已有项目的 3D 必要配置、插件和 ECSmini 注册信息合并进去。

- `run/main_scene` 保持 2D 主菜单场景。
- 3D FrontYard 和 ECS 演示通过独立场景 F6 运行。
- 合并 Autoload 时保留唯一实例，避免 `AudioManager`、`Settings`、`EventBus` 等重复注册。
- 3D 内容需要的 Forward Plus 和 Jolt Physics 配置加入最终项目，并用 2D 回归测试确认不影响 2D 流程。
- `ecsmini` 和 `pixel_art_filter` 等插件统一由根目录 `addons/` 管理。

## 迁移顺序

1. 建立两个项目的文件、哈希、UID 和引用清单。
2. 将已有项目暂存为 legacy 来源，禁止在未核对前直接删除或覆盖。
3. 确认 `E:/生产项目/项目/GodotProject/pvz_warG` 为唯一项目根目录。
4. 迁移复制项目的 2D 内容到 `2d/`，同步更新所有 `res://` 引用。
5. 迁移 FrontYard、3D 卡牌和 ECS 演示到 `3d/`，保留草坪和模型资源的职责边界。
6. 将无维度依赖的基础代码、公共资源和插件归入 `shared/` 或根目录。
7. 合并 `project.godot`、Autoload、插件配置和输入设置。
8. 处理路径、UID、`.import`、脚本 `preload/load` 和场景外部资源引用。
9. 对同名资源执行哈希和行为对比；只有确认不再被引用后才清理重复文件。
10. 完成 2D、3D 和整合验证后，再更新 README 和迁移记录。

## 验证标准

### 2D 验证

- `tools/verify_references.py` 通过。
- `tools/verify_project.ps1` 通过。
- F5 可以进入主菜单、选关、选卡和第一关流程。
- 2D 场景不出现路径错误、脚本错误、Autoload 重复或资源缺失。

### 3D 验证

- FrontYard 背景结构契约测试通过。
- 草坪格子边界和草坪运行时渲染测试通过。
- ECSmini Godot 测试、示例 smoke test 和基准正确性检查通过。
- `EcsFrontYardDemo.tscn` 可以独立启动，点击格子和僵尸演示行为保持正常。

### 整合验证

- F5 启动 2D 主流程，F6 启动指定的 3D 场景。
- 2D 和 3D 资源路径不会互相覆盖。
- Autoload、插件和音频总线没有重复定义。
- Godot 编辑器无导入错误，UID 和外部资源引用完整。
- 旧项目和复制项目的原始素材在迁移前后可追溯。

## 风险与处理

- `res://` 路径变化：使用引用清单和静态扫描逐项更新。
- 同名资源冲突：按哈希、UID 和运行行为对比，不按文件名直接覆盖。
- 2D 与 3D 渲染配置冲突：先合并配置，再分别运行两套场景验证。
- Autoload 重复：以最终 `project.godot` 为唯一注册来源。
- 旧项目中混合的 2D/3D 内容：按场景根节点和实际依赖分类，不能只按目录名判断。
- 二进制资源和导入缓存：保留原始资源，迁移后重新导入并检查 `.import` 状态。

## 非目标

本阶段不重写 2D 战斗规则，不把 2D 角色转换为 3D 模型，不把 3D FrontYard 直接改造成 2D 关卡，也不在未完成验证前删除旧目录或重复资源。
