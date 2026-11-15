# pvz_warG

**植物大战僵尸同人塔防 · Godot 4.7.1 · 2D + 3D 双模式**

同一个工程里两种玩法视角：**F5** 进 2D 战役，**F6** 走进 3D 前院。音频、设置、事件和转场两边共用一套。

| 主菜单 · 拼图选关 | 前院战斗 |
| :---: | :---: |
| ![](docs/maintenance/screenshots/main_menu.png) | ![](docs/maintenance/screenshots/first_level_battle.png) |

## 技术

- **引擎**：Godot 4.7.1、Forward Plus（Windows 走 D3D12）、Jolt Physics、纯 GDScript、1920 × 1080。
- **结构**：`2d/` 战役、`3d/` 前院、`shared/` 共用层（音频总线、事件总线、两套状态机、场景转场）。
- **草叶**：`LawnGrid` 按格生成草簇，`INSTANCE_CUSTOM` 打包朝向与尺寸，`lawn_cell_grass.gdshader` 顶点风摆 + 草尖亮边，`LawnRenderChunk` 分块合批（实测 6 chunk / 1756 实例）。
- **ECSmini**：内嵌 ECS 运行时，组件描述行进状态、系统按优先级推进，经 `EcsNodeSync3D` 同步到节点树。
- **输入**：前院全局输入只从 `FrontYard/Manager/PlantLogic` 进入，地图、草坪、UI 不重复监听。
- **验证**：`godot --headless --editor --path . --quit`、`tools/verify_references.py`、`tools/verify_integration.ps1`（加 `-Capture` 出图）。

## 运行

用 Godot 4.7.1 打开根目录，等导入完成后按 **F5** 跑主场景；按 **F6** 可选 `3d/scenes/maps/front_yard/FrontYard.tscn`（前院）、`EcsFrontYardDemo.tscn`（ECS 演示）、`3d/scenes/cards_box/CardsBox.tscn`（卡牌盒）。

## 许可与致谢

- 代码以 **Apache License 2.0** 开源，全文见 [LICENSE](LICENSE)，© 2026 lefengyao。
- 作者：恋梓里 <https://space.bilibili.com/1986364363>；美术：石英suartz <https://space.bilibili.com/169529553>。
- 美术、音乐与音效部分来自《植物大战僵尸》原作与网络素材（爱给网、耳聆网等），版权归各自作者所有；Apache-2.0 只覆盖本项目代码。
